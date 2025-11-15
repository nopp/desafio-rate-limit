package middleware

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"rate-limiter/internal/limiter"

	"github.com/gin-gonic/gin"
)

// RateLimitMiddleware creates a middleware that applies rate limiting
func RateLimitMiddleware(rateLimiter *limiter.RateLimiter) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()

		// Get client IP
		clientIP := getClientIP(c)

		// Check for API_KEY header (token)
		apiKey := c.GetHeader("API_KEY")

		var result *limiter.CheckResult
		var err error

		// Token-based rate limiting takes priority over IP-based
		if apiKey != "" {
			result, err = rateLimiter.CheckToken(ctx, apiKey)
		} else {
			result, err = rateLimiter.CheckIP(ctx, clientIP)
		}

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Internal server error",
			})
			c.Abort()
			return
		}

		// Set rate limit headers
		c.Header("X-RateLimit-Limit", fmt.Sprintf("%d", result.Limit))
		c.Header("X-RateLimit-Remaining", fmt.Sprintf("%d", result.Limit-result.Current))
		c.Header("X-RateLimit-Reset", fmt.Sprintf("%d", result.ResetTime.Unix()))

		if !result.Allowed {
			// If blocked, add additional headers
			if !result.BlockedUntil.IsZero() {
				c.Header("X-RateLimit-Retry-After", fmt.Sprintf("%d", int(result.BlockedUntil.Sub(time.Now()).Seconds())))
			}

			c.JSON(http.StatusTooManyRequests, gin.H{
				"message": "you have reached the maximum number of requests or actions allowed within a certain time frame",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// getClientIP extracts the real client IP address
func getClientIP(c *gin.Context) string {
	// Check X-Forwarded-For header first
	forwarded := c.GetHeader("X-Forwarded-For")
	if forwarded != "" {
		// X-Forwarded-For can contain multiple IPs, take the first one
		ips := strings.Split(forwarded, ",")
		if len(ips) > 0 {
			return strings.TrimSpace(ips[0])
		}
	}

	// Check X-Real-IP header
	realIP := c.GetHeader("X-Real-IP")
	if realIP != "" {
		return realIP
	}

	// Fallback to client IP from connection
	return c.ClientIP()
}
