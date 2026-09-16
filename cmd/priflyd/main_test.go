package main

import (
	"context"
	"testing"
)

func TestShutdownReturnsNil(t *testing.T) {
	if err := shutdown(context.Background()); err != nil {
		t.Fatalf("shutdown() error = %v, want nil", err)
	}
}
