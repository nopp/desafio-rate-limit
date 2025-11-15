package limiter

import (
	"context"
	"fmt"
	"time"

	"rate-limiter/internal/storage"
)

// RateLimiter implements rate limiting functionality
type RateLimiter struct {
	storage            storage.Storage
	ipRateLimit        int
	tokenRateLimit     int
	ipBlockDuration    time.Duration
	tokenBlockDuration time.Duration
}

// Config holds configuration for the rate limiter
type Config struct {
	IPRateLimit        int
	TokenRateLimit     int
	IPBlockDuration    time.Duration
	TokenBlockDuration time.Duration
}

// New creates a new rate limiter instance
func New(storage storage.Storage, config Config) *RateLimiter {
	return &RateLimiter{
		storage:            storage,
		ipRateLimit:        config.IPRateLimit,
		tokenRateLimit:     config.TokenRateLimit,
		ipBlockDuration:    config.IPBlockDuration,
		tokenBlockDuration: config.TokenBlockDuration,
	}
}

// CheckResult represents the result of a rate limit check
type CheckResult struct {
	Allowed      bool
	Limit        int
	Current      int
	ResetTime    time.Time
	BlockedUntil time.Time
}

// CheckIP checks if an IP address is allowed to make a request
func (rl *RateLimiter) CheckIP(ctx context.Context, ip string) (*CheckResult, error) {
	key := fmt.Sprintf("ip:%s", ip)
	return rl.check(ctx, key, rl.ipRateLimit, rl.ipBlockDuration)
}

// CheckToken checks if a token is allowed to make a request
func (rl *RateLimiter) CheckToken(ctx context.Context, token string) (*CheckResult, error) {
	key := fmt.Sprintf("token:%s", token)
	return rl.check(ctx, key, rl.tokenRateLimit, rl.tokenBlockDuration)
}

// check performs the actual rate limiting logic
func (rl *RateLimiter) check(ctx context.Context, key string, limit int, blockDuration time.Duration) (*CheckResult, error) {
	// First, check if the key is currently blocked
	blocked, err := rl.storage.IsBlocked(ctx, key)
	if err != nil {
		return nil, fmt.Errorf("failed to check blocked status: %w", err)
	}

	if blocked {
		// If blocked, return the blocked status
		return &CheckResult{
			Allowed:      false,
			Limit:        limit,
			Current:      limit,
			BlockedUntil: time.Now().Add(blockDuration),
		}, nil
	}

	// Increment the counter and get the current count
	window := time.Second
	current, err := rl.storage.Increment(ctx, key, window)
	if err != nil {
		return nil, fmt.Errorf("failed to increment counter: %w", err)
	}

	resetTime := time.Now().Add(window)

	// Check if limit exceeded
	if current > int64(limit) {
		// Block the key for the specified duration
		blockedUntil := time.Now().Add(blockDuration)
		if err := rl.storage.SetBlockedUntil(ctx, key, blockedUntil); err != nil {
			return nil, fmt.Errorf("failed to set blocked status: %w", err)
		}

		return &CheckResult{
			Allowed:      false,
			Limit:        limit,
			Current:      int(current),
			ResetTime:    resetTime,
			BlockedUntil: blockedUntil,
		}, nil
	}

	return &CheckResult{
		Allowed:   true,
		Limit:     limit,
		Current:   int(current),
		ResetTime: resetTime,
	}, nil
}
