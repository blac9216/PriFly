package bootstrap

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

const factory = "prifly-fixture-factory"

// Placeholder bytes standing in for age ciphertext; no key or secret exists.
var ciphertext = []byte("fixture ciphertext placeholder\n")

type entry struct{ mode, path, data string }

func manifestJSON(secrets []byte, extra string) string {
	sum := sha256.Sum256(secrets)
	return fmt.Sprintf(`{"schema":%q,"factory_id":%q,"secrets_path":%q,"secrets_sha256":%q,"secret_schema":"prifly.secrets/v1"%s}`,
		ManifestSchema, factory, SecretsPath, hex.EncodeToString(sum[:]), extra)
}

func validEntries() []entry {
	return []entry{{"100644", ManifestPath, manifestJSON(ciphertext, "")},
		{"100644", SecretsPath, string(ciphertext)}, {"100644", ReadmePath, "fixture\n"}}
}

// gitFixture runs git for fixture construction with an isolated configuration.
func gitFixture(t *testing.T, dir, stdin string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid"}, args...)...)
	cmd.Dir, cmd.Env, cmd.Stdin = dir, isolatedEnv(t.TempDir()), strings.NewReader(stdin)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("fixture git %v: %v\n%s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

// fixtureRepo builds a local repository whose single commit has exactly the
// given index entries (any mode, including symlinks and gitlinks).
func fixtureRepo(t *testing.T, entries []entry) (url, rev string) {
	t.Helper()
	dir := t.TempDir()
	gitFixture(t, dir, "", "init", "--quiet", "--template=", ".")
	for _, e := range entries {
		obj := gitFixture(t, dir, e.data, "hash-object", "-w", "--stdin")
		if e.mode == "160000" {
			obj = strings.Repeat("ab", 20)
		}
		gitFixture(t, dir, "", "update-index", "--add", "--cacheinfo", e.mode+","+obj+","+e.path)
	}
	tree := gitFixture(t, dir, "", "write-tree")
	rev = gitFixture(t, dir, "fixture\n", "commit-tree", tree)
	gitFixture(t, dir, "", "update-ref", "refs/heads/main", rev)
	gitFixture(t, dir, "", "tag", "v1", rev)
	return "file://" + dir, rev
}

func fetch(t *testing.T, url, rev string) (*Verified, error) {
	t.Helper()
	work := t.TempDir()
	v, err := Fetch(context.Background(), Request{Repository: url, Revision: rev, FactoryID: factory}, work)
	if left, _ := os.ReadDir(work); len(left) != 0 {
		t.Fatalf("work directory not cleaned: %d entries left", len(left))
	}
	if err != nil && strings.Contains(err.Error(), url) {
		t.Fatalf("error %q exposes the repository locator", err)
	}
	return v, err
}

func TestFetchReturnsVerifiedNonSecretBytes(t *testing.T) {
	url, rev := fixtureRepo(t, validEntries())
	v, err := fetch(t, url, rev)
	if err != nil {
		t.Fatalf("Fetch: %v", err)
	}
	if v.Revision != rev || v.Manifest.FactoryID != factory || string(v.Secrets) != string(ciphertext) {
		t.Fatalf("unexpected result %+v", v)
	}
}

func TestFetchRejectsMutableOrPartialRevision(t *testing.T) {
	url, rev := fixtureRepo(t, validEntries())
	for _, r := range []string{"main", "v1", "HEAD", "refs/heads/main", rev[:7], strings.ToUpper(rev), rev + strings.Repeat("0", 24)} {
		if _, err := fetch(t, url, r); !errors.Is(err, ErrMutableRef) {
			t.Errorf("revision %q: err = %v, want ErrMutableRef", r, err)
		}
	}
}

func TestFetchRejectsDisallowedTreeEntries(t *testing.T) {
	for name, bad := range map[string]entry{
		"executable":  {"100755", ManifestPath, "{}"},
		"symlink":     {"120000", ReadmePath, "fixture-target"},
		"submodule":   {"160000", ReadmePath, ""},
		".gitmodules": {"100644", ".gitmodules", "[submodule \"x\"]\n"},
		".gitattr":    {"100644", ".gitattributes", "* filter=x\n"},
		".githooks":   {"100755", ".githooks/post-checkout", "#!/bin/sh\n"},
		"other file":  {"100644", "run.sh", "echo\n"},
	} {
		t.Run(name, func(t *testing.T) {
			url, rev := fixtureRepo(t, append(validEntries(), bad)) // a later entry replaces a path
			if _, err := fetch(t, url, rev); !errors.Is(err, ErrTree) {
				t.Fatalf("err = %v, want ErrTree", err)
			}
		})
	}
}

func TestFetchRejectsInvalidManifest(t *testing.T) {
	for name, manifest := range map[string]string{
		"identity mismatch": strings.Replace(manifestJSON(ciphertext, ""), factory, "other-factory", 1),
		"unknown field":     manifestJSON(ciphertext, `,"extra":1`),
		"trailing data":     manifestJSON(ciphertext, "") + "{}",
		"schema":            strings.Replace(manifestJSON(ciphertext, ""), ManifestSchema, "prifly.bootstrap/v0", 1),
		"digest format":     strings.Replace(manifestJSON(ciphertext, ""), `"secrets_sha256":"`, `"secrets_sha256":"X`, 1),
	} {
		t.Run(name, func(t *testing.T) {
			entries := validEntries()
			entries[0].data = manifest
			url, rev := fixtureRepo(t, entries)
			if _, err := fetch(t, url, rev); !errors.Is(err, ErrManifest) {
				t.Fatalf("err = %v, want ErrManifest", err)
			}
		})
	}
}

func TestFetchRejectsSecretsDigestMismatch(t *testing.T) {
	entries := validEntries()
	entries[0].data = manifestJSON([]byte("different ciphertext\n"), "")
	url, rev := fixtureRepo(t, entries)
	if v, err := fetch(t, url, rev); !errors.Is(err, ErrDigest) || v != nil {
		t.Fatalf("result %v, err = %v, want nil and ErrDigest", v, err)
	}
}

func TestFetchUnreachableRepositoryOrRevision(t *testing.T) {
	url, rev := fixtureRepo(t, validEntries())
	missing := "file://" + filepath.Join(t.TempDir(), "absent-prifly-bootstrap")
	for name, c := range map[string][2]string{
		"repository": {missing, rev},
		"revision":   {url, strings.Repeat("1", 40)},
	} {
		// The message pins the fetch check itself, not a later ErrFetch.
		if v, err := fetch(t, c[0], c[1]); !errors.Is(err, ErrFetch) || v != nil ||
			!strings.Contains(err.Error(), "remote or revision unavailable") {
			t.Errorf("%s: result %v, err = %v, want nil and ErrFetch", name, v, err)
		}
	}
}

// hostileConfig writes a global Git config whose reference-transaction hook
// leaves a marker and whose insteadOf rule redirects the given locator.
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

// TestGitHardeningDisablesInheritedHooks runs the hardened invocation with the
// hostile global config deliberately inherited, and shows the same hook fires
// for an unhardened git so the control is not vacuous.
func TestGitHardeningDisablesInheritedHooks(t *testing.T) {
	url, rev := fixtureRepo(t, validEntries())
	config, marker := hostileConfig(t, "file:///unused-prifly/")
	env := append(os.Environ(), "GIT_CONFIG_GLOBAL="+config, "GIT_CONFIG_NOSYSTEM=1")
	repo := filepath.Join(t.TempDir(), "r.git")
	if _, err := runGit(context.Background(), env, "", "init", "--bare", "--quiet", "--template=", repo); err != nil {
		t.Fatal(err)
	}
	if _, err := runGit(context.Background(), env, repo, "fetch", "--quiet", url, rev+":refs/prifly/hardened"); err != nil {
		t.Fatalf("hardened fetch: %v", err)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Fatal("inherited reference-transaction hook ran under hardening")
	}
	plain := exec.Command("git", "fetch", "--quiet", url, rev+":refs/prifly/plain")
	plain.Dir, plain.Env = repo, env
	if out, err := plain.CombinedOutput(); err != nil {
		t.Fatalf("plain fetch: %v\n%s", err, out)
	}
	if _, err := os.Stat(marker); err != nil {
		t.Fatal("control: hook did not run for unhardened git, so the check is vacuous")
	}
}

// TestFetchIgnoresInheritedGitConfig sets a hostile global config that would
// redirect the fixture locator and run a hook; Fetch must not see either.
func TestFetchIgnoresInheritedGitConfig(t *testing.T) {
	url, rev := fixtureRepo(t, validEntries())
	config, marker := hostileConfig(t, url)
	t.Setenv("GIT_CONFIG_GLOBAL", config)
	t.Setenv("GIT_CONFIG_NOSYSTEM", "1")
	probe := exec.Command("git", "ls-remote", url)
	if probe.Run() == nil {
		t.Fatal("control: hostile config did not redirect an unisolated git")
	}
	if _, err := fetch(t, url, rev); err != nil {
		t.Fatalf("Fetch under hostile inherited config: %v", err)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Fatal("inherited hook ran during Fetch")
	}
}
