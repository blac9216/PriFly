//go:build linux

package bootstrap

import (
	"bytes"
	"cmp"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"filippo.io/age"
	"golang.org/x/sys/unix"
)

// A test-time canary; no real secret or key is committed.
const canary = "prifly-canary-secret-value"

func secretsJSON(old, new string) string {
	s := fmt.Sprintf(`{"schema":%q,"factory_id":%q,"secrets":[{"id":"r2","purpose":"replication","generation":1,"value":%q}]}`,
		SecretSchema, factory, canary)
	return strings.Replace(s, old, new, 1)
}

// newIdentity generates an X25519 identity and writes it to a 0600 file.
func newIdentity(t *testing.T) (*age.X25519Identity, string) {
	t.Helper()
	id, err := age.GenerateX25519Identity()
	path := filepath.Join(t.TempDir(), "identity.txt")
	if err != nil || os.WriteFile(path, []byte(id.String()+"\n"), 0o600) != nil {
		t.Fatal("generating identity")
	}
	return id, path
}

// seal encrypts plaintext to id and returns it as Fetch would have verified it, its last byte flipped (damage 0) or cut (1).
func seal(t *testing.T, id *age.X25519Identity, plaintext string, damage ...int) *Verified {
	t.Helper()
	var buf bytes.Buffer
	w, err := age.Encrypt(&buf, id.Recipient())
	if err != nil {
		t.Fatal("encrypting fixture")
	}
	if _, err := io.WriteString(w, plaintext); err != nil || w.Close() != nil {
		t.Fatal("encrypting fixture")
	}
	for _, cut := range damage {
		buf.Truncate(buf.Len() - cut)
		buf.Bytes()[buf.Len()-1] ^= byte(1 - cut)
	}
	m := Manifest{ManifestSchema, factory, SecretsPath, fmt.Sprintf("%x", sha256.Sum256(buf.Bytes())), []RequiredSecret{{"r2", 1}}, SecretSchema}
	return &Verified{Revision: strings.Repeat("a", 40), Manifest: m, Secrets: buf.Bytes()}
}

// capture runs f with file descriptors 1 and 2 redirected to files and returns what each received.
func capture(t *testing.T, f func()) (stdout, stderr string) {
	t.Helper()
	for _, fd := range []int{1, 2} {
		file, err := os.Create(filepath.Join(t.TempDir(), "fd"))
		saved, dupErr := unix.Dup(fd)
		if err != nil || dupErr != nil || unix.Dup2(int(file.Fd()), fd) != nil {
			t.Fatal("redirecting output")
		}
		defer func() {
			_, _ = unix.Dup2(saved, fd), unix.Close(saved)
			data, _ := os.ReadFile(file.Name())
			if fd == 1 {
				stdout = string(data)
			} else {
				stderr = string(data)
			}
			file.Close()
		}()
	}
	f()
	return
}

// errPanic is provision's panic value in the "provision panic" row; inWork stands for the helper's work directory.
var errPanic, inWork = errors.New("provision panicked"), "<work>"

// decrypt runs Decrypt in dir with TMPDIR empty, asserts on the filesystem that provision's file is in a directory created in
// work while TMPDIR is empty and that both are empty afterwards, and that no canary, age identity, work path or 8
// consecutive ciphertext bytes, raw or hex-encoded, are output. A non-zero fileSizeLimit is the RLIMIT_FSIZE soft limit
// for the Decrypt call only: the limit is process-wide, so no diagnostic of the test is written while it holds.
func decrypt(t *testing.T, v *Verified, identityFile, dir string, provision func(string) error, fileSizeLimit uint64) (stdout, stderr string, err error, panicked bool) {
	t.Helper()
	work, tmpdir, at := t.TempDir(), t.TempDir(), ""
	count := func(dir string) int { entries, _ := os.ReadDir(dir); return len(entries) }
	t.Setenv("TMPDIR", tmpdir)
	var limit unix.Rlimit
	if fileSizeLimit != 0 && unix.Getrlimit(unix.RLIMIT_FSIZE, &limit) != nil {
		t.Fatal("reading RLIMIT_FSIZE")
	}
	var limitErr error
	stdout, stderr = capture(t, func() {
		defer func() { p := recover(); r, _ := p.(error); err, panicked = cmp.Or(r, err), p != nil }()
		if fileSizeLimit != 0 {
			defer unix.Setrlimit(unix.RLIMIT_FSIZE, &limit) // runs before the recover above, also when provision panics
			limitErr = unix.Setrlimit(unix.RLIMIT_FSIZE, &unix.Rlimit{Cur: fileSizeLimit, Max: limit.Max})
		}
		err = Decrypt(v, identityFile, strings.Replace(dir, inWork, work, 1), func(path string) error {
			at = filepath.Dir(filepath.Dir(path)) + strings.Repeat(" and TMPDIR", count(tmpdir))
			return provision(path)
		})
	})
	if limitErr != nil {
		t.Fatalf("lowering RLIMIT_FSIZE: %v", limitErr)
	}
	if count(work)+count(tmpdir) != 0 || (at != "" && at != work) {
		t.Fatalf("plaintext outside work or not removed: %d entries left in work, %d in TMPDIR; provisioned in %q", count(work), count(tmpdir), at)
	}
	for where, text := range map[string]string{"stdout": stdout, "stderr": stderr, "error": fmt.Sprint(err)} {
		leak := strings.Contains(text, "prifly-canary") || strings.Contains(text, "AGE-SECRET-KEY-") || strings.Contains(text, work)
		for i := 0; v != nil && i+8 <= len(v.Secrets); i++ {
			leak = leak || strings.Contains(text, string(v.Secrets[i:i+8])) || strings.Contains(text, hex.EncodeToString(v.Secrets[i:i+8]))
		}
		if leak {
			t.Fatalf("%s exposes a secret, identity or path: %q", where, text)
		}
	}
	return stdout, stderr, err, panicked
}

func TestDecrypt(t *testing.T) {
	defer unix.Umask(unix.Umask(0)) // modes must not depend on a restrictive umask
	id, identityFile := newIdentity(t)
	_, otherFile := newIdentity(t)
	garbage := filepath.Join(t.TempDir(), canary)
	if os.WriteFile(garbage, []byte("AGE-SECRET-KEY-1"+canary+"\n"), 0o600) != nil {
		t.Fatal("writing identity fixture")
	}
	valid := seal(t, id, secretsJSON("", ""))
	url, rev := fixtureRepo(t, []entry{{"100644", ManifestPath, strings.Replace(manifest, digestHex, valid.Manifest.SecretsSHA256, 1)}, {"100644", SecretsPath, string(valid.Secrets)}})
	fetched, err := fetch(t, url, rev, factory)
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	substituted := &Verified{Manifest: valid.Manifest, Secrets: seal(t, id, secretsJSON(`"r2"`, `"other"`)).Secrets}
	otherSchema := *valid
	otherSchema.Manifest.SecretSchema = "prifly.secrets/v2"
	with := func(old, new string) *Verified { return seal(t, id, secretsJSON(old, new)) }
	// protected succeeds only for a 0600 file holding the plaintext in a 0700 directory, and prints capture markers.
	protected := func(path string) error {
		dir, _ := os.Stat(filepath.Dir(path))
		file, _ := os.Lstat(path)
		data, err := os.ReadFile(path)
		fmt.Fprint(os.Stdout, "prifly-capture-stdout")
		fmt.Fprint(os.Stderr, "prifly-capture-stderr")
		ok := err == nil && fmt.Sprint(dir.Mode(), file.Mode()) == "drwx------ -rw-------" && strings.Contains(string(data), canary)
		if !ok {
			return errors.New("transient plaintext unprotected")
		}
		return nil
	}
	calls := 0
	refuse := func(string) error { calls++; return nil }
	for name, c := range map[string]struct {
		v                     *Verified
		identity, dir, output string
		provision             func(string) error
		want                  error
	}{
		// Success; output is the capture control: without it the absence checks would be vacuous.
		"provisions protected": {valid, identityFile, inWork, "prifly-capture-stdout|prifly-capture-stderr", protected, nil},
		"fetched secrets":      {fetched, identityFile, inWork, "prifly-capture-stdout|prifly-capture-stderr", protected, nil},
		"missing key":          {valid, filepath.Join(t.TempDir(), "absent"), inWork, "|", refuse, ErrIdentity},
		"key as argument":      {valid, id.String(), inWork, "|", refuse, ErrIdentity},
		"unparsable key":       {valid, garbage, inWork, "|", refuse, ErrIdentity},
		"wrong key":            {valid, otherFile, inWork, "|", refuse, ErrDecrypt},
		"corrupt payload":      {seal(t, id, secretsJSON("", ""), 0), identityFile, inWork, "|", refuse, ErrDecrypt},
		"truncated payload":    {seal(t, id, secretsJSON("", ""), 1), identityFile, inWork, "|", refuse, ErrDecrypt},
		"unverified bytes":     {substituted, identityFile, inWork, "|", refuse, ErrDigest},
		"nil result":           {nil, identityFile, inWork, "|", refuse, ErrDigest},
		"empty work dir":       {valid, identityFile, "", "|", refuse, ErrTransient},
		"relative work dir":    {valid, identityFile, canary, "|", refuse, ErrTransient},
		"write failure":        {valid, identityFile, inWork, "|", refuse, ErrTransient}, // RLIMIT_FSIZE below the plaintext size
		"missing work dir":     {valid, identityFile, inWork + "/" + canary, "|", refuse, ErrTransient},
		"schema":               {with(SecretSchema, "prifly.secrets/v0"), identityFile, inWork, "|", refuse, ErrSecrets},
		"manifest schema id":   {&otherSchema, identityFile, inWork, "|", refuse, ErrSecrets},
		"factory":              {with(factory, "other-factory"), identityFile, inWork, "|", refuse, ErrSecrets},
		"unknown field":        {with(`"generation"`, `"rotated":1,"generation"`), identityFile, inWork, "|", refuse, ErrSecrets},
		"misplaced field":      {with(`"generation"`, `"schema":"x","generation"`), identityFile, inWork, "|", refuse, ErrSecrets},
		"duplicate member":     {with(`"value":`, `"value":"","value":`), identityFile, inWork, "|", refuse, ErrSecrets},
		"case-variant member":  {with(`"value":`, `"Value":`), identityFile, inWork, "|", refuse, ErrSecrets},
		"trailing data":        {with(`]}`, `]}{}`), identityFile, inWork, "|", refuse, ErrSecrets},
		"empty list":           {seal(t, id, fmt.Sprintf(`{"schema":%q,"factory_id":%q,"secrets":[]}`, SecretSchema, factory)), identityFile, inWork, "|", refuse, ErrSecrets},
		"generation":           {with(`"generation":1`, `"generation":0`), identityFile, inWork, "|", refuse, ErrSecrets},
		"missing value":        {with(`"value":"`+canary, `"value":"`), identityFile, inWork, "|", refuse, ErrSecrets},
		"duplicate id":         {with(`}]}`, `},{"id":"r2","purpose":"p","generation":1,"value":"v"}]}`), identityFile, inWork, "|", refuse, ErrSecrets},
		"provision error":      {valid, identityFile, inWork, "|", func(string) error { return errors.New("consumer failed on " + canary) }, ErrProvision},
		"provision panic":      {valid, identityFile, inWork, "|", func(string) error { panic(errPanic) }, errPanic},
	} {
		t.Run(name, func(t *testing.T) {
			var fileSizeLimit uint64
			if name == "write failure" {
				fileSizeLimit = 16
			}
			before := calls
			stdout, stderr, err, panicked := decrypt(t, c.v, c.identity, c.dir, c.provision, fileSizeLimit)
			if !errors.Is(err, c.want) || (c.want == nil) != (err == nil) || calls != before || stdout+"|"+stderr != c.output || panicked != (name == "provision panic") {
				t.Fatalf("err = %v, want %v; refused provision called %t; output %q|%q; panicked %t", err, c.want, calls != before, stdout, stderr, panicked)
			}
		})
	}
}

// TestDecryptRequiredSecrets pins the exact diagnostic for each way the decrypted secrets can differ from the ids and
// generations the manifest requires, or carry an inconsistent rotation lineage. Only the matching file is provisioned.
func TestDecryptRequiredSecrets(t *testing.T) {
	id, identityFile := newIdentity(t)
	r2 := func(generation int, lineage string) string {
		return fmt.Sprintf(`{"id":"r2","purpose":"replication","generation":%d,%s"value":%q}`, generation, lineage, canary)
	}
	git := `{"id":"git","purpose":"fetch","generation":1,"value":"prifly-canary-git"}`
	lineage := `secret "r2" rotation lineage inconsistent: supersedes_generation must be absent for generation 1, otherwise from 1 to generation-1`
	for name, c := range map[string]struct {
		secrets  []string
		required []RequiredSecret
		want     string // after "bootstrap: decrypted secrets invalid: "; "" when provisioned
	}{
		"exact generations":       {[]string{r2(3, `"supersedes_generation":2,`), git}, []RequiredSecret{{"git", 1}, {"r2", 3}}, ""},
		"missing":                 {[]string{r2(1, "")}, []RequiredSecret{{"r2", 1}, {"git", 1}}, `required secret "git" missing`},
		"stale":                   {[]string{r2(1, "")}, []RequiredSecret{{"r2", 2}}, `secret "r2" generation 1 is stale; the manifest requires 2`},
		"newer":                   {[]string{r2(2, `"supersedes_generation":1,`)}, []RequiredSecret{{"r2", 1}}, `secret "r2" generation 2 is newer than the manifest requires (1)`},
		"duplicate":               {[]string{r2(1, ""), r2(1, "")}, []RequiredSecret{{"r2", 1}}, `secret "r2" appears more than once`},
		"unnamed extra":           {[]string{r2(1, ""), strings.Replace(git, `"git"`, `"prifly-canary-extra"`, 1)}, []RequiredSecret{{"r2", 1}}, "holds a secret the manifest does not require"},
		"lineage at generation 1": {[]string{r2(1, `"supersedes_generation":1,`)}, []RequiredSecret{{"r2", 1}}, lineage},
		"lineage absent":          {[]string{r2(2, "")}, []RequiredSecret{{"r2", 2}}, lineage},
		"lineage below 1":         {[]string{r2(2, `"supersedes_generation":0,`)}, []RequiredSecret{{"r2", 2}}, lineage},
		"lineage not older":       {[]string{r2(2, `"supersedes_generation":2,`)}, []RequiredSecret{{"r2", 2}}, lineage},
		"lineage null":            {[]string{r2(1, `"supersedes_generation":null,`)}, []RequiredSecret{{"r2", 1}}, "not exactly one object of known, unique, exactly spelled, non-null fields"},
	} {
		t.Run(name, func(t *testing.T) {
			v := seal(t, id, fmt.Sprintf(`{"schema":%q,"factory_id":%q,"secrets":[%s]}`, SecretSchema, factory, strings.Join(c.secrets, ",")))
			v.Manifest.RequiredSecrets = c.required
			provisioned := 0
			stdout, stderr, err, _ := decrypt(t, v, identityFile, inWork, func(string) error { provisioned++; return nil }, 0)
			want, got, wantProvisioned := ErrSecrets.Error()+": "+c.want, fmt.Sprint(err), 0
			if c.want == "" {
				want, wantProvisioned = "<nil>", 1
			}
			if got != want || provisioned != wantProvisioned || (err != nil) != errors.Is(err, ErrSecrets) || stdout+stderr != "" {
				t.Fatalf("err = %q, want %q; provisioned %d times; output %q", got, want, provisioned, stdout+stderr)
			}
		})
	}
}

// homoglyphID is "r" then U+0430, the Cyrillic small a, which a terminal draws as the Latin a. %q is
// strconv.Quote and leaves it raw; homoglyphEscaped, written as a raw literal so this file states the bytes
// rather than computing them with the renderer under test, is what strconv.QuoteToASCII renders it as.
const (
	homoglyphID      = "r\u0430"
	homoglyphEscaped = `"r\u0430"`
)

// TestDecryptRendersIDsASCII drives an id carrying a printable non-ASCII character through each of the five
// diagnostics that name a secret id, and pins the whole message: prifly-bootstrap prints it after "blocked: ".
// Through the decrypt helper, so the leak checks hold for these cases too.
func TestDecryptRendersIDsASCII(t *testing.T) {
	id, identityFile := newIdentity(t)
	entry := func(generation int, lineage string) string {
		return fmt.Sprintf(`{"id":%q,"purpose":"p","generation":%d,%s"value":%q}`, homoglyphID, generation, lineage, canary)
	}
	r2 := `{"id":"r2","purpose":"replication","generation":1,"value":"prifly-canary-r2"}`
	for name, c := range map[string]struct {
		secrets  []string
		required []RequiredSecret
		want     string // after "bootstrap: decrypted secrets invalid: "
	}{
		"duplicate": {[]string{entry(1, ""), entry(1, "")}, []RequiredSecret{{homoglyphID, 1}}, "secret " + homoglyphEscaped + " appears more than once"},
		"lineage": {[]string{entry(1, `"supersedes_generation":1,`)}, []RequiredSecret{{homoglyphID, 1}}, "secret " + homoglyphEscaped +
			" rotation lineage inconsistent: supersedes_generation must be absent for generation 1, otherwise from 1 to generation-1"},
		"stale":   {[]string{entry(1, "")}, []RequiredSecret{{homoglyphID, 2}}, "secret " + homoglyphEscaped + " generation 1 is stale; the manifest requires 2"},
		"newer":   {[]string{entry(2, `"supersedes_generation":1,`)}, []RequiredSecret{{homoglyphID, 1}}, "secret " + homoglyphEscaped + " generation 2 is newer than the manifest requires (1)"},
		"missing": {[]string{r2}, []RequiredSecret{{"r2", 1}, {homoglyphID, 1}}, "required secret " + homoglyphEscaped + " missing"},
	} {
		t.Run(name, func(t *testing.T) {
			v := seal(t, id, fmt.Sprintf(`{"schema":%q,"factory_id":%q,"secrets":[%s]}`, SecretSchema, factory, strings.Join(c.secrets, ",")))
			v.Manifest.RequiredSecrets = c.required
			stdout, stderr, err, _ := decrypt(t, v, identityFile, inWork, func(string) error { return nil }, 0)
			want, got := ErrSecrets.Error()+": "+c.want, fmt.Sprint(err)
			ascii := true
			for _, b := range []byte(got) {
				ascii = ascii && b < 0x80
			}
			if got != want || !ascii || !errors.Is(err, ErrSecrets) || stdout+stderr != "" {
				t.Fatalf("err = %q, want %q; ASCII %t; output %q", got, want, ascii, stdout+stderr)
			}
		})
	}
}

// TestClaimWorkDir leaves what a killed run would (a Decrypt directory holding a canary plaintext and a symbolic
// link out of the work directory, and a Fetch directory) beside look-alike names. Only the leftovers may go,
// nothing outside may change, and an entry that is not this user's 0700 directory or a second claim blocks.
func TestClaimWorkDir(t *testing.T) {
	outside, work := t.TempDir(), t.TempDir()
	keep := filepath.Join(outside, "keep")
	mkdir := func(path string, mode os.FileMode) {
		if os.Mkdir(path, 0o700) != nil || os.Chmod(path, mode) != nil {
			t.Fatal("directory fixture")
		}
	}
	write := func(path string, mode os.FileMode) {
		if os.WriteFile(path, []byte(canary), 0o600) != nil || os.Chmod(path, mode) != nil {
			t.Fatal("file fixture")
		}
	}
	write(keep, 0o600)
	mkdir(filepath.Join(work, "prifly-bootstrap-17"), 0o700)
	mkdir(filepath.Join(work, "prifly-secrets-4242"), 0o700)
	write(filepath.Join(work, "prifly-secrets-4242", plaintextName), 0o600)
	// Look-alikes: a missing, trailing or non-digit suffix, a prefix and another PriFly name.
	kept := []string{"prifly-other-1", "prifly-secrets-", "prifly-secrets-1-", "prifly-secrets-1a"}
	kept = append(kept, "x"+kept[3][:len(kept[3])-1])
	for _, name := range kept {
		mkdir(filepath.Join(work, name), 0o700)
	}
	if os.Symlink(outside, filepath.Join(work, "prifly-secrets-4242", "out")) != nil {
		t.Fatal("symlink fixture")
	}
	release, err := ClaimWorkDir(work)
	if err != nil {
		t.Fatalf("claim: %v", err)
	}
	if _, err := ClaimWorkDir(work); !errors.Is(err, ErrTransient) {
		t.Fatalf("second claim while the first is held: err = %v, want ErrTransient", err)
	}
	release()
	var left []string
	entries, _ := os.ReadDir(work)
	for _, e := range entries {
		left = append(left, e.Name())
	}
	if data, _ := os.ReadFile(keep); strings.Join(left, ",") != strings.Join(kept, ",") || string(data) != canary {
		t.Fatalf("work directory holds %q, want %q; entry outside unchanged: %t", left, kept, string(data) == canary)
	}
	if again, err := ClaimWorkDir(work); err != nil {
		t.Fatalf("claim after release: %v", err)
	} else {
		again()
	}
	for name, plant := range map[string]func(path string){
		"symlink to a 0700 directory": func(p string) { _ = os.Symlink(".", p) }, // the work directory itself
		"0755 directory":              func(p string) { mkdir(p, 0o755) },
		"0700 regular file":           func(p string) { write(p, 0o700) },
		"another owner":               func(p string) { mkdir(p, 0o700); currentUID = func() int { return os.Getuid() + 1 } },
		"unremovable leftover":        func(p string) { _ = os.MkdirAll(p+"/sub/d", 0o700); _ = os.Chmod(p+"/sub", 0o500) },
	} {
		t.Run(name, func(t *testing.T) {
			t.Cleanup(func() { currentUID = os.Getuid })
			work := t.TempDir()
			path := filepath.Join(work, "prifly-secrets-9")
			if name == "unremovable leftover" && os.Geteuid() == 0 {
				t.Skip("root removes it regardless of mode")
			}
			plant(path)
			t.Cleanup(func() { os.Chmod(path+"/sub", 0o700) }) // runs before TempDir's removal
			_, err := ClaimWorkDir(work)
			if _, lerr := os.Lstat(path); !errors.Is(err, ErrTransient) || strings.Contains(err.Error(), work) || lerr != nil {
				t.Fatalf("err = %v, want redacted ErrTransient; entry still present: %t", err, lerr == nil)
			}
		})
	}
	link := filepath.Join(t.TempDir(), "work-link")
	t.Chdir(filepath.Dir(work))
	if os.Symlink(work, link) != nil {
		t.Fatal("symlink fixture")
	}
	for _, dir := range []string{filepath.Base(work), link, filepath.Join(work, "absent")} {
		if _, err := ClaimWorkDir(dir); !errors.Is(err, ErrTransient) {
			t.Errorf("work directory %q: err = %v, want ErrTransient", dir, err)
		}
	}
}

// TestClaimWorkDirPathSwap renames the work directory away and puts a symbolic link to another directory holding
// a same-named 0700 leftover in its place: right after the lock (must block), and right before the sweep, where the
// locked leftover is 0700 (must be swept) or 0500 (must block); nothing the link reaches may be deleted.
func TestClaimWorkDirPathSwap(t *testing.T) {
	t.Cleanup(func() { claimHook = func(int) {} })
	for i, mode := range []os.FileMode{0o700, 0o700, 0o500} { // stage min(i, 1); only i == 1 may succeed
		work, other := filepath.Join(t.TempDir(), "work"), t.TempDir()
		if os.Mkdir(work, 0o700) != nil || os.Mkdir(filepath.Join(work, "prifly-secrets-1"), mode) != nil ||
			os.Mkdir(filepath.Join(other, "prifly-secrets-1"), 0o700) != nil {
			t.Fatal("directory fixture")
		}
		claimHook = func(s int) {
			if s == min(i, 1) && (os.Rename(work, work+".old") != nil || os.Symlink(other, work) != nil) {
				t.Error("swap fixture")
			}
		}
		release, err := ClaimWorkDir(work)
		if err == nil {
			release()
		}
		_, otherErr := os.Lstat(filepath.Join(other, "prifly-secrets-1"))
		_, oldErr := os.Lstat(filepath.Join(work+".old", "prifly-secrets-1"))
		if errors.Is(err, ErrTransient) != (i != 1) || otherErr != nil || (i != 1) == (oldErr != nil) {
			t.Fatalf("swap case %d: err = %v; entry behind the link kept: %t; locked leftover removed: %t", i, err, otherErr == nil, oldErr != nil)
		}
	}
}
