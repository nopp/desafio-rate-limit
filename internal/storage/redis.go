package storage

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisStorage implements the Storage interface using Redis
type RedisStorage struct {
	client *redis.Client
}

// NewRedisStorage creates a new Redis storage instance
func NewRedisStorage(addr, password string, db int) (*RedisStorage, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: password,
		DB:       db,
	})

	// Test the connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %w", err)
	}

	return &RedisStorage{
		client: rdb,
	}, nil
}

// Increment increments the counter for a given key using sliding window algorithm
func (r *RedisStorage) Increment(ctx context.Context, key string, window time.Duration) (int64, error) {
	now := time.Now()
	windowStart := now.Add(-window)

	// Use a sorted set to implement sliding window
	pipe := r.client.TxPipeline()

	// Remove expired entries
	pipe.ZRemRangeByScore(ctx, key, "0", strconv.FormatInt(windowStart.UnixNano(), 10))

	// Add current timestamp
	pipe.ZAdd(ctx, key, redis.Z{
		Score:  float64(now.UnixNano()),
		Member: now.UnixNano(),
	})

	// Count current entries in window
	count := pipe.ZCard(ctx, key)

	// Set expiration for the key
	pipe.Expire(ctx, key, window+time.Minute) // Add extra minute for safety

	_, err := pipe.Exec(ctx)
	if err != nil {
		return 0, fmt.Errorf("failed to increment counter: %w", err)
	}

	return count.Val(), nil
}

// Get returns the current counter value for a given key
func (r *RedisStorage) Get(ctx context.Context, key string) (int64, error) {
	count, err := r.client.ZCard(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return 0, nil
		}
		return 0, fmt.Errorf("failed to get counter: %w", err)
	}

	return count, nil
}

// SetBlockedUntil sets a key to be blocked until a specific time
func (r *RedisStorage) SetBlockedUntil(ctx context.Context, key string, until time.Time) error {
	blockedKey := "blocked:" + key
	duration := time.Until(until)

	if duration <= 0 {
		return nil // Already expired
	}

	err := r.client.Set(ctx, blockedKey, until.Unix(), duration).Err()
	if err != nil {
		return fmt.Errorf("failed to set blocked status: %w", err)
	}

	return nil
}

// IsBlocked checks if a key is currently blocked
func (r *RedisStorage) IsBlocked(ctx context.Context, key string) (bool, error) {
	blockedKey := "blocked:" + key

	result, err := r.client.Get(ctx, blockedKey).Result()
	if err != nil {
		if err == redis.Nil {
			return false, nil // Not blocked
		}
		return false, fmt.Errorf("failed to check blocked status: %w", err)
	}

	// Parse the timestamp and check if it's still valid
	timestamp, err := strconv.ParseInt(result, 10, 64)
	if err != nil {
		return false, fmt.Errorf("failed to parse blocked timestamp: %w", err)
	}

	blockedUntil := time.Unix(timestamp, 0)
	return time.Now().Before(blockedUntil), nil
}

// Close closes the Redis connection
func (r *RedisStorage) Close() error {
	return r.client.Close()
}
