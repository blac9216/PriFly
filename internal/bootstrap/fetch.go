// Package bootstrap fetches the owner-selected revision of a private bootstrap
// Git repository and verifies it before anything is decrypted. It returns only
// non-secret bytes: the manifest and the still-encrypted secrets file.
package bootstrap

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

// Fixed repository layout and manifest schema.
const (
	ManifestPath   = "bootstrap.json"
	SecretsPath    = "secrets.json.age"
	ReadmePath     = "README.md"
	ManifestSchema = "prifly.bootstrap/v1"
)

// Failure classes. Errors wrap exactly one of these and never carry the
// repository locator, Git output or file contents.
var (
	ErrMutableRef = errors.New("bootstrap: revision must be a full 40-hex commit id")
	ErrFetch      = errors.New("bootstrap: fetch of selected revision failed")
	ErrTree       = errors.New("bootstrap: revision tree has a disallowed entry")
	ErrManifest   = errors.New("bootstrap: manifest invalid")
	ErrDigest     = errors.New("bootstrap: secrets digest does not match manifest")
)

// Request names the Recovery Kit inputs for one fetch.
type Request struct {
	Repository string // Git locator of the private bootstrap repository
	Revision   string // exact commit id selected by the owner
	FactoryID  string // expected Factory identity
}

// Manifest is the non-secret bootstrap.json.
type Manifest struct {
	Schema        string `json:"schema"`
	FactoryID     string `json:"factory_id"`
	SecretsPath   string `json:"secrets_path"`
	SecretsSHA256 string `json:"secrets_sha256"`
	SecretSchema  string `json:"secret_schema"`
}

// Verified is the result of a successful fetch. Secrets is still encrypted.
type Verified struct {
	Revision string
	Manifest Manifest
	Secrets  []byte
}

var (
	commitID = regexp.MustCompile(`^[0-9a-f]{40}$`)
	digest   = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

// hardening applies to every Git invocation: no hooks, and only the file,
// https and ssh transports.
var hardening = []string{"-c", "core.hooksPath=/dev/null", "-c", "protocol.allow=never",
	"-c", "protocol.file.allow=always", "-c", "protocol.https.allow=always", "-c", "protocol.ssh.allow=always"}

// isolatedEnv drops the inherited environment, so no system or global Git
// configuration, template or GIT_* variable reaches the fetch.
func isolatedEnv(home string) []string {
	return []string{"PATH=" + os.Getenv("PATH"), "HOME=" + home, "LC_ALL=C",
		"GIT_CONFIG_NOSYSTEM=1", "GIT_CONFIG_GLOBAL=/dev/null", "GIT_TERMINAL_PROMPT=0"}
}

func runGit(ctx context.Context, env []string, dir string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, "git", append(append([]string{}, hardening...), args...)...)
	cmd.Dir, cmd.Env, cmd.Stderr = dir, env, io.Discard
	return cmd.Output()
}

// Fetch retrieves req.Revision into a private repository under workDir, checks
// its tree, manifest and secrets digest, and removes everything it created
// before returning.
func Fetch(ctx context.Context, req Request, workDir string) (*Verified, error) {
	if !commitID.MatchString(req.Revision) {
		return nil, ErrMutableRef
	}
	tmp, err := os.MkdirTemp(workDir, "prifly-bootstrap-")
	if err != nil {
		return nil, fmt.Errorf("%w: work directory unavailable", ErrFetch)
	}
	defer os.RemoveAll(tmp)
	env, repo := isolatedEnv(tmp), filepath.Join(tmp, "repo.git")
	git := func(args ...string) ([]byte, error) { return runGit(ctx, env, repo, args...) }

	if _, err := runGit(ctx, env, tmp, "init", "--bare", "--quiet", "--template=", repo); err != nil {
		return nil, fmt.Errorf("%w: init", ErrFetch)
	}
	if _, err := git("fetch", "--quiet", "--no-tags", "--end-of-options",
		req.Repository, req.Revision+":refs/prifly/selected"); err != nil {
		return nil, fmt.Errorf("%w: remote or revision unavailable", ErrFetch)
	}
	if out, err := git("rev-parse", "--verify", "--end-of-options", req.Revision+"^{commit}"); err != nil ||
		strings.TrimSpace(string(out)) != req.Revision {
		return nil, fmt.Errorf("%w: revision is not a commit", ErrFetch)
	}
	tree, err := git("ls-tree", "-z", "--end-of-options", req.Revision)
	if err != nil {
		return nil, fmt.Errorf("%w: tree unreadable", ErrFetch)
	}
	if err := checkTree(tree); err != nil {
		return nil, err
	}
	manifestBytes, err1 := git("cat-file", "blob", req.Revision+":"+ManifestPath)
	secrets, err2 := git("cat-file", "blob", req.Revision+":"+SecretsPath)
	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("%w: file unreadable", ErrFetch)
	}
	m, err := parseManifest(manifestBytes, req.FactoryID)
	if err != nil {
		return nil, err
	}
	sum := sha256.Sum256(secrets)
	if hex.EncodeToString(sum[:]) != m.SecretsSHA256 {
		return nil, ErrDigest
	}
	return &Verified{Revision: req.Revision, Manifest: m, Secrets: secrets}, nil
}

// checkTree admits only the three top-level regular, non-executable files of
// the fixed layout, and requires the manifest and secrets file.
func checkTree(listing []byte) error {
	allowed := map[string]bool{ManifestPath: false, SecretsPath: false, ReadmePath: false}
	for _, rec := range strings.Split(strings.TrimSuffix(string(listing), "\x00"), "\x00") {
		meta, name, ok := strings.Cut(rec, "\t")
		if _, known := allowed[name]; !ok || !known {
			return fmt.Errorf("%w: %q is not in the allowlist", ErrTree, name)
		}
		if !strings.HasPrefix(meta, "100644 blob ") {
			return fmt.Errorf("%w: %q is not a regular non-executable file", ErrTree, name)
		}
		allowed[name] = true
	}
	if !allowed[ManifestPath] || !allowed[SecretsPath] {
		return fmt.Errorf("%w: %s and %s are required", ErrTree, ManifestPath, SecretsPath)
	}
	return nil
}

func parseManifest(data []byte, factoryID string) (Manifest, error) {
	var m Manifest
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&m); err != nil || dec.Decode(&struct{}{}) != io.EOF {
		return Manifest{}, fmt.Errorf("%w: not exactly one object of known fields", ErrManifest)
	}
	switch {
	case m.Schema != ManifestSchema:
		return Manifest{}, fmt.Errorf("%w: unsupported schema", ErrManifest)
	case factoryID == "" || m.FactoryID != factoryID:
		return Manifest{}, fmt.Errorf("%w: factory identity mismatch", ErrManifest)
	case m.SecretsPath != SecretsPath:
		return Manifest{}, fmt.Errorf("%w: secrets_path must be %s", ErrManifest, SecretsPath)
	case !digest.MatchString(m.SecretsSHA256):
		return Manifest{}, fmt.Errorf("%w: secrets_sha256 must be 64 lowercase hex", ErrManifest)
	case m.SecretSchema == "":
		return Manifest{}, fmt.Errorf("%w: secret_schema is required", ErrManifest)
	}
	return m, nil
}
