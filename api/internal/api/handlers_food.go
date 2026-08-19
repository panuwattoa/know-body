package api

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"knowbody/api/internal/calc"
	"knowbody/api/internal/food"
	"knowbody/api/internal/httpx"
	"knowbody/api/internal/plan"
)

// POST /v1/profile/setup — body metrics → computed calorie & macro targets.
func (s *Server) handleSetupProfile(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Goal      string  `json:"goal"`
		Locale    string  `json:"locale"`
		Sex       string  `json:"sex"`      // m | f
		Age       int     `json:"age"`
		HeightCm  float64 `json:"heightCm"`
		WeightKg  float64 `json:"weightKg"`
		Activity   string `json:"activity"` // sedentary|light|moderate|active|very
		GoalDir    string `json:"goalDir"`  // lose|maintain|gain
		TargetDate string `json:"targetDate"` // "YYYY-MM-DD" or ""
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
	if in.Activity == "" {
		in.Activity = "light"
	}
	if in.GoalDir == "" {
		in.GoalDir = "maintain"
	}

	t := calc.Daily(in.Sex, in.Age, in.HeightCm, in.WeightKg, in.Activity, in.GoalDir)
	birthYear := 0
	if in.Age > 0 {
		birthYear = nowYear() - in.Age
	}
	profile, err := s.store.SetupProfile(r.Context(), s.uid(r), in.Goal, in.Locale, in.Sex, birthYear,
		in.HeightCm, in.WeightKg, in.Activity, in.GoalDir, in.TargetDate, t.Kcal, t.ProteinG, t.CarbsG, t.FatG)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"profile": profile, "calc": t})
}

// GET /v1/foods/search?q=...
func (s *Server) handleSearchFoods(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	if len(q) < 1 {
		httpx.JSON(w, http.StatusOK, map[string]any{"foods": []any{}})
		return
	}
	foods, err := s.store.SearchFoods(r.Context(), q, 20)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	out := make([]map[string]any, 0, len(foods))
	for _, f := range foods {
		out = append(out, map[string]any{
			"id": f.ID, "nameTh": f.NameTH, "nameEn": f.NameEN,
			"kcal100": f.Kcal100, "protein100": f.Prot100, "carbs100": f.Carb100, "fat100": f.Fat100,
		})
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"foods": out})
}

// DELETE /v1/meals/{id}
func (s *Server) handleDeleteMeal(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, "bad id")
		return
	}
	if err := s.store.DeleteMeal(r.Context(), s.uid(r), id); err != nil {
		httpx.Error(w, http.StatusNotFound, "meal not found")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"ok": true})
}

// POST /v1/weight { "weightKg": 72.4, "muscleKg": 33.1 }
func (s *Server) handleAddWeight(w http.ResponseWriter, r *http.Request) {
	var in struct {
		WeightKg float64  `json:"weightKg"`
		MuscleKg *float64 `json:"muscleKg"`
	}
	if err := httpx.Decode(r, &in); err != nil || in.WeightKg <= 0 {
		httpx.Error(w, http.StatusBadRequest, "weightKg required")
		return
	}
	uid := s.uid(r)
	if err := s.store.AddWeighIn(r.Context(), uid, in.WeightKg, in.MuscleKg); err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	weights, _ := s.store.ListWeighIns(r.Context(), uid, 60)
	httpx.JSON(w, http.StatusCreated, map[string]any{"weights": weights})
}

// PUT /v1/weight/{id} { "weightKg": .., "muscleKg": .. }
func (s *Server) handleUpdateWeight(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, "bad id")
		return
	}
	var in struct {
		WeightKg float64  `json:"weightKg"`
		MuscleKg *float64 `json:"muscleKg"`
	}
	if err := httpx.Decode(r, &in); err != nil || in.WeightKg <= 0 {
		httpx.Error(w, http.StatusBadRequest, "weightKg required")
		return
	}
	uid := s.uid(r)
	if err := s.store.UpdateWeighIn(r.Context(), uid, id, in.WeightKg, in.MuscleKg); err != nil {
		httpx.Error(w, http.StatusNotFound, "weigh-in not found")
		return
	}
	weights, _ := s.store.ListWeighIns(r.Context(), uid, 60)
	httpx.JSON(w, http.StatusOK, map[string]any{"weights": weights})
}

// DELETE /v1/weight/{id}
func (s *Server) handleDeleteWeight(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, "bad id")
		return
	}
	uid := s.uid(r)
	if err := s.store.DeleteWeighIn(r.Context(), uid, id); err != nil {
		httpx.Error(w, http.StatusNotFound, "weigh-in not found")
		return
	}
	weights, _ := s.store.ListWeighIns(r.Context(), uid, 60)
	httpx.JSON(w, http.StatusOK, map[string]any{"weights": weights})
}

// GET /v1/weight
func (s *Server) handleListWeights(w http.ResponseWriter, r *http.Request) {
	weights, err := s.store.ListWeighIns(r.Context(), s.uid(r), 60)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"weights": weights})
}

// GET /v1/activity?ym=YYYYMM — days in a month that had activity (for the calendar).
func (s *Server) handleActivity(w http.ResponseWriter, r *http.Request) {
	now := nowYear()
	year, month := now, int(monthNow())
	if ym := r.URL.Query().Get("ym"); len(ym) == 6 {
		if v, err := atoi(ym); err == nil {
			year, month = v/100, v%100
		}
	}
	days, err := s.store.ActiveDays(r.Context(), s.uid(r), year, month)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	if days == nil {
		days = []string{}
	}
	streak, _ := s.store.GetStreak(r.Context(), s.uid(r))
	httpx.JSON(w, http.StatusOK, map[string]any{"year": year, "month": month, "activeDays": days, "streak": streak})
}

// GET /v1/workouts/plan — quick rule-based suggestions (kept for compatibility).
func (s *Server) handleWorkoutPlan(w http.ResponseWriter, r *http.Request) {
	p, err := s.store.GetProfile(r.Context(), s.uid(r))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	goalDir := r.URL.Query().Get("goalDir")
	workouts := plan.Suggest(p.Goal, goalDir)
	httpx.JSON(w, http.StatusOK, map[string]any{"workouts": workouts})
}

// GET /v1/workouts/program        — AI-personalized program (cached).
// POST /v1/workouts/program       — force regeneration.
// Falls back to the rule-based plan if AI is unavailable.
func (s *Server) handleWorkoutProgram(w http.ResponseWriter, r *http.Request) {
	uid := s.uid(r)
	force := r.Method == http.MethodPost

	m, err := s.store.GetMetrics(r.Context(), uid)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	targetStr, weeks := "", 0
	if m.TargetDate != nil {
		targetStr = m.TargetDate.Format("2006-01-02")
		weeks = int(m.TargetDate.Sub(nowTrunc()).Hours()/24/7 + 0.5)
		if weeks < 0 {
			weeks = 0
		}
	}

	// Serve cached program unless forcing regeneration.
	if !force {
		if cached, _, err := s.store.GetProgram(r.Context(), uid); err == nil && len(cached) > 4 {
			var workouts json.RawMessage = cached
			httpx.JSON(w, http.StatusOK, map[string]any{
				"source": "ai", "targetDate": targetStr, "weeksToTarget": weeks, "workouts": workouts,
			})
			return
		}
	}

	// Generate with AI.
	raw, err := s.food.GenerateProgram(r.Context(), food.ProgramInput{
		Sex: m.Sex, Age: m.Age, HeightCm: m.HeightCm, WeightKg: m.WeightKg,
		Activity: m.Activity, Goal: m.Goal, GoalDir: m.GoalDir, TargetDate: targetStr, Weeks: weeks, Locale: "th",
	})
	if err != nil {
		// Fallback: rule-based plan.
		workouts := plan.Suggest(m.Goal, m.GoalDir)
		httpx.JSON(w, http.StatusOK, map[string]any{
			"source": "builtin", "targetDate": targetStr, "weeksToTarget": weeks, "workouts": workouts,
		})
		return
	}

	// Cache the workouts array for stability.
	var parsed struct {
		Summary  string          `json:"summary"`
		Workouts json.RawMessage `json:"workouts"`
	}
	_ = json.Unmarshal(raw, &parsed)
	if len(parsed.Workouts) > 0 {
		_ = s.store.SaveProgram(r.Context(), uid, parsed.Workouts)
	}
	httpx.JSON(w, http.StatusOK, map[string]any{
		"source": "ai", "summary": parsed.Summary, "targetDate": targetStr, "weeksToTarget": weeks,
		"workouts": parsed.Workouts,
	})
}
