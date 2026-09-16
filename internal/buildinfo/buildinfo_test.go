package buildinfo

import "testing"

// TestCurrentReflectsPackageVariables demonstrates that Current() surfaces
// the Version/Commit currently held by the package variables (which
// -ldflags -X overrides at link time) plus the fixed SchemaVersion.
func TestCurrentReflectsPackageVariables(t *testing.T) {
	origVersion, origCommit := Version, Commit
	t.Cleanup(func() { Version, Commit = origVersion, origCommit })

	Version, Commit = "v9.9.9", "deadbeef"

	got := Current()
	want := Info{Version: "v9.9.9", Commit: "deadbeef", Schema: SchemaVersion}
	if got != want {
		t.Fatalf("Current() = %+v, want %+v", got, want)
	}
}

func TestInfoStringIsDeterministicAndIncludesSubjectIdentity(t *testing.T) {
	i := Info{Version: "v1.2.3", Commit: "abc123", Schema: "v1"}
	want := "version=v1.2.3 commit=abc123 schema=v1"
	if got := i.String(); got != want {
		t.Fatalf("String() = %q, want %q", got, want)
	}
	if got2 := i.String(); got2 != want { // deterministic across calls
		t.Fatalf("String() not deterministic: %q vs %q", got2, want)
	}
}

// TestDefaultsAreNonEmpty is the negative-adjacent check: a plain,
// unmodified build (no -ldflags -X) must still report a fixed, non-empty
// subject identity rather than an empty or randomized value.
func TestDefaultsAreNonEmpty(t *testing.T) {
	for name, v := range map[string]string{"Version": Version, "Commit": Commit, "SchemaVersion": SchemaVersion} {
		if v == "" {
			t.Fatalf("default %s must not be empty", name)
		}
	}
}
