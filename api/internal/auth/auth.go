// Package auth verifies Supabase-issued JWTs (HS256, shared project secret) and
// attaches the authenticated user id to the request context.
package auth

import (
	"context"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type ctxKey int

const userIDKey ctxKey = 0

type Authenticator struct {
	secret    []byte
	devBypass bool
}

func New(jwtSecret string, devBypass bool) *Authenticator {
	return &Authenticator{secret: []byte(jwtSecret), devBypass: devBypass}
}

// Middleware rejects requests without a valid bearer token.
// In dev-bypass mode it also accepts "Bearer dev:<uuid>" for local testing.
func (a *Authenticator) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw := bearer(r)
		if raw == "" {
			http.Error(w, `{"error":"missing bearer token"}`, http.StatusUnauthorized)
			return
		}

		if a.devBypass && strings.HasPrefix(raw, "dev:") {
			id, err := uuid.Parse(strings.TrimPrefix(raw, "dev:"))
			if err != nil {
				http.Error(w, `{"error":"bad dev token"}`, http.StatusUnauthorized)
				return
			}
			next.ServeHTTP(w, r.WithContext(withUser(r.Context(), id)))
			return
		}

		id, err := a.parse(raw)
		if err != nil {
			http.Error(w, `{"error":"invalid token"}`, http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r.WithContext(withUser(r.Context(), id)))
	})
}

func (a *Authenticator) parse(raw string) (uuid.UUID, error) {
	tok, err := jwt.Parse(raw, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrTokenSignatureInvalid
		}
		return a.secret, nil
	}, jwt.WithValidMethods([]string{"HS256"}))
	if err != nil || !tok.Valid {
		return uuid.Nil, err
	}
	claims, ok := tok.Claims.(jwt.MapClaims)
	if !ok {
		return uuid.Nil, jwt.ErrTokenInvalidClaims
	}
	sub, _ := claims["sub"].(string)
	return uuid.Parse(sub)
}

func bearer(r *http.Request) string {
	h := r.Header.Get("Authorization")
	if len(h) > 7 && strings.EqualFold(h[:7], "Bearer ") {
		return strings.TrimSpace(h[7:])
	}
	return ""
}

func withUser(ctx context.Context, id uuid.UUID) context.Context {
	return context.WithValue(ctx, userIDKey, id)
}

// UserID returns the authenticated user id from a request context.
func UserID(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(userIDKey).(uuid.UUID)
	return id, ok
}
