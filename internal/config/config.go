package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

// Config holds all configuration for the rate limiter
type Config struct {
	// IP Rate Limiting
	IPRateLimit     int
	IPBlockDuration time.Duration

	// Token Rate Limiting
	TokenRateLimit     int
	TokenBlockDuration time.Duration

	// Redis Configuration
	RedisAddr     string
	RedisPassword string
	RedisDB       int

	// Server Configuration
	ServerPort string
}

// Load loads configuration from environment variables and .env file
func Load() (*Config, error) {
	// Load .env file if it exists
	_ = godotenv.Load()

	config := &Config{}

	// IP Rate Limiting
	ipRateLimit, err := strconv.Atoi(getEnv("IP_RATE_LIMIT", "10"))
	if err != nil {
		return nil, fmt.Errorf("invalid IP_RATE_LIMIT: %w", err)
	}
	config.IPRateLimit = ipRateLimit

	ipBlockDuration, err := strconv.Atoi(getEnv("IP_BLOCK_DURATION", "300"))
	if err != nil {
		return nil, fmt.Errorf("invalid IP_BLOCK_DURATION: %w", err)
	}
	config.IPBlockDuration = time.Duration(ipBlockDuration) * time.Second

	// Token Rate Limiting
	tokenRateLimit, err := strconv.Atoi(getEnv("TOKEN_RATE_LIMIT", "100"))
	if err != nil {
		return nil, fmt.Errorf("invalid TOKEN_RATE_LIMIT: %w", err)
	}
	config.TokenRateLimit = tokenRateLimit

	tokenBlockDuration, err := strconv.Atoi(getEnv("TOKEN_BLOCK_DURATION", "600"))
	if err != nil {
		return nil, fmt.Errorf("invalid TOKEN_BLOCK_DURATION: %w", err)
	}
	config.TokenBlockDuration = time.Duration(tokenBlockDuration) * time.Second

	// Redis Configuration
	config.RedisAddr = getEnv("REDIS_ADDR", "localhost:6379")
	config.RedisPassword = getEnv("REDIS_PASSWORD", "")

	redisDB, err := strconv.Atoi(getEnv("REDIS_DB", "0"))
	if err != nil {
		return nil, fmt.Errorf("invalid REDIS_DB: %w", err)
	}
	config.RedisDB = redisDB

	// Server Configuration
	config.ServerPort = getEnv("SERVER_PORT", "8080")

	return config, nil
}

// getEnv gets an environment variable with a fallback default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
