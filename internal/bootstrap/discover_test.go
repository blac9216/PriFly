//go:build linux

package bootstrap

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"testing"
)

// fakeDiscoverer is the local provider: it returns a fixed identity or error and
// records the secrets path it was given. No network or real bucket is involved.
type fakeDiscoverer struct {
	id   string
	err  error
	path string
}

func (f *fakeDiscoverer) Discover(_ context.Context, _ Manifest, secretsPath string) (string, error) {
	f.path = secretsPath
	return f.id, f.err
}

func TestDiscover(t *testing.T) {
	m := Manifest{FactoryID: factory}
	leak := errors.New("outage at bucket prifly-canary-bucket with " + canary)
	for name, c := range map[string]struct {
		d    Discoverer
		want error
	}{
		"existing state":    {&fakeDiscoverer{id: factory}, nil},
		"no provider":       {nil, ErrDiscoveryConfig},
		"missing config":    {&fakeDiscoverer{err: fmt.Errorf("%w: %v", ErrDiscoveryConfig, leak)}, ErrDiscoveryConfig},
		"provider outage":   {&fakeDiscoverer{err: leak}, ErrDiscovery},
		"inaccessible":      {&fakeDiscoverer{id: factory, err: leak}, ErrDiscovery},
		"absent state":      {&fakeDiscoverer{}, ErrNoFactory},
		"identity mismatch": {&fakeDiscoverer{id: "other-factory"}, ErrDiscovery},
	} {
		t.Run(name, func(t *testing.T) {
			err := Discover(context.Background(), c.d, m, "/secrets-path")
			if !errors.Is(err, c.want) || (c.want == nil) != (err == nil) {
				t.Fatalf("err = %v, want %v", err, c.want)
			}
			if msg := fmt.Sprint(err); strings.Contains(msg, "prifly-canary") || strings.Contains(msg, "/secrets-path") {
				t.Fatalf("error exposes provider output or path: %q", msg)
			}
			if f, ok := c.d.(*fakeDiscoverer); ok && f.path != "/secrets-path" {
				t.Fatalf("provider got secrets path %q", f.path)
			}
		})
	}
}
