package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"filippo.io/age"

	"github.com/blac9216/PriFly/internal/bootstrap"
)

// Test-time canaries; no real secret, key or credential is committed.
const (
	canary   = "prifly-canary-cli-secret"
	factory  = "prifly-fixture-factory"
	inherits = "PRIFLY_INHERITED_CANARY"
)

func git(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid"}, args...)...)
	cmd.Dir, cmd.Env = dir, []string{"PATH=" + os.Getenv("PATH"), "HOME=" + t.TempDir(), "GIT_CONFIG_NOSYSTEM=1", "GIT_CONFIG_GLOBAL=/dev/null"}
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("fixture git %v: %v\n%s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

// fixture commits an age-encrypted canary secrets file and its manifest, and puts on PATH a
// fake ssh that records its environment in envLog and serves the repository locally.
func fixture(t *testing.T) (url, rev, identityFile, envLog string) {
	t.Helper()
	id, err := age.GenerateX25519Identity()
	if err != nil {
		t.Fatal("identity fixture")
	}
	identityFile, repo, bin := filepath.Join(t.TempDir(), "identity"), t.TempDir(), t.TempDir()
	var sealed bytes.Buffer
	w, err := age.Encrypt(&sealed, id.Recipient())
	if err != nil || os.WriteFile(identityFile, []byte(id.String()+"\n"), 0o600) != nil {
		t.Fatal("identity fixture")
	}
	fmt.Fprintf(w, `{"schema":%q,"factory_id":%q,"secrets":[{"id":"r2","purpose":"replication","generation":1,"value":%q}]}`, bootstrap.SecretSchema, factory, canary)
	if w.Close() != nil {
		t.Fatal("encrypting fixture")
	}
	manifest := fmt.Sprintf(`{"schema":%q,"factory_id":%q,"secrets_path":%q,"secrets_sha256":"%x","required_secrets":[{"id":"r2","generation":1}],"secret_schema":%q}`, bootstrap.ManifestSchema, factory, bootstrap.SecretsPath, sha256.Sum256(sealed.Bytes()), bootstrap.SecretSchema)
	envLog = filepath.Join(bin, "ssh-env")
	ssh := "#!/bin/sh\nenv > '" + envLog + "'\nfor a; do last=$a; done\neval \"exec git upload-pack ${last#git-upload-pack }\"\n"
	if os.WriteFile(filepath.Join(repo, bootstrap.ManifestPath), []byte(manifest), 0o644) != nil ||
		os.WriteFile(filepath.Join(repo, bootstrap.SecretsPath), sealed.Bytes(), 0o644) != nil ||
		os.WriteFile(filepath.Join(bin, "ssh"), []byte(ssh), 0o700) != nil {
		t.Fatal("repository fixture")
	}
	git(t, repo, "init", "--quiet", "--template=")
	git(t, repo, "add", ".")
	git(t, repo, "commit", "--quiet", "-m", "fixture")
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	return "ssh://fixture-host" + repo, git(t, repo, "rev-parse", "HEAD"), identityFile, envLog
}

// provider is the local fake discovery provider; it sees the plaintext only through the secrets path.
type provider struct {
	id                    string
	err                   error
	sawValue, sawLeftover bool
	leftover              string // a killed run's leftover, which the sweep must remove before decryption
}

func (p *provider) Discover(_ context.Context, _ bootstrap.Manifest, path string) (string, error) {
	data, _ := os.ReadFile(path)
	p.sawValue = strings.Contains(string(data), canary)
	_, err := os.Lstat(p.leftover)
	p.sawLeftover = p.leftover != "" && err == nil
	return p.id, p.err
}

func TestBootstrapCLI(t *testing.T) {
	url, rev, identityFile, envLog := fixture(t)
	refs, fd2, stderrFile := t.TempDir(), os.Stderr, filepath.Join(t.TempDir(), "fd2")
	sock, knownHosts := filepath.Join(refs, "agent.sock"), filepath.Join(refs, "known_hosts")
	t.Chdir(refs) // so relative references name existing entries
	listener, err := net.Listen("unix", sock)
	os.Stderr, _ = os.Create(stderrFile) // the flag package's default output
	for _, name := range []string{"known_hosts", "known hosts", "known$hosts", "known%hosts", "known~hosts"} {
		err = errors.Join(err, os.WriteFile(name, nil, 0o600)) // existing files only refPath can refuse
	}
	if err != nil || os.Symlink(sock, "link.sock") != nil || os.Symlink(knownHosts, "link_hosts") != nil {
		t.Fatal("reference fixture")
	}
	t.Cleanup(func() { listener.Close(); os.Stderr = fd2 })
	t.Setenv(inherits, canary)
	t.Setenv("SSH_AUTH_SOCK", "/inherited-agent.sock")
	unusable := "ssh agent socket or known-hosts reference unusable"
	for name, c := range map[string]struct {
		d      bootstrap.Discoverer
		extra  []string // appended to the full argument list; a repeated flag overrides the earlier value
		code   int
		output string
	}{
		"existing factory":         {&provider{id: factory}, nil, 0, "existing Factory state discovered at revision " + rev},
		"provider outage":          {&provider{err: errors.New("bucket prifly-canary-bucket unreachable: " + canary)}, nil, 1, bootstrap.ErrDiscovery.Error()},
		"missing config":           {nil, nil, 1, bootstrap.ErrDiscoveryConfig.Error()},
		"absent state":             {&provider{}, nil, 1, bootstrap.ErrNoFactory.Error()},
		"missing key":              {&provider{id: factory}, []string{"-age-identity-file", identityFile + "-absent"}, 1, bootstrap.ErrIdentity.Error()},
		"missing credential":       {&provider{id: factory}, []string{"-fetch-ssh-auth-sock", ""}, 1, "explicit fetch credential and known-hosts references"},
		"missing known hosts":      {&provider{id: factory}, []string{"-fetch-known-hosts", ""}, 1, "explicit fetch credential and known-hosts references"},
		"non-socket credential":    {&provider{id: factory}, []string{"-fetch-ssh-auth-sock", knownHosts}, 1, unusable},
		"relative credential":      {&provider{id: factory}, []string{"-fetch-ssh-auth-sock", "./agent.sock"}, 1, unusable},
		"space in known hosts":     {&provider{id: factory}, []string{"-fetch-known-hosts", filepath.Join(refs, "known hosts")}, 1, unusable},
		"dollar in known hosts":    {&provider{id: factory}, []string{"-fetch-known-hosts", filepath.Join(refs, "known$hosts")}, 1, unusable},
		"percent in known hosts":   {&provider{id: factory}, []string{"-fetch-known-hosts", filepath.Join(refs, "known%hosts")}, 1, unusable},
		"tilde in known hosts":     {&provider{id: factory}, []string{"-fetch-known-hosts", filepath.Join(refs, "known~hosts")}, 1, unusable},
		"symlinked credential":     {&provider{id: factory}, []string{"-fetch-ssh-auth-sock", filepath.Join(refs, "link.sock")}, 1, unusable},
		"symlinked known hosts":    {&provider{id: factory}, []string{"-fetch-known-hosts", filepath.Join(refs, "link_hosts")}, 1, unusable},
		"directory as known hosts": {&provider{id: factory}, []string{"-fetch-known-hosts", refs}, 1, unusable},
		"absent known hosts":       {&provider{id: factory}, []string{"-fetch-known-hosts", knownHosts + "-absent"}, 1, unusable},
		"missing input":            {&provider{id: factory}, []string{"-factory-id", ""}, 2, usage},
		"positional argument":      {&provider{id: factory}, []string{"extra"}, 2, usage},
		"unknown flag":             {&provider{id: factory}, []string{"-verbose"}, 2, usage},
		"zero fetch timeout":       {&provider{id: factory}, []string{"-fetch-timeout", "0s"}, 2, usage},
	} {
		t.Run(name, func(t *testing.T) {
			work, tmp := t.TempDir(), t.TempDir()
			t.Setenv("TMPDIR", tmp)
			if leftover := filepath.Join(work, "prifly-secrets-4242"); c.code != 2 { // plaintext a killed run left
				if os.Mkdir(leftover, 0o700) != nil || os.WriteFile(filepath.Join(leftover, "secrets.json"), []byte(canary), 0o600) != nil {
					t.Fatal("leftover fixture")
				}
				if p, ok := c.d.(*provider); ok {
					p.leftover = leftover
				}
			}
			os.Remove(envLog)
			args := append([]string{"-repository", url, "-revision", rev, "-factory-id", factory, "-fetch-ssh-auth-sock", sock,
				"-fetch-known-hosts", knownHosts, "-age-identity-file", identityFile, "-work-dir", work}, c.extra...)
			var stdout, stderr bytes.Buffer
			code := run(context.Background(), args, &stdout, &stderr, c.d)
			output := stdout.String() + stderr.String()
			if written, _ := os.ReadFile(stderrFile); code != c.code || !strings.Contains(output, c.output) || c.code == 2 && output != usage || len(written) != 0 {
				t.Fatalf("exit %d, output %q; want exit %d with %q", code, output, c.code, c.output)
			}
			for _, secret := range []string{"prifly-canary", url, refs, identityFile, work} {
				if strings.Contains(output, secret) {
					t.Fatalf("output exposes %q: %q", secret, output)
				}
			}
			for label, dir := range map[string]string{"work directory": work, "TMPDIR": tmp} {
				if left, _ := os.ReadDir(dir); len(left) != 0 {
					t.Fatalf("%s holds %d entries after the run", label, len(left))
				}
			}
			if p, ok := c.d.(*provider); ok && (p.sawValue != (len(c.extra) == 0) || p.sawLeftover) {
				t.Fatalf("provider saw decrypted secrets: %t; a killed run's leftover still present at discovery: %t", p.sawValue, p.sawLeftover)
			}
			recorded, err := os.ReadFile(envLog)
			if blocked := c.code == 2 || strings.HasPrefix(strings.Join(c.extra, " "), "-fetch"); blocked != (err != nil) {
				t.Fatalf("git ran: %t; want %t (inputs incomplete or unusable: %t)", err == nil, !blocked, blocked)
			} else if blocked {
				return
			}
			// Fetch's documented allowlist with its values, plus the variables git and sh set themselves.
			want := map[string]string{"LC_ALL": "C", "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_TERMINAL_PROMPT": "0",
				"GIT_SSH_COMMAND": "ssh -F /dev/null -o IdentityFile=none -o IdentityAgent=" + sock + " -o UserKnownHostsFile=" + knownHosts +
					" -o GlobalKnownHostsFile=/dev/null -o StrictHostKeyChecking=yes -o BatchMode=yes", "GIT_EXEC_PATH": "*", "GIT_PROTOCOL": "*", "PWD": "*"}
			if !strings.Contains("\n"+string(recorded), "\nGIT_SSH_COMMAND="+want["GIT_SSH_COMMAND"]+"\n") {
				t.Fatalf("git's ssh did not receive the fixed command with the explicit references:\n%s", recorded)
			}
			for _, line := range strings.Split(strings.TrimSpace(string(recorded)), "\n") {
				name, value, _ := strings.Cut(line, "=")
				switch w, ok := want[name]; {
				case name == "HOME" && strings.HasPrefix(value, work+string(os.PathSeparator)), name == "PATH" && strings.HasSuffix(value, os.Getenv("PATH")):
				case ok && (w == "*" || w == value):
				default:
					t.Fatalf("variable %q=%q reached git", name, value)
				}
			}
		})
	}
}

// slowFetch returns CLI arguments whose fetch reaches, in front of the serving ssh, a stand-in that never answers;
// the work directory; the file the stand-in writes its pid and process group to; and a function that waits up to
// 5s for no process to run in that group or as the stand-in, returning how many still do.
func slowFetch(t *testing.T) (args []string, work, pidFile string, survivors func() int) {
	url, rev, identityFile, _ := fixture(t)
	bin, refs, work := t.TempDir(), t.TempDir(), t.TempDir()
	pidFile, sock, knownHosts := filepath.Join(bin, "ssh-pid"), filepath.Join(refs, "agent.sock"), filepath.Join(refs, "known_hosts")
	listener, err := net.Listen("unix", sock)
	if err != nil || os.WriteFile(knownHosts, nil, 0o600) != nil || os.WriteFile(filepath.Join(bin, "ssh"),
		[]byte("#!/bin/sh\necho $$ $(cut -d' ' -f5 /proc/$$/stat) > '"+pidFile+"'\nexec sleep 20\n"), 0o700) != nil {
		t.Fatal("fixture")
	}
	t.Cleanup(func() { listener.Close() })
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	survivors = func() int {
		var pid, pgid int
		data, _ := os.ReadFile(pidFile)
		if _, err := fmt.Sscan(string(data), &pid, &pgid); err != nil {
			t.Fatal("ssh stand-in never ran")
		}
		for end := time.Now().Add(5 * time.Second); ; time.Sleep(50 * time.Millisecond) {
			n := 0
			stats, _ := filepath.Glob("/proc/[0-9]*/stat")
			for _, stat := range stats {
				data, _ := os.ReadFile(stat)
				f := strings.Fields(string(data[bytes.LastIndexByte(data, ')')+1:])) // state, ppid, pgrp, ...
				if len(f) > 2 && f[0] != "Z" && (f[2] == strconv.Itoa(pgid) || stat == fmt.Sprintf("/proc/%d/stat", pid)) {
					n++
				}
			}
			if n == 0 || time.Now().After(end) {
				if syscall.Kill(pid, syscall.SIGKILL); n != 0 && pgid != syscall.Getpgrp() { // never this test's own group
					syscall.Kill(-pgid, syscall.SIGKILL)
				}
				return n
			}
		}
	}
	return []string{"-repository", url, "-revision", rev, "-factory-id", factory, "-fetch-ssh-auth-sock", sock,
		"-fetch-known-hosts", knownHosts, "-age-identity-file", identityFile, "-work-dir", work}, work, pidFile, survivors
}

// TestBootstrapCLIFetchDeadline: past the deadline the CLI must block with a fixed diagnostic, leave the work
// directory empty and leave no git, shell or ssh of the fetch running.
func TestBootstrapCLIFetchDeadline(t *testing.T) {
	args, work, _, survivors := slowFetch(t)
	var stdout, stderr bytes.Buffer
	start := time.Now()
	code := run(context.Background(), append(args, "-fetch-timeout", "2s"), &stdout, &stderr, &provider{id: factory})
	elapsed, output := time.Since(start), stdout.String()+stderr.String()
	if left, _ := os.ReadDir(work); code != 1 || elapsed > 10*time.Second || len(left) != 0 ||
		output != "prifly-bootstrap: blocked: "+bootstrap.ErrFetch.Error()+": deadline exceeded\n" {
		t.Fatalf("exit %d after %v with %d work entries, output %q", code, elapsed, len(left), output)
	}
	if n := survivors(); n != 0 {
		t.Fatalf("%d fetch processes still running 5s after the CLI returned", n)
	}
}

// TestBootstrapCLIGroupKill starts the CLI as its own process group, as a shell or supervisor does, and kills that
// group with SIGKILL while the fetch waits on ssh. No git, shell or ssh of the fetch may outlive it.
func TestBootstrapCLIGroupKill(t *testing.T) {
	if args := os.Getenv("PRIFLY_TEST_CLI_ARGS"); args != "" {
		os.Exit(run(context.Background(), strings.Split(args, "\x1f"), io.Discard, io.Discard, &provider{id: factory}))
	}
	args, _, pidFile, survivors := slowFetch(t)
	cli := exec.Command(os.Args[0], "-test.run=^TestBootstrapCLIGroupKill$")
	cli.Env = append(os.Environ(), "PRIFLY_TEST_CLI_ARGS="+strings.Join(args, "\x1f"))
	cli.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if cli.Start() != nil {
		t.Fatal("start CLI")
	}
	for end := time.Now().Add(10 * time.Second); time.Now().Before(end); time.Sleep(50 * time.Millisecond) {
		if data, _ := os.ReadFile(pidFile); strings.HasSuffix(string(data), "\n") {
			break
		}
	}
	syscall.Kill(-cli.Process.Pid, syscall.SIGKILL)
	cli.Wait()
	if n := survivors(); n != 0 {
		t.Fatalf("%d fetch processes still running 5s after the CLI's process group was killed", n)
	}
}
