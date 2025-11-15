package storage

import (
	"context"
	"time"
)

// Storage defines the interface for rate limiter storage implementations
type Storage interface {
	// Increment increments the counter for a given key and returns the new value
	Increment(ctx context.Context, key string, window time.Duration) (int64, error)

	// Get returns the current counter value for a given key
	Get(ctx context.Context, key string) (int64, error)

	// SetBlockedUntil sets a key to be blocked until a specific time
	SetBlockedUntil(ctx context.Context, key string, until time.Time) error

	// IsBlocked checks if a key is currently blocked
	IsBlocked(ctx context.Context, key string) (bool, error)

	// Close closes the storage connection
	Close() error
}
