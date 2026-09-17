package bootstrap

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"syscall"

	"filippo.io/age"
)

// SecretSchema is the only decrypted-secrets schema this package accepts.
const SecretSchema = "prifly.secrets/v1"

// Decryption failure classes. Like the fetch errors, they never carry the
// identity, the plaintext, a file path or a wrapped library or consumer error.
var (
	ErrIdentity  = errors.New("bootstrap: age identity file unreadable or holds no identity")
	ErrDecrypt   = errors.New("bootstrap: secrets do not decrypt with the supplied identity")
	ErrSecrets   = errors.New("bootstrap: decrypted secrets invalid")
	ErrTransient = errors.New("bootstrap: protected transient storage unavailable")
	ErrProvision = errors.New("bootstrap: provisioning from decrypted secrets failed")
)

const (
	transientDirMode  os.FileMode = 0o700
	transientFileMode os.FileMode = 0o600
	plaintextName                 = "secrets.json"
)

type secretsFile struct {
	Schema    string   `json:"schema"`
	FactoryID string   `json:"factory_id"`
	Secrets   []secret `json:"secrets"`
}

type secret struct {
	ID         string `json:"id"`
	Purpose    string `json:"purpose"`
	Generation int    `json:"generation"`
	Value      string `json:"value"`
}

// Decrypt re-checks that v.Secrets still matches the digest Fetch verified, decrypts it with the age
// identities read from identityFile into a 0600 file in a fresh 0700 directory created in workDir, an
// absolute path, checks the plaintext schema and calls provision with that file's path. Nothing is
// written outside workDir. The directory is removed before Decrypt returns, on success, on every failure
// and when provision panics (the panic continues), so the path is valid only during provision.
func Decrypt(v *Verified, identityFile, workDir string, provision func(path string) error) error {
	if v == nil {
		return ErrDigest
	}
	if sum := sha256.Sum256(v.Secrets); hex.EncodeToString(sum[:]) != v.Manifest.SecretsSHA256 {
		return ErrDigest
	}
	if !filepath.IsAbs(workDir) {
		return fmt.Errorf("%w: work directory is not an absolute path", ErrTransient)
	}
	identities, err := readIdentities(identityFile)
	if err != nil {
		return err
	}
	r, err := age.Decrypt(bytes.NewReader(v.Secrets), identities...)
	if err != nil {
		return fmt.Errorf("%w: no identity matches or header invalid", ErrDecrypt)
	}
	tmp, err := os.MkdirTemp(workDir, "prifly-secrets-")
	defer os.RemoveAll(tmp) // tmp is "" after a MkdirTemp error, and RemoveAll("") does nothing
	path, f := filepath.Join(tmp, plaintextName), (*os.File)(nil)
	if err == nil && os.Chmod(tmp, transientDirMode) == nil {
		f, _ = os.OpenFile(path, os.O_RDWR|os.O_CREATE|os.O_EXCL, transientFileMode)
	}
	if f == nil {
		return fmt.Errorf("%w: cannot create", ErrTransient)
	}
	defer f.Close()
	n, err := io.Copy(f, r)
	if pathErr := (*os.PathError)(nil); errors.As(err, &pathErr) { // only writing f can; age reads in-memory bytes
		return fmt.Errorf("%w: cannot write", ErrTransient)
	}
	if err != nil {
		return fmt.Errorf("%w: payload failed authentication", ErrDecrypt)
	}
	if err := checkSecrets(f, n, v.Manifest); err != nil {
		return err
	}
	if provision(path) != nil {
		return ErrProvision
	}
	return nil
}

// readIdentities takes the identity only from the named file, never from the
// argument's own text.
func readIdentities(identityFile string) ([]age.Identity, error) {
	f, err := os.Open(identityFile)
	if err != nil {
		return nil, fmt.Errorf("%w: cannot open", ErrIdentity)
	}
	defer f.Close()
	identities, err := age.ParseIdentities(f)
	if err != nil {
		return nil, fmt.Errorf("%w: no parsable identity", ErrIdentity)
	}
	return identities, nil
}

// secretKeys are the member names checkSecrets accepts, spelled exactly. encoding/json alone matches names
// case-insensitively and keeps the last duplicate, so a consumer of the file could read another value.
var secretKeys = map[string]bool{"schema": true, "factory_id": true, "secrets": true, "id": true, "purpose": true, "generation": true, "value": true}

var errMember = errors.New("duplicate or inexactly spelled member name")

// strictMembers rejects a duplicate member name, or one not spelled exactly as in keys, at any depth of one JSON value.
func strictMembers(dec *json.Decoder, keys map[string]bool) error {
	tok, err := dec.Token()
	if err != nil || (tok != json.Delim('{') && tok != json.Delim('[')) {
		return err
	}
	for seen := map[string]bool{}; dec.More(); {
		if tok == json.Delim('{') {
			name, err := dec.Token()
			if key, _ := name.(string); err != nil || seen[key] || !keys[key] {
				return errMember
			}
			seen[name.(string)] = true
		}
		if err := strictMembers(dec, keys); err != nil {
			return err
		}
	}
	_, err = dec.Token()
	return err
}

func checkSecrets(f io.ReaderAt, n int64, m Manifest) error {
	var s secretsFile
	dec := json.NewDecoder(io.NewSectionReader(f, 0, n))
	dec.DisallowUnknownFields()
	if strictMembers(json.NewDecoder(io.NewSectionReader(f, 0, n)), secretKeys) != nil || dec.Decode(&s) != nil || dec.Decode(&struct{}{}) != io.EOF {
		return fmt.Errorf("%w: not exactly one object of known, unique, exactly spelled fields", ErrSecrets)
	}
	switch {
	case s.Schema != SecretSchema || s.Schema != m.SecretSchema:
		return fmt.Errorf("%w: unsupported schema", ErrSecrets)
	case s.FactoryID != m.FactoryID:
		return fmt.Errorf("%w: factory identity mismatch", ErrSecrets)
	case len(s.Secrets) == 0:
		return fmt.Errorf("%w: no secrets", ErrSecrets)
	}
	seen := map[string]bool{}
	for _, e := range s.Secrets {
		if e.ID == "" || seen[e.ID] || e.Purpose == "" || e.Generation < 1 || e.Value == "" {
			return fmt.Errorf("%w: each secret needs a unique id, a purpose, generation >= 1 and a value", ErrSecrets)
		}
		seen[e.ID] = true
	}
	return nil
}

var (
	// transientName matches exactly the names os.MkdirTemp gives the directories Fetch and Decrypt create.
	transientName = regexp.MustCompile(`^prifly-(bootstrap|secrets)-[0-9]+$`)
	currentUID    = os.Getuid          // replaced only by tests
	claimHook     = func(stage int) {} // replaced only by tests: 0 after locking, 1 before sweeping
)

// ClaimWorkDir locks workDir, an absolute path to a directory that is not a symbolic link, for one bootstrap
// run, then removes the transient directories that a run killed before its own cleanup left there. It removes
// only an entry named as Fetch or Decrypt names theirs that is a real 0700 directory owned by this user. Every
// inspection and removal resolves relative to the locked directory itself (an os.Root proven to be the same
// directory), never through the workDir path again, so replacing that path afterwards, say by a symbolic
// link, cannot redirect them; nothing outside the locked directory is touched. Any other entry with such a
// name, a lock another run holds, or a path that no longer names the locked directory returns ErrTransient.
// The claim lasts until release is called.
func ClaimWorkDir(workDir string) (release func(), err error) {
	d, err := os.OpenFile(workDir, os.O_RDONLY|syscall.O_DIRECTORY|syscall.O_NOFOLLOW, 0)
	if err != nil || !filepath.IsAbs(workDir) {
		d.Close() // a nil *os.File's Close only returns an error
		return nil, fmt.Errorf("%w: work directory unusable", ErrTransient)
	}
	var root *os.Root
	defer func() {
		if err != nil {
			d.Close()
			if root != nil {
				root.Close()
			}
		}
	}()
	if syscall.Flock(int(d.Fd()), syscall.LOCK_EX|syscall.LOCK_NB) != nil {
		return nil, fmt.Errorf("%w: work directory in use by another run", ErrTransient)
	}
	claimHook(0)
	if root, err = os.OpenRoot(workDir); err == nil {
		locked, derr := d.Stat()
		opened, rerr := root.Stat(".")
		if derr != nil || rerr != nil || !os.SameFile(locked, opened) {
			err = ErrTransient
		}
	}
	if err != nil {
		return nil, fmt.Errorf("%w: work directory changed while claimed", ErrTransient)
	}
	entries, err := d.ReadDir(-1)
	if err != nil {
		return nil, fmt.Errorf("%w: work directory unreadable", ErrTransient)
	}
	claimHook(1)
	for _, e := range entries {
		if !transientName.MatchString(e.Name()) {
			continue
		}
		fi, lerr := root.Lstat(e.Name())
		if lerr != nil {
			return nil, fmt.Errorf("%w: unexpected transient entry in work directory", ErrTransient)
		}
		if st, ok := fi.Sys().(*syscall.Stat_t); !ok || !fi.IsDir() || fi.Mode().Perm() != transientDirMode || int(st.Uid) != currentUID() {
			return nil, fmt.Errorf("%w: unexpected transient entry in work directory", ErrTransient)
		}
		if root.RemoveAll(e.Name()) != nil {
			return nil, fmt.Errorf("%w: cannot remove leftover transient directory", ErrTransient)
		}
	}
	return func() { root.Close(); d.Close() }, nil
}
