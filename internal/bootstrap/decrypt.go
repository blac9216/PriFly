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

// Decrypt re-checks that v.Secrets still matches the digest Fetch verified,
// decrypts it with the age identities read from identityFile into a 0600 file
// inside a fresh 0700 directory under workDir, checks the plaintext schema and
// calls provision with that file's path. The directory is removed before
// Decrypt returns, on success and on every failure path, so the path is valid
// only during provision.
func Decrypt(v *Verified, identityFile, workDir string, provision func(path string) error) error {
	if v == nil {
		return ErrDigest
	}
	if sum := sha256.Sum256(v.Secrets); hex.EncodeToString(sum[:]) != v.Manifest.SecretsSHA256 {
		return ErrDigest
	}
	identities, err := readIdentities(identityFile)
	if err != nil {
		return err
	}
	tmp, err := os.MkdirTemp(workDir, "prifly-secrets-")
	if err != nil {
		return fmt.Errorf("%w: directory", ErrTransient)
	}
	defer os.RemoveAll(tmp)
	if os.Chmod(tmp, transientDirMode) != nil {
		return fmt.Errorf("%w: directory mode", ErrTransient)
	}
	path := filepath.Join(tmp, plaintextName)
	if err := decryptTo(path, v.Secrets, identities); err != nil {
		return err
	}
	if err := checkSecrets(path, v.Manifest); err != nil {
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

func decryptTo(path string, ciphertext []byte, identities []age.Identity) error {
	r, err := age.Decrypt(bytes.NewReader(ciphertext), identities...)
	if err != nil {
		return fmt.Errorf("%w: no identity matches or header invalid", ErrDecrypt)
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, transientFileMode)
	if err != nil {
		return fmt.Errorf("%w: file", ErrTransient)
	}
	_, err = io.Copy(f, r)
	if closeErr := f.Close(); err != nil || closeErr != nil {
		return fmt.Errorf("%w: payload failed authentication or could not be stored", ErrDecrypt)
	}
	return nil
}

func checkSecrets(path string, m Manifest) error {
	f, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("%w: file", ErrTransient)
	}
	defer f.Close()
	var s secretsFile
	dec := json.NewDecoder(f)
	dec.DisallowUnknownFields()
	if dec.Decode(&s) != nil || dec.Decode(&struct{}{}) != io.EOF {
		return fmt.Errorf("%w: not exactly one object of known fields", ErrSecrets)
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
