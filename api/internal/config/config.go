// Package config loads runtime configuration from the environment.
package config

import (
	"os"
	"strconv"
)

type Config struct {
	Port              string
	Env               string // "local" | "prod"
	DatabaseURL       string
	SupabaseJWTSecret string
	AuthDevBypass     bool
	AIProvider        string // gemini | claude
	GeminiAPIKey      string
	GeminiModel       string
	AnthropicAPIKey   string
	AnthropicModel    string
	R2AccountID       string
	R2AccessKeyID     string
	R2SecretKey       string
	R2Bucket          string
	FreeAILogsPerMo   int
}

func Load() Config {
	return Config{
		Port:              env("PORT", "8080"),
		Env:               env("ENV", "local"),
		DatabaseURL:       env("DATABASE_URL", "postgres://knowbody:knowbody@localhost:5432/knowbody?sslmode=disable"),
		SupabaseJWTSecret: env("SUPABASE_JWT_SECRET", ""),
		AuthDevBypass:     env("AUTH_DEV_BYPASS", "0") == "1",
		AIProvider:        env("AI_PROVIDER", "gemini"),
		GeminiAPIKey:      env("GEMINI_API_KEY", ""),
		GeminiModel:       env("GEMINI_MODEL", "gemini-3.6-flash"),
		AnthropicAPIKey:   env("ANTHROPIC_API_KEY", ""),
		AnthropicModel:    env("ANTHROPIC_MODEL", "claude-sonnet-4-6"),
		R2AccountID:       env("R2_ACCOUNT_ID", ""),
		R2AccessKeyID:     env("R2_ACCESS_KEY_ID", ""),
		R2SecretKey:       env("R2_SECRET_ACCESS_KEY", ""),
		R2Bucket:          env("R2_BUCKET", "knowbody-media"),
		FreeAILogsPerMo:   envInt("FREE_AI_LOGS_PER_MONTH", 3),
	}
}

func (c Config) IsLocal() bool { return c.Env == "local" }

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func envInt(k string, def int) int {
	if v := os.Getenv(k); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}
