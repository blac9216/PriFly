package bootstrap

import (
	"bytes"
	"cmp"
	"crypto/sha256"
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
	m := Manifest{ManifestSchema, factory, SecretsPath, fmt.Sprintf("%x", sha256.Sum256(buf.Bytes())), SecretSchema}
	return &Verified{Revision: strings.Repeat("a", 40), Manifest: m, Secrets: buf.Bytes()}
}

// capture runs f with file descriptors 1 and 2 redirected to files and returns what each received.
func capture(t *testing.T, f func()) (stdout, stderr string) {
	t.Helper()
	for i, fd := range []int{1, 2} {
		file, err := os.Create(filepath.Join(t.TempDir(), "fd"))
		saved, dupErr := unix.Dup(fd)
		if err != nil || dupErr != nil || unix.Dup2(int(file.Fd()), fd) != nil {
			t.Fatal("redirecting output")
		}
		defer func() {
			_, _ = unix.Dup2(saved, fd), unix.Close(saved)
			data, _ := os.ReadFile(file.Name())
			*[]*string{&stdout, &stderr}[i] = string(data)
			file.Close()
		}()
	}
	f()
	return
}

// errPanic is provision's panic value in the "provision panic" row; inWork stands for the helper's work directory.
var errPanic, inWork = errors.New("provision panicked"), "<work>"

// decrypt runs Decrypt in dir with TMPDIR empty, asserts on the filesystem that provision's file is in a directory created in
// work while TMPDIR is empty and that both are empty afterwards, and that no canary, age identity or work path is output.
func decrypt(t *testing.T, v *Verified, identityFile, dir string, provision func(string) error) (stdout, stderr string, err error, panicked bool) {
	t.Helper()
	work, tmpdir, at := t.TempDir(), t.TempDir(), ""
	count := func(dir string) int { entries, _ := os.ReadDir(dir); return len(entries) }
	t.Setenv("TMPDIR", tmpdir)
	stdout, stderr = capture(t, func() {
		defer func() { p := recover(); r, _ := p.(error); err, panicked = cmp.Or(r, err), p != nil }()
		err = Decrypt(v, identityFile, strings.Replace(dir, inWork, work, 1), func(path string) error {
			at = filepath.Dir(filepath.Dir(path)) + strings.Repeat(" and TMPDIR", count(tmpdir))
			return provision(path)
		})
	})
	if count(work)+count(tmpdir) != 0 || (at != "" && at != work) {
		t.Fatalf("plaintext outside work or not removed: %d entries left in work, %d in TMPDIR; provisioned in %q", count(work), count(tmpdir), at)
	}
	for where, text := range map[string]string{"stdout": stdout, "stderr": stderr, "error": fmt.Sprint(err)} {
		if strings.Contains(text, canary) || strings.Contains(text, "AGE-SECRET-KEY-") || strings.Contains(text, work) {
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
		return map[bool]error{false: errors.New("transient plaintext unprotected")}[ok]
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
			if lim := (unix.Rlimit{}); name == "write failure" && unix.Getrlimit(unix.RLIMIT_FSIZE, &lim) == nil {
				defer unix.Setrlimit(unix.RLIMIT_FSIZE, &lim) // the limit is process-wide, so it is lifted when the row ends
				_ = unix.Setrlimit(unix.RLIMIT_FSIZE, &unix.Rlimit{Cur: 16, Max: lim.Max})
			}
			before := calls
			stdout, stderr, err, panicked := decrypt(t, c.v, c.identity, c.dir, c.provision)
			if !errors.Is(err, c.want) || (c.want == nil) != (err == nil) || calls != before || stdout+"|"+stderr != c.output || panicked != (name == "provision panic") {
				t.Fatalf("err = %v, want %v; refused provision called %t; output %q|%q; panicked %t", err, c.want, calls != before, stdout, stderr, panicked)
			}
		})
	}
}
