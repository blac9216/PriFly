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
	if err != nil {
		return fmt.Errorf("%w: payload failed authentication or could not be stored", ErrDecrypt)
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

// strictMembers rejects a duplicate or inexactly spelled member name at any depth of one JSON value.
func strictMembers(dec *json.Decoder) error {
	tok, err := dec.Token()
	if err != nil || (tok != json.Delim('{') && tok != json.Delim('[')) {
		return err
	}
	seen := map[string]bool{}
	for dec.More() {
		if tok == json.Delim('{') {
			name, err := dec.Token()
			if key, _ := name.(string); err != nil || seen[key] || !secretKeys[key] {
				return ErrSecrets
			}
			seen[name.(string)] = true
		}
		if err := strictMembers(dec); err != nil {
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
	if strictMembers(json.NewDecoder(io.NewSectionReader(f, 0, n))) != nil || dec.Decode(&s) != nil || dec.Decode(&struct{}{}) != io.EOF {
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
