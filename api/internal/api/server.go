// Package api wires the HTTP router, middleware and handlers.
package api

import (
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/google/uuid"

	"knowbody/api/internal/auth"
	"knowbody/api/internal/config"
	"knowbody/api/internal/food"
	"knowbody/api/internal/store"
)

type Server struct {
	cfg   config.Config
	store *store.Store
	food  *food.Service
	auth  *auth.Authenticator

	ensuredMu sync.Mutex
	ensured   map[uuid.UUID]struct{} // process-local cache to avoid repeat upserts
}

func NewServer(cfg config.Config, st *store.Store, fs *food.Service) *Server {
	return &Server{
		cfg:     cfg,
		store:   st,
		food:    fs,
		auth:    auth.New(cfg.SupabaseJWTSecret, cfg.AuthDevBypass),
		ensured: make(map[uuid.UUID]struct{}),
	}
}

func (s *Server) Router() http.Handler {
	r := chi.NewRouter()
	r.Use(chimw.RequestID)
	r.Use(chimw.RealIP)
	r.Use(chimw.Recoverer)
	r.Use(chimw.Timeout(70 * time.Second))
	if s.cfg.IsLocal() {
		r.Use(devCORS) // allow `flutter run -d chrome` against localhost during dev
	}

	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })

	r.Route("/v1", func(r chi.Router) {
		r.Use(s.auth.Middleware)
		r.Use(s.ensureUser)

		r.Get("/home", s.handleHome)
		r.Get("/profile", s.handleGetProfile)
		r.Put("/profile", s.handleUpdateProfile)
		r.Post("/profile/setup", s.handleSetupProfile)

		r.Post("/meals/analyze", s.handleAnalyzeMeal)
		r.Post("/meals", s.handleCreateMeal)
		r.Put("/meals/{id}", s.handleUpdateMeal)
		r.Delete("/meals/{id}", s.handleDeleteMeal)
		r.Get("/foods/search", s.handleSearchFoods)

		r.Post("/workouts", s.handleCreateWorkout)
		r.Post("/workouts/{id}/complete", s.handleCompleteWorkout)
		r.Get("/workouts/plan", s.handleWorkoutPlan)
		r.Get("/workouts/program", s.handleWorkoutProgram)
		r.Post("/workouts/program", s.handleWorkoutProgram)

		r.Post("/weight", s.handleAddWeight)
		r.Get("/weight", s.handleListWeights)
		r.Put("/weight/{id}", s.handleUpdateWeight)
		r.Delete("/weight/{id}", s.handleDeleteWeight)
		r.Get("/activity", s.handleActivity)

		r.Get("/pet", s.handleGetPet)
		r.Put("/pet", s.handleRenamePet)

		r.Post("/body-scans/analyze", s.handleAnalyzeBodyScan)
		r.Post("/body-scans", s.handleCreateBodyScan)
		r.Get("/body-scans", s.handleListBodyScans)
	})

	return r
}

// ensureUser lazily provisions the Supabase user's rows on first sight this process.
func (s *Server) ensureUser(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := auth.UserID(r.Context())
		if !ok {
			http.Error(w, `{"error":"no user"}`, http.StatusUnauthorized)
			return
		}
		s.ensuredMu.Lock()
		_, seen := s.ensured[uid]
		s.ensuredMu.Unlock()
		if !seen {
			if err := s.store.EnsureUser(r.Context(), uid, ""); err != nil {
				http.Error(w, `{"error":"provision failed"}`, http.StatusInternalServerError)
				return
			}
			s.ensuredMu.Lock()
			s.ensured[uid] = struct{}{}
			s.ensuredMu.Unlock()
		}
		next.ServeHTTP(w, r)
	})
}

// devCORS permits any origin — LOCAL DEV ONLY (gated by ENV=local).
func devCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization,Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func yyyymm(t time.Time) int { return t.Year()*100 + int(t.Month()) }

func nowYear() int               { return time.Now().Year() }
func monthNow() int              { return int(time.Now().Month()) }
func nowTrunc() time.Time         { return time.Now().Truncate(24 * time.Hour) }
func atoi(s string) (int, error) { return strconv.Atoi(s) }
