package main

import (
	"fmt"
	"log"
	"net/http"
	"time"

	"rate-limiter/internal/config"
	"rate-limiter/internal/limiter"
	"rate-limiter/internal/middleware"
	"rate-limiter/internal/storage"

	"github.com/gin-gonic/gin"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize Redis storage
	redisStorage, err := storage.NewRedisStorage(cfg.RedisAddr, cfg.RedisPassword, cfg.RedisDB)
	if err != nil {
		log.Fatalf("Failed to initialize Redis storage: %v", err)
	}
	defer redisStorage.Close()

	// Initialize rate limiter
	rateLimiter := limiter.New(redisStorage, limiter.Config{
		IPRateLimit:        cfg.IPRateLimit,
		TokenRateLimit:     cfg.TokenRateLimit,
		IPBlockDuration:    cfg.IPBlockDuration,
		TokenBlockDuration: cfg.TokenBlockDuration,
	})

	// Initialize Gin router
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()

	// Add middleware
	router.Use(gin.Logger())
	router.Use(gin.Recovery())
	router.Use(middleware.RateLimitMiddleware(rateLimiter))

	// Define routes
	setupRoutes(router)

	// Start server
	addr := fmt.Sprintf(":%s", cfg.ServerPort)
	log.Printf("Starting server on port %s", cfg.ServerPort)
	log.Printf("Rate limits - IP: %d req/s, Token: %d req/s", cfg.IPRateLimit, cfg.TokenRateLimit)
	log.Printf("Block durations - IP: %v, Token: %v", cfg.IPBlockDuration, cfg.TokenBlockDuration)

	if err := http.ListenAndServe(addr, router); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func setupRoutes(router *gin.Engine) {
	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":    "ok",
			"timestamp": time.Now().Unix(),
		})
	})

	// Test endpoint
	router.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message":   "Request successful",
			"ip":        c.ClientIP(),
			"timestamp": time.Now().Unix(),
		})
	})

	// API v1 routes
	v1 := router.Group("/api/v1")
	{
		v1.GET("/users", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{
				"users": []string{"user1", "user2", "user3"},
			})
		})

		v1.POST("/users", func(c *gin.Context) {
			c.JSON(http.StatusCreated, gin.H{
				"message": "User created successfully",
			})
		})

		v1.GET("/data", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{
				"data": map[string]interface{}{
					"key1":      "value1",
					"key2":      "value2",
					"timestamp": time.Now().Unix(),
				},
			})
		})
	}
}
