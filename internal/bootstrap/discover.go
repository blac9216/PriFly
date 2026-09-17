package bootstrap

import (
	"context"
	"errors"
	"fmt"
)

// Discovery failure classes. Each blocks startup; none initializes a Factory, and
// none carries provider output, coordinates or secrets.
var (
	ErrDiscoveryConfig = errors.New("bootstrap: remote discovery configuration missing or unusable")
	ErrDiscovery       = errors.New("bootstrap: remote Factory state could not be discovered")
	ErrNoFactory       = errors.New("bootstrap: no existing Factory state; starting a new Factory requires the explicit new-identity action, which bootstrap does not perform")
)

// Discoverer reads the remote coordination state the manifest names, using the
// decrypted secrets file at secretsPath. It returns the Factory identity recorded
// there, "" when the remote holds no Factory state, or an error when it cannot
// decide; an error wrapping ErrDiscoveryConfig means its configuration is missing.
type Discoverer interface {
	Discover(ctx context.Context, m Manifest, secretsPath string) (factoryID string, err error)
}

// Discover succeeds only when d positively finds existing state for m.FactoryID.
// A missing provider or configuration, an outage, an inaccessible bucket, absent
// state and a mismatched identity each return an error, so a caller that treats
// any error as blocking can never initialize an empty Factory.
func Discover(ctx context.Context, d Discoverer, m Manifest, secretsPath string) error {
	if d == nil {
		return fmt.Errorf("%w: no provider", ErrDiscoveryConfig)
	}
	id, err := d.Discover(ctx, m, secretsPath)
	switch {
	case errors.Is(err, ErrDiscoveryConfig):
		return fmt.Errorf("%w: provider", ErrDiscoveryConfig)
	case err != nil:
		return fmt.Errorf("%w: provider unavailable or state inaccessible", ErrDiscovery)
	case id == "":
		return ErrNoFactory
	case id != m.FactoryID:
		return fmt.Errorf("%w: factory identity mismatch", ErrDiscovery)
	}
	return nil
}
