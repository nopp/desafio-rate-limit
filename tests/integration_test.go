package tests

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"rate-limiter/internal/limiter"
	"rate-limiter/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

// InMemoryStorage is a simple in-memory storage for testing
type InMemoryStorage struct {
	counters map[string][]time.Time
	blocked  map[string]time.Time
}

func NewInMemoryStorage() *InMemoryStorage {
	return &InMemoryStorage{
		counters: make(map[string][]time.Time),
		blocked:  make(map[string]time.Time),
	}
}

func (s *InMemoryStorage) Increment(ctx context.Context, key string, window time.Duration) (int64, error) {
	now := time.Now()
	windowStart := now.Add(-window)

	// Clean old entries
	timestamps := s.counters[key]
	var validTimestamps []time.Time
	for _, ts := range timestamps {
		if ts.After(windowStart) {
			validTimestamps = append(validTimestamps, ts)
		}
	}

	// Add current timestamp
	validTimestamps = append(validTimestamps, now)
	s.counters[key] = validTimestamps

	return int64(len(validTimestamps)), nil
}

func (s *InMemoryStorage) Get(ctx context.Context, key string) (int64, error) {
	return int64(len(s.counters[key])), nil
}

func (s *InMemoryStorage) SetBlockedUntil(ctx context.Context, key string, until time.Time) error {
	s.blocked[key] = until
	return nil
}

func (s *InMemoryStorage) IsBlocked(ctx context.Context, key string) (bool, error) {
	until, exists := s.blocked[key]
	if !exists {
		return false, nil
	}
	return time.Now().Before(until), nil
}

func (s *InMemoryStorage) Close() error {
	return nil
}

func setupTestRouter(rateLimiter *limiter.RateLimiter) *gin.Engine {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(middleware.RateLimitMiddleware(rateLimiter))

	router.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "success"})
	})

	return router
}

func TestRateLimit_IP_WithinLimit(t *testing.T) {
	// Setup
	storage := NewInMemoryStorage()
	rateLimiter := limiter.New(storage, limiter.Config{
		IPRateLimit:     5,
		TokenRateLimit:  10,
		IPBlockDuration: 1 * time.Minute,
	})

	router := setupTestRouter(rateLimiter)

	// Make requests within limit
	for i := 0; i < 5; i++ {
		req := httptest.NewRequest("GET", "/test", nil)
		req.RemoteAddr = "192.168.1.1:1234"
		w := httptest.NewRecorder()

		router.ServeHTTP(w, req)

		assert.Equal(t, http.StatusOK, w.Code)
	}
}

func TestRateLimit_IP_ExceedsLimit(t *testing.T) {
	// Setup
	storage := NewInMemoryStorage()
	rateLimiter := limiter.New(storage, limiter.Config{
		IPRateLimit:     2,
		TokenRateLimit:  10,
		IPBlockDuration: 1 * time.Minute,
	})

	router := setupTestRouter(rateLimiter)

	// Make requests up to limit
	for i := 0; i < 2; i++ {
		req := httptest.NewRequest("GET", "/test", nil)
		req.RemoteAddr = "192.168.1.1:1234"
		w := httptest.NewRecorder()

		router.ServeHTTP(w, req)

		assert.Equal(t, http.StatusOK, w.Code)
	}

	// Exceed limit
	req := httptest.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "192.168.1.1:1234"
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusTooManyRequests, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "you have reached the maximum number of requests or actions allowed within a certain time frame", response["message"])
}

func TestRateLimit_Token_WithinLimit(t *testing.T) {
	// Setup
	storage := NewInMemoryStorage()
	rateLimiter := limiter.New(storage, limiter.Config{
		IPRateLimit:        2,
		TokenRateLimit:     10,
		TokenBlockDuration: 1 * time.Minute,
	})

	router := setupTestRouter(rateLimiter)

	// Make requests with token within limit
	for i := 0; i < 10; i++ {
		req := httptest.NewRequest("GET", "/test", nil)
		req.Header.Set("API_KEY", "test-token")
		req.RemoteAddr = "192.168.1.1:1234"
		w := httptest.NewRecorder()

		router.ServeHTTP(w, req)

		assert.Equal(t, http.StatusOK, w.Code)
	}
}

func TestRateLimit_Token_ExceedsLimit(t *testing.T) {
	// Setup
	storage := NewInMemoryStorage()
	rateLimiter := limiter.New(storage, limiter.Config{
		IPRateLimit:        5,
		TokenRateLimit:     3,
		TokenBlockDuration: 1 * time.Minute,
	})

	router := setupTestRouter(rateLimiter)

	// Make requests up to token limit
	for i := 0; i < 3; i++ {
		req := httptest.NewRequest("GET", "/test", nil)
		req.Header.Set("API_KEY", "test-token")
		req.RemoteAddr = "192.168.1.1:1234"
		w := httptest.NewRecorder()

		router.ServeHTTP(w, req)

		assert.Equal(t, http.StatusOK, w.Code)
	}

	// Exceed token limit
	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("API_KEY", "test-token")
	req.RemoteAddr = "192.168.1.1:1234"
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestRateLimit_Token_OverridesIP(t *testing.T) {
	// Setup
	storage := NewInMemoryStorage()
	rateLimiter := limiter.New(storage, limiter.Config{
		IPRateLimit:        2, // Lower IP limit
		TokenRateLimit:     5, // Higher token limit
		TokenBlockDuration: 1 * time.Minute,
	})

	router := setupTestRouter(rateLimiter)

	// Make requests with token that exceed IP limit but within token limit
	for i := 0; i < 5; i++ {
		req := httptest.NewRequest("GET", "/test", nil)
		req.Header.Set("API_KEY", "test-token")
		req.RemoteAddr = "192.168.1.1:1234"
		w := httptest.NewRecorder()

		router.ServeHTTP(w, req)

		assert.Equal(t, http.StatusOK, w.Code, "Request %d should succeed with token", i+1)
	}
}
