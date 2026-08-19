package api

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"knowbody/api/internal/auth"
	"knowbody/api/internal/domain"
	"knowbody/api/internal/game"
	"knowbody/api/internal/httpx"
)

func (s *Server) uid(r *http.Request) uuid.UUID {
	id, _ := auth.UserID(r.Context())
	return id
}

// GET /v1/home
func (s *Server) handleHome(w http.ResponseWriter, r *http.Request) {
	home, err := s.store.GetHome(r.Context(), s.uid(r), time.Now())
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	httpx.JSON(w, http.StatusOK, home)
}

// GET /v1/profile
func (s *Server) handleGetProfile(w http.ResponseWriter, r *http.Request) {
	p, err := s.store.GetProfile(r.Context(), s.uid(r))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	httpx.JSON(w, http.StatusOK, p)
}

// PUT /v1/profile
func (s *Server) handleUpdateProfile(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Goal        string `json:"goal"`
		Locale      string `json:"locale"`
		KcalGoal    int    `json:"dailyKcalGoal"`
		ProteinGoal int    `json:"proteinGoalG"`
		CarbsGoal   int    `json:"carbsGoalG"`
		FatGoal     int    `json:"fatGoalG"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid body")
		return
	}
	if in.Goal == "" {
		in.Goal = "eat_better"
	}
	if in.Locale == "" {
		in.Locale = "th"
	}
	p, err := s.store.UpdateProfile(r.Context(), s.uid(r), in.Goal, in.Locale, in.KcalGoal, in.ProteinGoal, in.CarbsGoal, in.FatGoal)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	httpx.JSON(w, http.StatusOK, p)
}

// POST /v1/meals/analyze  { "imageBase64": "..." }
// Enforces the free-tier monthly AI cap, then returns an editable draft.
func (s *Server) handleAnalyzeMeal(w http.ResponseWriter, r *http.Request) {
	var in struct {
		ImageBase64 string `json:"imageBase64"`
	}
	if err := httpx.Decode(r, &in); err != nil || in.ImageBase64 == "" {
		httpx.Error(w, http.StatusBadRequest, "imageBase64 required")
		return
	}
	uid := s.uid(r)
	ym := yyyymm(time.Now())

	tier, _ := s.store.Tier(r.Context(), uid)
	if tier == "free" {
		used, err := s.store.AIUsageThisMonth(r.Context(), uid, ym)
		if err != nil {
			httpx.Error(w, http.StatusInternalServerError, err.Error())
			return
		}
		if used >= s.cfg.FreeAILogsPerMo {
			httpx.JSON(w, http.StatusPaymentRequired, map[string]any{
				"error":     "free_ai_limit_reached",
				"limit":     s.cfg.FreeAILogsPerMo,
				"used":      used,
				"upgradeTo": "plus",
			})
			return
		}
	}

	draft, err := s.food.Analyze(r.Context(), in.ImageBase64)
	if err != nil {
		httpx.Error(w, http.StatusBadGateway, "analysis failed: "+err.Error())
		return
	}
	if err := s.store.IncAIUsage(r.Context(), uid, ym); err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	httpx.JSON(w, http.StatusOK, draft)
}

// POST /v1/meals  — persist a (possibly user-edited) meal, then award XP + streak.
func (s *Server) handleCreateMeal(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Slot     string            `json:"slot"`
		Title    string            `json:"title"`
		PhotoKey *string           `json:"photoKey"`
		Items    []domain.MealItem `json:"items"`
	}
	if err := httpx.Decode(r, &in); err != nil || len(in.Items) == 0 {
		httpx.Error(w, http.StatusBadRequest, "slot/items required")
		return
	}
	if in.Slot == "" {
		in.Slot = "snack"
	}
	uid := s.uid(r)
	meal, err := s.store.CreateMeal(r.Context(), uid, in.Slot, in.Title, in.PhotoKey, in.Items)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	pet, levels, _ := s.store.AwardXP(r.Context(), uid, game.XPLogMeal)
	streak, _ := s.store.TouchStreak(r.Context(), uid, time.Now())

	httpx.JSON(w, http.StatusCreated, map[string]any{
		"meal":         meal,
		"xpGained":     game.XPLogMeal,
		"pet":          pet,
		"levelsGained": levels,
		"streak":       streak,
	})
}

// PUT /v1/meals/{id}  — replace a meal's items (edit).
func (s *Server) handleUpdateMeal(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, "bad id")
		return
	}
	var in struct {
		Slot  string            `json:"slot"`
		Title string            `json:"title"`
		Items []domain.MealItem `json:"items"`
	}
	if err := httpx.Decode(r, &in); err != nil || len(in.Items) == 0 {
		httpx.Error(w, http.StatusBadRequest, "slot/items required")
		return
	}
	if in.Slot == "" {
		in.Slot = "snack"
	}
	meal, err := s.store.UpdateMeal(r.Context(), s.uid(r), id, in.Slot, in.Title, in.Items)
	if err != nil {
		httpx.Error(w, http.StatusNotFound, "meal not found")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"meal": meal})
}

// POST /v1/workouts  { "title": "Tuesday easy" }
func (s *Server) handleCreateWorkout(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Title string `json:"title"`
	}
	if err := httpx.Decode(r, &in); err != nil || in.Title == "" {
		httpx.Error(w, http.StatusBadRequest, "title required")
		return
	}
	id, err := s.store.CreateWorkout(r.Context(), s.uid(r), in.Title)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]any{"id": id})
}

// POST /v1/workouts/{id}/complete  { "kcalBurned": 168, "durationS": 842, "partial": false }
func (s *Server) handleCompleteWorkout(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, "bad id")
		return
	}
	var in struct {
		KcalBurned int  `json:"kcalBurned"`
		DurationS  int  `json:"durationS"`
		Partial    bool `json:"partial"`
	}
	_ = httpx.Decode(r, &in)
	uid := s.uid(r)
	if err := s.store.CompleteWorkout(r.Context(), uid, id, in.KcalBurned, in.DurationS); err != nil {
		httpx.Error(w, http.StatusNotFound, "workout not found")
		return
	}
	xp := game.XPFinishWorkout
	if in.Partial {
		xp = game.XPPartialWorkout // a part-finished workout still counts
	}
	pet, levels, _ := s.store.AwardXP(r.Context(), uid, xp)
	streak, _ := s.store.TouchStreak(r.Context(), uid, time.Now())
	httpx.JSON(w, http.StatusOK, map[string]any{
		"xpGained": xp, "pet": pet, "levelsGained": levels, "streak": streak,
	})
}

// PUT /v1/pet  { "name": "..." }  — rename the pet.
func (s *Server) handleRenamePet(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Name string `json:"name"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid body")
		return
	}
	name := strings.TrimSpace(in.Name)
	if name == "" {
		httpx.Error(w, http.StatusBadRequest, "name required")
		return
	}
	if len([]rune(name)) > 24 {
		name = string([]rune(name)[:24])
	}
	pet, err := s.store.SetPetName(r.Context(), s.uid(r), name)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	httpx.JSON(w, http.StatusOK, pet)
}

// GET /v1/pet
func (s *Server) handleGetPet(w http.ResponseWriter, r *http.Request) {
	pet, err := s.store.GetPet(r.Context(), s.uid(r))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	httpx.JSON(w, http.StatusOK, pet)
}

// GET /v1/body-scans?limit=12
func (s *Server) handleListBodyScans(w http.ResponseWriter, r *http.Request) {
	scans, err := s.store.ListBodyScans(r.Context(), s.uid(r), 12)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"scans": scans})
}

// POST /v1/body-scans/analyze  { front, side (base64), weightKg }  — Plus only.
func (s *Server) handleAnalyzeBodyScan(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Front    string  `json:"front"`
		Side     string  `json:"side"`
		WeightKg float64 `json:"weightKg"`
	}
	if err := httpx.Decode(r, &in); err != nil || in.Front == "" || in.Side == "" {
		httpx.Error(w, http.StatusBadRequest, "front and side images required")
		return
	}
	tier, _ := s.store.Tier(r.Context(), s.uid(r))
	if tier == "free" {
		httpx.JSON(w, http.StatusPaymentRequired, map[string]any{
			"error": "plus_required", "feature": "body_scan", "upgradeTo": "plus",
		})
		return
	}
	draft, err := s.food.AnalyzeBody(r.Context(), in.Front, in.Side, in.WeightKg)
	if err != nil {
		httpx.Error(w, http.StatusBadGateway, "analysis failed: "+err.Error())
		return
	}
	httpx.JSON(w, http.StatusOK, draft)
}

// POST /v1/body-scans  — persist a scan (client sends the AI ranges + optional notes).
func (s *Server) handleCreateBodyScan(w http.ResponseWriter, r *http.Request) {
	var in struct {
		WeightKg *float64 `json:"weightKg"`
		BfPct    *float64 `json:"bodyFatPct"`
		BfLow    *float64 `json:"bodyFatLow"`
		BfHigh   *float64 `json:"bodyFatHigh"`
		Notes    []string `json:"notes"`
		FrontKey *string  `json:"frontKey"`
		SideKey  *string  `json:"sideKey"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid body")
		return
	}
	notes, _ := json.Marshal(orEmpty(in.Notes))
	uid := s.uid(r)
	scan, err := s.store.CreateBodyScan(r.Context(), uid, domain.BodyScan{
		WeightKg: in.WeightKg, BfPct: in.BfPct, BfLow: in.BfLow, BfHigh: in.BfHigh, Notes: orEmpty(in.Notes),
	}, notes, in.FrontKey, in.SideKey)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	pet, levels, _ := s.store.AwardXP(r.Context(), uid, game.XPBodyScan)
	httpx.JSON(w, http.StatusCreated, map[string]any{
		"scan": scan, "xpGained": game.XPBodyScan, "pet": pet, "levelsGained": levels,
	})
}

func orEmpty(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}
