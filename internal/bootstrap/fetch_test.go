//go:build linux

package bootstrap

import (
	"context"
	"crypto/rand"
	"crypto/sha1"
	"crypto/sha256"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"
)

const factory = "prifly-fixture-factory"

// Placeholder bytes standing in for age ciphertext; no key or secret exists.
var (
	ciphertext = []byte("fixture ciphertext placeholder\n")
	digestHex  = fmt.Sprintf("%x", sha256.Sum256(ciphertext))
	manifest   = fmt.Sprintf(`{"schema":%q,"factory_id":%q,"secrets_path":%q,"secrets_sha256":%q,"required_secrets":[{"id":"r2","generation":1}],"secret_schema":"prifly.secrets/v1"}`,
		ManifestSchema, factory, SecretsPath, digestHex)
)

// entry is one index entry of a fixture commit; an empty mode removes path.
type entry struct{ mode, path, data string }

func validEntries() []entry {
	return []entry{{"100644", ManifestPath, manifest}, {"100644", SecretsPath, string(ciphertext)}, {"100644", ReadmePath, "fixture\n"}}
}

func withManifest(old, new string) []entry {
	e := validEntries()
	e[0].data = strings.Replace(e[0].data, old, new, 1)
	return e
}

func testCtx(t *testing.T) context.Context {
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	t.Cleanup(cancel)
	return ctx
}

func gitFixture(t *testing.T, dir, stdin string, args ...string) string {
	t.Helper()
	cmd := exec.CommandContext(testCtx(t), "git", append([]string{"-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid"}, args...)...)
	cmd.Dir, cmd.Env, cmd.Stdin = dir, isolatedEnv(t.TempDir(), "", ""), strings.NewReader(stdin)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("fixture git %v: %v\n%s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

// fixtureRepo commits exactly the given index entries, in any mode, to a local repository.
func fixtureRepo(t *testing.T, entries []entry) (url, rev string) {
	t.Helper()
	dir := t.TempDir()
	gitFixture(t, dir, "", "init", "--quiet", "--template=", ".")
	for _, e := range entries {
		if e.mode == "" {
			gitFixture(t, dir, "", "update-index", "--force-remove", e.path)
			continue
		}
		obj := gitFixture(t, dir, e.data, "hash-object", "-w", "--stdin")
		if e.mode == "160000" {
			obj = strings.Repeat("ab", 20)
		}
		gitFixture(t, dir, "", "update-index", "--add", "--cacheinfo", e.mode+","+obj+","+e.path)
	}
	rev = gitFixture(t, dir, "fixture\n", "commit-tree", gitFixture(t, dir, "", "write-tree"))
	gitFixture(t, dir, "", "update-ref", "refs/heads/main", rev)
	gitFixture(t, dir, "", "tag", "v1", rev)
	gitFixture(t, dir, "", "tag", "-a", "-m", "fixture", "v2", rev)
	return "file://" + dir, rev
}

// fetch runs Fetch and asserts that the work directory is emptied and that a failure
// returns no result and no locator or "prifly-canary" repository content.
func fetch(t *testing.T, url, rev, factoryID string) (*Verified, error) {
	t.Helper()
	work := t.TempDir()
	v, err := Fetch(testCtx(t), Request{Repository: url, Revision: rev, FactoryID: factoryID}, work)
	if left, _ := os.ReadDir(work); len(left) != 0 {
		t.Fatalf("work directory not cleaned: %d entries left", len(left))
	}
	if err != nil && (v != nil || strings.Contains(err.Error(), url) || strings.Contains(err.Error(), "prifly-canary")) {
		t.Fatalf("error %q returned a result or exposes the locator or repository content", err)
	}
	return v, err
}

func TestFetchReturnsVerifiedNonSecretBytes(t *testing.T) {
	url, rev := fixtureRepo(t, validEntries())
	if v, err := fetch(t, url, rev, factory); err != nil || v.Revision != rev || v.Manifest.FactoryID != factory || string(v.Secrets) != string(ciphertext) {
		t.Fatalf("result %+v, err = %v", v, err)
	}
}

func TestFetchRejectsMutableOrPartialRevision(t *testing.T) {
	url, rev := fixtureRepo(t, validEntries())
	for _, r := range []string{"main", "v1", "HEAD", "refs/heads/main", rev[:7], strings.ToUpper(rev), rev + strings.Repeat("0", 24)} {
		if _, err := fetch(t, url, r, factory); !errors.Is(err, ErrMutableRef) {
			t.Errorf("revision %q: err = %v, want ErrMutableRef", r, err)
		}
	}
}

func TestFetchRejects(t *testing.T) {
	tree := func(e entry) []entry { return append(validEntries(), e) } // a later entry replaces a path
	for name, c := range map[string]struct {
		entries []entry
		factory string
		want    error
	}{
		"executable":            {tree(entry{"100755", ManifestPath, "{}"}), factory, ErrTree},
		"symlink":               {tree(entry{"120000", ReadmePath, "fixture-target"}), factory, ErrTree},
		"submodule":             {tree(entry{"160000", ReadmePath, ""}), factory, ErrTree},
		".gitmodules":           {tree(entry{"100644", ".gitmodules", "[submodule \"x\"]\n"}), factory, ErrTree},
		".gitattr":              {tree(entry{"100644", ".gitattributes", "* filter=x\n"}), factory, ErrTree},
		".githooks":             {tree(entry{"100755", ".githooks/post-checkout", "#!/bin/sh\n"}), factory, ErrTree},
		"other file":            {tree(entry{"100644", "prifly-canary-entry", "echo\n"}), factory, ErrTree},
		"missing secrets":       {tree(entry{"", SecretsPath, ""}), factory, ErrTree},
		"identity mismatch":     {withManifest(factory, "other-factory"), factory, ErrManifest},
		"empty identity":        {withManifest(factory, ""), "", ErrManifest},
		"unknown field":         {withManifest(`v1"}`, `v1","extra":1}`), factory, ErrManifest},
		"trailing data":         {withManifest(`v1"}`, `v1"}{}`), factory, ErrManifest},
		"schema":                {withManifest(ManifestSchema, "prifly.bootstrap/v0"), factory, ErrManifest},
		"digest format":         {withManifest(`"secrets_sha256":"`, `"secrets_sha256":"X`), factory, ErrManifest},
		"secrets path":          {withManifest(`"secrets_path":"`+SecretsPath, `"secrets_path":"other.age`), factory, ErrManifest},
		"secret schema":         {withManifest(`"prifly.secrets/v1"`, `""`), factory, ErrManifest},
		"digest mismatch":       {withManifest(digestHex, strings.Repeat("0", 64)), factory, ErrDigest},
		"no required secret":    {withManifest(`[{"id":"r2","generation":1}]`, `[]`), factory, ErrManifest},
		"required id":           {withManifest(`{"id":"r2"`, `{"id":""`), factory, ErrManifest},
		"required generation":   {withManifest(`"generation":1}`, `"generation":0}`), factory, ErrManifest},
		"duplicate required id": {withManifest(`1}]`, `1},{"id":"r2","generation":2}]`), factory, ErrManifest},
		// encoding/json alone keeps the last duplicate and matches names case-insensitively, accepting each of these.
		"duplicate key":           {withManifest(`{`, `{"factory_id":"prifly-canary-factory",`), factory, ErrManifest},
		"duplicate same value":    {withManifest(`{`, `{"schema":"`+ManifestSchema+`",`), factory, ErrManifest},
		"case-variant key":        {withManifest(`"factory_id"`, `"Factory_ID"`), factory, ErrManifest},
		"case-variant dup schema": {withManifest(`{"schema":`, `{"schema":"other/v9","SCHEMA":`), factory, ErrManifest},
	} {
		t.Run(name, func(t *testing.T) {
			url, rev := fixtureRepo(t, c.entries)
			if _, err := fetch(t, url, rev, c.factory); !errors.Is(err, c.want) {
				t.Fatalf("err = %v, want %v", err, c.want)
			}
		})
	}
}

// Non-commit object ids and unlisted transports, whose helper must never run, also fail.
func TestFetchUnreachableRepositoryOrRevision(t *testing.T) {
	url, rev := fixtureRepo(t, validEntries())
	dir, bin := strings.TrimPrefix(url, "file://"), t.TempDir()
	sentinel := filepath.Join(bin, "helper-ran")
	if os.WriteFile(filepath.Join(bin, "git-remote-priflyx"), []byte("#!/bin/sh\ntouch '"+sentinel+"'\n"), 0o700) != nil {
		t.Fatal("writing transport helper")
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	unavailable, notCommit := "remote or revision unavailable", "revision is not a commit"
	for name, c := range map[string][3]string{
		"repository":    {"file://" + filepath.Join(t.TempDir(), "absent-prifly-bootstrap"), rev, unavailable},
		"revision":      {url, strings.Repeat("1", 40), unavailable},
		"tag object":    {url, gitFixture(t, dir, "", "rev-parse", "v2"), notCommit},
		"tree object":   {url, gitFixture(t, dir, "", "rev-parse", rev+"^{tree}"), notCommit},
		"transport ::":  {"priflyx::" + dir, rev, unavailable},
		"transport ://": {"priflyx://" + dir, rev, unavailable},
	} {
		if _, err := fetch(t, c[0], c[1], factory); !errors.Is(err, ErrFetch) || !strings.Contains(err.Error(), c[2]) { // pins the check itself
			t.Errorf("%s: err = %v, want ErrFetch with %q", name, err, c[2])
		}
	}
	if _, err := os.Stat(sentinel); err == nil {
		t.Fatal("unlisted transport helper ran")
	}
	_ = exec.CommandContext(testCtx(t), "git", "ls-remote", "priflyx::x").Run()
	if _, err := os.Stat(sentinel); err != nil {
		t.Fatal("control: helper did not run for unhardened git, so the check is vacuous")
	}
}

// hostileConfig writes a global config with a marker-writing hook and an insteadOf redirect.
func hostileConfig(t *testing.T, redirect string) (config, marker string) {
	t.Helper()
	dir := t.TempDir()
	marker, config = filepath.Join(dir, "hook-ran"), filepath.Join(dir, "gitconfig")
	hook := "#!/bin/sh\ncat >/dev/null\ntouch '" + marker + "'\n"
	body := fmt.Sprintf("[core]\n\thooksPath = %s\n[url \"file:///nonexistent-prifly-redirect/\"]\n\tinsteadOf = %s\n", dir, redirect)
	if os.WriteFile(filepath.Join(dir, "reference-transaction"), []byte(hook), 0o700) != nil ||
		os.WriteFile(config, []byte(body), 0o600) != nil {
		t.Fatal("writing hostile config")
	}
	return config, marker
}

func TestGitHardeningDisablesInheritedHooks(t *testing.T) {
	url, rev := fixtureRepo(t, validEntries())
	config, marker := hostileConfig(t, "file:///unused-prifly/")
	env := append(os.Environ(), "GIT_CONFIG_GLOBAL="+config, "GIT_CONFIG_NOSYSTEM=1")
	repo, ctx := filepath.Join(t.TempDir(), "r.git"), testCtx(t)
	if _, err := runGit(ctx, env, "", "init", "--bare", "--quiet", "--template=", repo); err != nil {
		t.Fatal(err)
	} else if _, err := runGit(ctx, env, repo, "fetch", "--quiet", url, rev+":refs/prifly/hardened"); err != nil {
		t.Fatalf("hardened fetch: %v", err)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Fatal("inherited reference-transaction hook ran under hardening")
	}
	plain := exec.CommandContext(ctx, "git", "fetch", "--quiet", url, rev+":refs/prifly/plain")
	plain.Dir, plain.Env = repo, env
	if out, err := plain.CombinedOutput(); err != nil {
		t.Fatalf("plain fetch: %v\n%s", err, out)
	}
	if _, err := os.Stat(marker); err != nil {
		t.Fatal("control: hook did not run for unhardened git, so the check is vacuous")
	}
}

func TestFetchIgnoresInheritedGitConfig(t *testing.T) {
	url, rev := fixtureRepo(t, validEntries())
	config, marker := hostileConfig(t, url)
	t.Setenv("GIT_CONFIG_GLOBAL", config)
	t.Setenv("GIT_CONFIG_NOSYSTEM", "1")
	if exec.CommandContext(testCtx(t), "git", "ls-remote", url).Run() == nil {
		t.Fatal("control: hostile config did not redirect an unisolated git")
	}
	if _, err := fetch(t, url, rev, factory); err != nil {
		t.Fatalf("Fetch under hostile inherited config: %v", err)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Fatal("inherited hook ran during Fetch")
	}
}

// TestSSHCommandIgnoresAmbientConfig runs the real ssh -G, which resolves configuration without
// connecting, through the fixed command: ssh reads only /dev/null, and its identity, agent and
// host-key sources are exactly the explicit references, or none when they are empty.
func TestSSHCommandIgnoresAmbientConfig(t *testing.T) {
	fields := regexp.MustCompile(`(?m)^(debug1: Reading configuration data .*|(batchmode|stricthostkeychecking|identityagent|identityfile|globalknownhostsfile|userknownhostsfile) .*)$`)
	for refs, want := range map[[2]string][2]string{{"/run/agent.sock", "/kit/known_hosts"}: {"/run/agent.sock", "/kit/known_hosts"}, {"", ""}: {"none", "/dev/null"}} {
		env := isolatedEnv(t.TempDir(), refs[0], refs[1])
		cmd := exec.CommandContext(testCtx(t), "sh", "-c", strings.TrimPrefix(env[len(env)-1], "GIT_SSH_COMMAND=")+` -v -G "$@"`, "ssh", "fixture-host")
		cmd.Env = env
		out, err := cmd.CombinedOutput()
		got := strings.Join(fields.FindAllString(strings.ReplaceAll(string(out), "\r", ""), -1), "\n")
		if err != nil || got != "debug1: Reading configuration data /dev/null\nbatchmode yes\nstricthostkeychecking true\nidentityagent "+want[0]+"\nidentityfile none\nglobalknownhostsfile /dev/null\nuserknownhostsfile "+want[1] {
			t.Fatalf("ssh -G (%v) with references %q resolved:\n%s", err, refs, got)
		}
	}
}

// TestFetchSizeGuards pads each file to exactly its guard, which passes, and one byte over, which fails with
// ErrTooLarge before git is ever asked for that blob's content.
func TestFetchSizeGuards(t *testing.T) {
	realGit, err := exec.LookPath("git")
	bin := t.TempDir()
	argLog := filepath.Join(bin, "git-args")
	if err != nil || os.WriteFile(filepath.Join(bin, "git"), []byte("#!/bin/sh\nprintf '%s\\n' \"$*\" >> '"+argLog+"'\nexec '"+realGit+"' \"$@\"\n"), 0o700) != nil {
		t.Fatal("writing git shim")
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	for name, c := range map[string]struct {
		path string
		over int
		want error
	}{
		"manifest at guard": {ManifestPath, 0, nil}, "manifest over guard": {ManifestPath, 1, ErrTooLarge},
		"secrets at guard": {SecretsPath, 0, nil}, "secrets over guard": {SecretsPath, 1, ErrTooLarge},
	} {
		t.Run(name, func(t *testing.T) {
			e := validEntries()
			if c.path == ManifestPath {
				e[0].data += strings.Repeat(" ", MaxManifestBytes-len(manifest)+c.over)
			} else {
				e[1].data = strings.Repeat("s", MaxSecretsBytes+c.over)
				e[0].data = strings.Replace(manifest, digestHex, fmt.Sprintf("%x", sha256.Sum256([]byte(e[1].data))), 1)
			}
			url, rev := fixtureRepo(t, e)
			os.Remove(argLog)
			v, err := fetch(t, url, rev, factory)
			args, _ := os.ReadFile(argLog)
			read := strings.Contains(string(args), "cat-file blob "+rev+":"+c.path+"\n")
			if !errors.Is(err, c.want) || read != (c.want == nil) || c.want == nil && (v == nil || len(v.Secrets) != len(e[1].data)) {
				t.Fatalf("err = %v, want %v; blob content read: %t", err, c.want, read)
			}
		})
	}
}

// TestFetchBound: a git shim records each invocation's arguments and, after it, the size of every file under its working
// directory, and traces git into a file. A fetched file over MaxFetchFileBytes stops with a file exactly at that bound;
// many small blobs, each file under it, pass MaxFetchTotalBytes; both fail with ErrFetchBound, and no git invocation
// follows the fetch. A history over the bounds fetches and verifies, as does a revision holding both guarded files at
// their guards. No fetch starts git maintenance.
func TestFetchBound(t *testing.T) {
	realGit, err := exec.LookPath("git")
	bin := t.TempDir()
	sizes, trace := filepath.Join(bin, "sizes"), filepath.Join(bin, "trace")
	shim := "#!/bin/sh\necho \"git $*\" >> '" + sizes + "'\nGIT_TRACE='" + trace + "' '" + realGit + "' \"$@\"; rc=$?\n" +
		"find . -type f -exec wc -c {} \\; >> '" + sizes + "'\nexit $rc\n"
	if err != nil || os.WriteFile(filepath.Join(bin, "git"), []byte(shim), 0o700) != nil {
		t.Fatal("writing git shim")
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	over, secrets := make([]byte, MaxFetchFileBytes+64<<10), make([]byte, MaxSecretsBytes)
	rand.Read(over)
	rand.Read(secrets)
	half := len(over) / 2
	guards := validEntries()
	guards[0].data = strings.Replace(manifest, digestHex, fmt.Sprintf("%x", sha256.Sum256(secrets)), 1)
	guards[0].data += strings.Repeat(" ", MaxManifestBytes-len(guards[0].data))
	guards[1].data = string(secrets)
	for name, c := range map[string]struct {
		entries []entry
		child   bool // select a valid child commit of the fixture commit instead
		blobs   int  // add this many small blobs to the fixture tree
		want    error
	}{
		"file over file bound":                    {append(validEntries(), entry{"100644", ReadmePath, string(over[:half])}, entry{"100644", "prifly-canary-tree", string(over[half:])}), false, 0, ErrFetchBound},
		"small blobs over total bound":            {validEntries(), false, 105000, ErrFetchBound},
		"history over bound fetches and verifies": {append(validEntries(), entry{"100644", "prifly-canary-history", string(over)}), true, 0, nil},
		"files at guards":                         {guards, false, 0, nil},
	} {
		t.Run(name, func(t *testing.T) {
			url, rev := fixtureRepo(t, c.entries)
			if dir := strings.TrimPrefix(url, "file://"); c.child {
				gitFixture(t, dir, "", "update-index", "--force-remove", "prifly-canary-history")
				rev = gitFixture(t, dir, "fixture child\n", "commit-tree", "-p", rev, gitFixture(t, dir, "", "write-tree"))
			} else if c.blobs > 0 {
				var stream, tree strings.Builder
				tree.WriteString(gitFixture(t, dir, "", "ls-tree", rev) + "\n")
				for i := range c.blobs {
					data := fmt.Sprintf("%d\n", i)
					fmt.Fprintf(&stream, "blob\ndata %d\n%s\n", len(data), data)
					fmt.Fprintf(&tree, "100644 blob %x\tc%06d\n", sha1.Sum([]byte(fmt.Sprintf("blob %d\x00%s", len(data), data))), i)
				}
				gitFixture(t, dir, stream.String(), "fast-import", "--quiet")
				rev = gitFixture(t, dir, "fixture\n", "commit-tree", gitFixture(t, dir, tree.String(), "mktree"))
			}
			os.Remove(sizes)
			os.Remove(trace)
			v, err := fetch(t, url, rev, factory)
			data, _ := os.ReadFile(sizes)
			traced, _ := os.ReadFile(trace)
			largest, last := 0, ""
			for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
				n := 0
				fmt.Sscan(line, &n)
				largest = max(largest, n)
				if strings.HasPrefix(line, "git ") {
					last = line
				}
			}
			if c.want != nil && !strings.Contains(last, " fetch ") || strings.Contains(string(traced), "maintenance run") {
				t.Fatalf("a git invocation follows the bounded fetch (last: %.40q), or a fetch started git maintenance", last)
			}
			if !errors.Is(err, c.want) || c.want == nil && (v == nil || v.Revision != rev) || (largest == MaxFetchFileBytes) != (c.want != nil && c.blobs == 0) || largest > MaxFetchFileBytes {
				t.Fatalf("err = %v, want %v; largest file written %d bytes, bound %d", err, c.want, largest, MaxFetchFileBytes)
			}
		})
	}
}

// entries returns a setup that adds n empty files.
func entries(n int) func(string) error {
	return func(dir string) error {
		for i := range n {
			if err := os.WriteFile(fmt.Sprintf("%s/e%d", dir, i), nil, 0o600); err != nil {
				return err
			}
		}
		return nil
	}
}

// TestCheckFetched walks a directory standing in for the fetched repository: regular files count up to exactly
// MaxFetchTotalBytes, a symlink's target does not count, and a walk that passes maxFetchEntries or cannot read a
// directory fails.
func TestCheckFetched(t *testing.T) {
	outside := filepath.Join(t.TempDir(), "outside")
	if os.WriteFile(outside, []byte("x"), 0o600) != nil {
		t.Fatal("writing symlink target")
	}
	for _, c := range []struct {
		name  string
		setup func(dir string) error
		want  error
	}{
		{"at total bound", func(dir string) error { return os.Truncate(dir+"/pack", MaxFetchTotalBytes) }, nil},
		{"one byte over total bound", func(dir string) error { return os.Truncate(dir+"/pack", MaxFetchTotalBytes+1) }, ErrFetchBound},
		{"symlink target not counted", func(dir string) error {
			return errors.Join(os.Truncate(dir+"/pack", MaxFetchTotalBytes), os.Symlink(outside, dir+"/link"))
		}, nil},
		{"entries at bound", entries(maxFetchEntries - 2), nil}, // the walk also visits dir and pack
		{"entries over bound", entries(maxFetchEntries - 1), ErrFetchBound},
		{"unreadable directory", func(dir string) error {
			return errors.Join(os.Mkdir(dir+"/objects", 0o700), os.Chmod(dir+"/objects", 0))
		}, ErrFetch},
		{"listable but not searchable directory", func(dir string) error { // os.Lstat of its entry fails
			return errors.Join(os.Mkdir(dir+"/objects", 0o700), os.WriteFile(dir+"/objects/pack", nil, 0o600),
				os.Truncate(dir+"/objects/pack", 3<<20), os.Chmod(dir+"/objects", 0o600))
		}, ErrFetch},
	} {
		if c.want == ErrFetch && os.Geteuid() == 0 {
			continue // root reads a directory whatever its mode
		}
		dir := t.TempDir()
		if os.WriteFile(dir+"/pack", nil, 0o600) != nil || c.setup(dir) != nil {
			t.Fatalf("%s: setup", c.name)
		}
		if err := checkFetched(dir, nil); !errors.Is(err, c.want) || c.want == nil && err != nil {
			t.Errorf("%s: err = %v, want %v", c.name, err, c.want)
		}
		os.Chmod(dir+"/objects", 0o700)
	}
}

// TestFetchServerRefusesUnadvertisedCommit serves the fixture over ssh as a server that drops GIT_PROTOCOL, so git
// falls back to protocol v0, which refuses a commit id no ref advertises unless the server allows it.
func TestFetchServerRefusesUnadvertisedCommit(t *testing.T) {
	url, tip := fixtureRepo(t, validEntries())
	dir, bin := strings.TrimPrefix(url, "file://"), t.TempDir()
	unadvertised := gitFixture(t, dir, "fixture child\n", "commit-tree", "-p", tip, tip+"^{tree}")
	v0 := filepath.Join(bin, "v0")
	ssh := "#!/bin/sh\n[ -e '" + v0 + "' ] && unset GIT_PROTOCOL\nfor a; do last=$a; done\neval \"exec git upload-pack ${last#git-upload-pack }\"\n"
	if os.WriteFile(filepath.Join(bin, "ssh"), []byte(ssh), 0o700) != nil {
		t.Fatal("writing ssh stand-in")
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	for _, c := range []struct {
		name, rev string
		v0, allow bool
		want      error
	}{
		{"v0 unadvertised", unadvertised, true, false, ErrFetch},
		{"v0 advertised", tip, true, false, nil},
		{"v0 unadvertised allowed", unadvertised, true, true, nil},
		{"v2 unadvertised", unadvertised, false, false, nil},
	} {
		os.Remove(v0)
		gitFixture(t, dir, "", "config", "uploadpack.allowAnySHA1InWant", fmt.Sprint(c.allow))
		if c.v0 && os.WriteFile(v0, nil, 0o600) != nil {
			t.Fatal("writing v0 marker")
		}
		v, err := fetch(t, "ssh://fixture-host"+dir, c.rev, factory)
		if !errors.Is(err, c.want) || c.want != nil && !strings.Contains(err.Error(), "remote or revision unavailable") || c.want == nil && (v == nil || v.Revision != c.rev) {
			t.Errorf("%s: err = %v, want %v", c.name, err, c.want)
		}
	}
}
