package bootstrap

import (
	"bytes"
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

// seal encrypts plaintext to id and returns it as Fetch would have verified it.
func seal(t *testing.T, id *age.X25519Identity, plaintext string) *Verified {
	t.Helper()
	var buf bytes.Buffer
	w, err := age.Encrypt(&buf, id.Recipient())
	if err != nil {
		t.Fatal("encrypting fixture")
	}
	if _, err := io.WriteString(w, plaintext); err != nil || w.Close() != nil {
		t.Fatal("encrypting fixture")
	}
	m := Manifest{ManifestSchema, factory, SecretsPath, fmt.Sprintf("%x", sha256.Sum256(buf.Bytes())), SecretSchema}
	return &Verified{Revision: strings.Repeat("a", 40), Manifest: m, Secrets: buf.Bytes()}
}

// capture runs f with file descriptors 1 and 2 redirected to files and returns what each received.
func capture(t *testing.T, f func()) (stdout, stderr string) {
	t.Helper()
	got := [2]string{}
	defer func() { stdout, stderr = got[0], got[1] }()
	for i, fd := range []int{1, 2} {
		file, err := os.Create(filepath.Join(t.TempDir(), "fd"))
		saved, dupErr := unix.Dup(fd)
		if err != nil || dupErr != nil || unix.Dup2(int(file.Fd()), fd) != nil {
			t.Fatal("redirecting output")
		}
		defer func() {
			_, _ = unix.Dup2(saved, fd), unix.Close(saved)
			data, _ := os.ReadFile(file.Name())
			got[i] = string(data)
			file.Close()
		}()
	}
	f()
	return
}

// decrypt runs Decrypt and asserts that the work directory is emptied and that
// neither the canary nor any age identity reaches stdout, stderr or the error.
func decrypt(t *testing.T, v *Verified, identityFile string, provision func(string) error) (stdout, stderr string, err error) {
	t.Helper()
	work := t.TempDir()
	stdout, stderr = capture(t, func() { err = Decrypt(v, identityFile, work, provision) })
	if left, _ := os.ReadDir(work); len(left) != 0 {
		t.Fatalf("transient storage not removed: %d entries left", len(left))
	}
	for where, text := range map[string]string{"stdout": stdout, "stderr": stderr, "error": fmt.Sprint(err)} {
		if strings.Contains(text, canary) || strings.Contains(text, "AGE-SECRET-KEY-") {
			t.Fatalf("%s exposes a secret or identity: %q", where, text)
		}
	}
	return stdout, stderr, err
}

func TestDecryptProvisionsProtectedTransientSecrets(t *testing.T) {
	id, identityFile := newIdentity(t)
	defer unix.Umask(unix.Umask(0)) // modes must not depend on a restrictive umask
	var seen string
	provision := func(path string) error {
		dir, errDir := os.Stat(filepath.Dir(path))
		file, errFile := os.Lstat(path)
		data, errRead := os.ReadFile(path)
		if errDir == nil && errFile == nil && errRead == nil {
			seen = fmt.Sprintf("dir %v file %v decrypted %t", dir.Mode(), file.Mode(), strings.Contains(string(data), canary))
		}
		fmt.Fprint(os.Stdout, "prifly-capture-stdout")
		fmt.Fprint(os.Stderr, "prifly-capture-stderr")
		return nil
	}
	stdout, stderr, err := decrypt(t, seal(t, id, secretsJSON("", "")), identityFile, provision)
	if err != nil || seen != "dir drwx------ file -rw------- decrypted true" {
		t.Fatalf("err = %v, transient plaintext: %q", err, seen)
	}
	if stdout != "prifly-capture-stdout" || stderr != "prifly-capture-stderr" {
		t.Fatalf("control: output capture saw %q and %q, so the absence checks are vacuous", stdout, stderr)
	}
}

func TestDecryptFailsClosed(t *testing.T) {
	id, identityFile := newIdentity(t)
	_, otherFile := newIdentity(t)
	valid := seal(t, id, secretsJSON("", ""))
	substituted := seal(t, id, secretsJSON(`"r2"`, `"other"`))
	substituted.Manifest.SecretsSHA256 = valid.Manifest.SecretsSHA256
	otherSchema := *valid
	otherSchema.Manifest.SecretSchema = "prifly.secrets/v2"
	with := func(old, new string) *Verified { return seal(t, id, secretsJSON(old, new)) }
	for name, c := range map[string]struct {
		v        *Verified
		identity string
		want     error
	}{
		"missing key":        {valid, filepath.Join(t.TempDir(), "absent"), ErrIdentity},
		"key as argument":    {valid, id.String(), ErrIdentity},
		"wrong key":          {valid, otherFile, ErrDecrypt},
		"unverified bytes":   {substituted, identityFile, ErrDigest},
		"nil result":         {nil, identityFile, ErrDigest},
		"schema":             {with(SecretSchema, "prifly.secrets/v0"), identityFile, ErrSecrets},
		"manifest schema id": {&otherSchema, identityFile, ErrSecrets},
		"factory":            {with(factory, "other-factory"), identityFile, ErrSecrets},
		"unknown field":      {with(`"generation"`, `"rotated":1,"generation"`), identityFile, ErrSecrets},
		"trailing data":      {with(`]}`, `]}{}`), identityFile, ErrSecrets},
		"empty list":         {seal(t, id, fmt.Sprintf(`{"schema":%q,"factory_id":%q,"secrets":[]}`, SecretSchema, factory)), identityFile, ErrSecrets},
		"generation":         {with(`"generation":1`, `"generation":0`), identityFile, ErrSecrets},
		"missing value":      {with(`"value":"`+canary, `"value":"`), identityFile, ErrSecrets},
		"duplicate id":       {with(`}]}`, `},{"id":"r2","purpose":"p","generation":1,"value":"v"}]}`), identityFile, ErrSecrets},
	} {
		t.Run(name, func(t *testing.T) {
			called := false
			_, _, err := decrypt(t, c.v, c.identity, func(string) error { called = true; return nil })
			if !errors.Is(err, c.want) || called {
				t.Fatalf("err = %v, want %v; provision called %t", err, c.want, called)
			}
		})
	}
	t.Run("provision error", func(t *testing.T) {
		_, _, err := decrypt(t, valid, identityFile, func(string) error { return errors.New("consumer failed on " + canary) })
		if !errors.Is(err, ErrProvision) {
			t.Fatalf("err = %v, want ErrProvision", err)
		}
	})
}

// Decrypt accepts the bytes Fetch verified from a fixture repository.
func TestDecryptFetchedSecrets(t *testing.T) {
	id, identityFile := newIdentity(t)
	sealed := seal(t, id, secretsJSON("", ""))
	m := strings.Replace(manifest, digestHex, sealed.Manifest.SecretsSHA256, 1)
	url, rev := fixtureRepo(t, []entry{{"100644", ManifestPath, m}, {"100644", SecretsPath, string(sealed.Secrets)}})
	v, err := fetch(t, url, rev, factory)
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	if _, _, err := decrypt(t, v, identityFile, func(string) error { return nil }); err != nil {
		t.Fatalf("decrypt: %v", err)
	}
}
