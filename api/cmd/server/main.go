// KnowBody API server entrypoint.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"knowbody/api/internal/ai"
	"knowbody/api/internal/api"
	"knowbody/api/internal/config"
	"knowbody/api/internal/food"
	"knowbody/api/internal/store"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})))
	cfg := config.Load()

	ctx := context.Background()
	st, err := store.New(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("db connect", "err", err)
		os.Exit(1)
	}
	defer st.Close()

	// Pick the vision provider. Default is Google Gemini (free tier); switch to
	// Claude by setting AI_PROVIDER=claude. An empty key ⇒ Enabled()=false ⇒ stub.
	var vision food.Vision
	switch cfg.AIProvider {
	case "claude", "anthropic":
		vision = ai.New(cfg.AnthropicAPIKey, cfg.AnthropicModel)
	default:
		vision = ai.NewGemini(cfg.GeminiAPIKey, cfg.GeminiModel)
	}
	foodSvc := food.NewService(vision, st)
	srv := api.NewServer(cfg, st, foodSvc)

	httpSrv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           srv.Router(),
		ReadHeaderTimeout: 10 * time.Second,
		WriteTimeout:      75 * time.Second,
	}

	go func() {
		slog.Info("KnowBody API listening", "port", cfg.Port, "env", cfg.Env, "aiProvider", cfg.AIProvider, "ai", vision.Enabled())
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("serve", "err", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	slog.Info("shutting down")
	shutCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = httpSrv.Shutdown(shutCtx)
}
