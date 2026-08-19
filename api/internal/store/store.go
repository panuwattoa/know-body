// Package store is the Postgres data layer (pgx). One method per use case; queries
// are inline and always scoped by user_id.
package store

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"knowbody/api/internal/domain"
	"knowbody/api/internal/food"
	"knowbody/api/internal/game"
	"knowbody/api/internal/plan"
)

type Store struct{ pool *pgxpool.Pool }

func New(ctx context.Context, url string) (*Store, error) {
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return nil, err
	}
	if err := pool.Ping(ctx); err != nil {
		return nil, err
	}
	return &Store{pool: pool}, nil
}

func (s *Store) Close() { s.pool.Close() }

// EnsureUser upserts the user row and creates default profile/pet/streak/subscription.
// Called on first authenticated request for a Supabase user.
func (s *Store) EnsureUser(ctx context.Context, id uuid.UUID, email string) error {
	batch := &pgx.Batch{}
	batch.Queue(`INSERT INTO users (id, email) VALUES ($1,$2)
	             ON CONFLICT (id) DO UPDATE SET email = COALESCE(EXCLUDED.email, users.email)`, id, nz(email))
	batch.Queue(`INSERT INTO profiles (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, id)
	batch.Queue(`INSERT INTO pets (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, id)
	batch.Queue(`INSERT INTO streaks (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, id)
	batch.Queue(`INSERT INTO subscriptions (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, id)
	br := s.pool.SendBatch(ctx, batch)
	defer br.Close()
	for i := 0; i < batch.Len(); i++ {
		if _, err := br.Exec(); err != nil {
			return err
		}
	}
	return nil
}

// ── Profile ──────────────────────────────────────────────────

func (s *Store) GetProfile(ctx context.Context, uid uuid.UUID) (domain.Profile, error) {
	var p domain.Profile
	err := s.pool.QueryRow(ctx, `
		SELECT user_id, goal, locale, daily_kcal_goal, protein_g_goal, carbs_g_goal, fat_g_goal
		FROM profiles WHERE user_id = $1`, uid).
		Scan(&p.UserID, &p.Goal, &p.Locale, &p.DailyKcalGoal, &p.ProteinGoal, &p.CarbsGoal, &p.FatGoal)
	return p, err
}

func (s *Store) UpdateProfile(ctx context.Context, uid uuid.UUID, goal, locale string, kcal, prot, carb, fat int) (domain.Profile, error) {
	_, err := s.pool.Exec(ctx, `
		UPDATE profiles SET goal=$2, locale=$3, daily_kcal_goal=$4,
		  protein_g_goal=$5, carbs_g_goal=$6, fat_g_goal=$7, updated_at=now()
		WHERE user_id=$1`, uid, goal, locale, kcal, prot, carb, fat)
	if err != nil {
		return domain.Profile{}, err
	}
	return s.GetProfile(ctx, uid)
}

// SetupProfile saves body metrics + goal and the computed calorie/macro targets.
// targetDate is "YYYY-MM-DD" or "". Setting metrics clears any cached program.
func (s *Store) SetupProfile(ctx context.Context, uid uuid.UUID, goal, locale, sex string, birthYear int, heightCm, weightKg float64, activity, goalDir, targetDate string, kcal, prot, carb, fat int) (domain.Profile, error) {
	_, err := s.pool.Exec(ctx, `
		UPDATE profiles SET
		  goal=$2, locale=$3, sex=$4, birth_year=$5, height_cm=$6, weight_kg=$7,
		  activity_level=$8, goal_dir=$9, target_date=NULLIF($10,'')::date, program=NULL,
		  daily_kcal_goal=$11, protein_g_goal=$12, carbs_g_goal=$13, fat_g_goal=$14, updated_at=now()
		WHERE user_id=$1`,
		uid, goal, locale, nz(sex), birthYear, heightCm, weightKg, activity, goalDir, targetDate, kcal, prot, carb, fat)
	if err != nil {
		return domain.Profile{}, err
	}
	// record initial weight as the first weigh-in for the trend
	if weightKg > 0 {
		_, _ = s.pool.Exec(ctx, `INSERT INTO weigh_ins (user_id, weight_kg) VALUES ($1,$2)`, uid, weightKg)
	}
	return s.GetProfile(ctx, uid)
}

// SearchFoods returns Thai foods matching a free-text query (trigram + prefix).
func (s *Store) SearchFoods(ctx context.Context, q string, limit int) ([]food.ThaiFood, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, name_th, name_en, kcal_100g, protein_100g, carbs_100g, fat_100g
		FROM thai_foods
		WHERE name_th ILIKE '%'||$1||'%' OR name_en ILIKE '%'||$1||'%'
		   OR EXISTS (SELECT 1 FROM unnest(aliases) a WHERE a ILIKE '%'||$1||'%')
		   OR similarity(name_th, $1) > 0.2 OR similarity(name_en, $1) > 0.2
		ORDER BY GREATEST(similarity(name_th,$1), similarity(name_en,$1)) DESC
		LIMIT $2`, q, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []food.ThaiFood
	for rows.Next() {
		var f food.ThaiFood
		if err := rows.Scan(&f.ID, &f.NameTH, &f.NameEN, &f.Kcal100, &f.Prot100, &f.Carb100, &f.Fat100); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// DeleteMeal removes a meal owned by the user.
func (s *Store) DeleteMeal(ctx context.Context, uid, mealID uuid.UUID) error {
	ct, err := s.pool.Exec(ctx, `DELETE FROM meals WHERE id=$2 AND user_id=$1`, uid, mealID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// AddWeighIn records a weight (and optional muscle mass).
func (s *Store) AddWeighIn(ctx context.Context, uid uuid.UUID, kg float64, muscle *float64) error {
	_, err := s.pool.Exec(ctx, `INSERT INTO weigh_ins (user_id, weight_kg, muscle_kg) VALUES ($1,$2,$3)`, uid, kg, muscle)
	return err
}

// UpdateWeighIn edits a weigh-in (owner-scoped).
func (s *Store) UpdateWeighIn(ctx context.Context, uid, id uuid.UUID, kg float64, muscle *float64) error {
	ct, err := s.pool.Exec(ctx, `UPDATE weigh_ins SET weight_kg=$3, muscle_kg=$4 WHERE id=$2 AND user_id=$1`, uid, id, kg, muscle)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// DeleteWeighIn removes a weigh-in (owner-scoped).
func (s *Store) DeleteWeighIn(ctx context.Context, uid, id uuid.UUID) error {
	ct, err := s.pool.Exec(ctx, `DELETE FROM weigh_ins WHERE id=$2 AND user_id=$1`, uid, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// WeighIn is a single logged weight (+ optional muscle mass).
type WeighIn struct {
	ID       uuid.UUID `json:"id"`
	WeightKg float64   `json:"weightKg"`
	MuscleKg *float64  `json:"muscleKg,omitempty"`
	At       time.Time `json:"at"`
}

func (s *Store) ListWeighIns(ctx context.Context, uid uuid.UUID, limit int) ([]WeighIn, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, weight_kg, muscle_kg, at FROM weigh_ins WHERE user_id=$1 ORDER BY at DESC LIMIT $2`, uid, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []WeighIn
	for rows.Next() {
		var w WeighIn
		if err := rows.Scan(&w.ID, &w.WeightKg, &w.MuscleKg, &w.At); err != nil {
			return nil, err
		}
		out = append(out, w)
	}
	// reverse to chronological order for charting
	for i, j := 0, len(out)-1; i < j; i, j = i+1, j-1 {
		out[i], out[j] = out[j], out[i]
	}
	return out, rows.Err()
}

// ── Home aggregate ───────────────────────────────────────────

func (s *Store) GetHome(ctx context.Context, uid uuid.UUID, day time.Time) (domain.Home, error) {
	var h domain.Home
	p, err := s.GetProfile(ctx, uid)
	if err != nil {
		return h, err
	}
	h.Profile = p
	h.KcalGoal = p.DailyKcalGoal

	meals, err := s.MealsForDay(ctx, uid, day)
	if err != nil {
		return h, err
	}
	h.Meals = meals
	for _, m := range meals {
		h.KcalEaten += m.Kcal
		h.ProteinG += m.ProteinG
		h.CarbsG += m.CarbsG
		h.FatG += m.FatG
	}

	// calories burned today from finished workouts
	_ = s.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(kcal_burned),0) FROM workouts
		WHERE user_id=$1 AND status='done' AND finished_at::date = $2::date`,
		uid, day).Scan(&h.KcalBurned)

	h.KcalLeft = h.KcalGoal - h.KcalEaten + h.KcalBurned

	if h.Pet, err = s.GetPet(ctx, uid); err != nil {
		return h, err
	}
	if h.Streak, err = s.GetStreak(ctx, uid); err != nil {
		return h, err
	}
	h.Tier, _ = s.Tier(ctx, uid)

	// Yesterday recap.
	yest := day.AddDate(0, 0, -1)
	y := domain.DaySummary{KcalGoal: p.DailyKcalGoal}
	_ = s.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(kcal),0), COUNT(*) FROM meals
		WHERE user_id=$1 AND eaten_at::date = $2::date`, uid, yest).Scan(&y.KcalEaten, &y.Meals)
	_ = s.pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM workouts WHERE user_id=$1 AND status='done' AND finished_at::date=$2::date)`,
		uid, yest).Scan(&y.WorkedOut)
	if y.KcalGoal > 0 {
		diff := float64(y.KcalEaten-y.KcalGoal) / float64(y.KcalGoal)
		y.OnTarget = y.KcalEaten > 0 && diff >= -0.10 && diff <= 0.10
	}
	h.Yesterday = y

	// Today's suggestion: first workout of the personalized plan.
	if ws := plan.Suggest(p.Goal, ""); len(ws) > 0 {
		h.Suggestion = ws[0].Title
	}
	return h, nil
}

// Metrics holds the profile data an AI trainer needs to build a program.
type Metrics struct {
	Sex        string
	Age        int
	HeightCm   float64
	WeightKg   float64
	Activity   string
	Goal       string
	GoalDir    string
	TargetDate *time.Time
}

// GetMetrics loads the user's body metrics + goal + target date.
func (s *Store) GetMetrics(ctx context.Context, uid uuid.UUID) (Metrics, error) {
	var m Metrics
	var sex *string
	var birthYear *int
	var h, wt *float64
	var td *time.Time
	err := s.pool.QueryRow(ctx, `
		SELECT sex, birth_year, height_cm, weight_kg, activity_level, goal, goal_dir, target_date
		FROM profiles WHERE user_id=$1`, uid).
		Scan(&sex, &birthYear, &h, &wt, &m.Activity, &m.Goal, &m.GoalDir, &td)
	if err != nil {
		return m, err
	}
	if sex != nil {
		m.Sex = *sex
	}
	if birthYear != nil && *birthYear > 0 {
		m.Age = time.Now().Year() - *birthYear
	}
	if h != nil {
		m.HeightCm = *h
	}
	if wt != nil {
		m.WeightKg = *wt
	}
	m.TargetDate = td
	return m, nil
}

// GetProgram returns the cached AI program JSON (or nil) and the target date.
func (s *Store) GetProgram(ctx context.Context, uid uuid.UUID) ([]byte, *time.Time, error) {
	var prog []byte
	var td *time.Time
	err := s.pool.QueryRow(ctx, `SELECT program, target_date FROM profiles WHERE user_id=$1`, uid).Scan(&prog, &td)
	return prog, td, err
}

func (s *Store) SaveProgram(ctx context.Context, uid uuid.UUID, prog []byte) error {
	_, err := s.pool.Exec(ctx, `UPDATE profiles SET program=$2 WHERE user_id=$1`, uid, prog)
	return err
}

// ActiveDays returns the days in a month that had any activity (meal or workout).
func (s *Store) ActiveDays(ctx context.Context, uid uuid.UUID, year, month int) ([]string, error) {
	start := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.UTC)
	end := start.AddDate(0, 1, 0)
	rows, err := s.pool.Query(ctx, `
		SELECT DISTINCT d::date FROM (
		  SELECT eaten_at AS d FROM meals WHERE user_id=$1 AND eaten_at >= $2 AND eaten_at < $3
		  UNION ALL
		  SELECT finished_at AS d FROM workouts WHERE user_id=$1 AND status='done' AND finished_at >= $2 AND finished_at < $3
		) x
		ORDER BY 1`, uid, start, end)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var d time.Time
		if err := rows.Scan(&d); err != nil {
			return nil, err
		}
		out = append(out, d.Format("2006-01-02"))
	}
	return out, rows.Err()
}

// ── Meals ────────────────────────────────────────────────────

func (s *Store) MealsForDay(ctx context.Context, uid uuid.UUID, day time.Time) ([]domain.Meal, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, slot, title, photo_key, kcal, protein_g, carbs_g, fat_g, eaten_at
		FROM meals WHERE user_id=$1 AND eaten_at::date = $2::date
		ORDER BY eaten_at`, uid, day)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.Meal
	byID := map[uuid.UUID]int{}
	for rows.Next() {
		var m domain.Meal
		if err := rows.Scan(&m.ID, &m.Slot, &m.Title, &m.PhotoKey, &m.Kcal, &m.ProteinG, &m.CarbsG, &m.FatG, &m.EatenAt); err != nil {
			return nil, err
		}
		byID[m.ID] = len(out)
		out = append(out, m)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(out) == 0 {
		return out, nil
	}

	// Load items for all meals in one query and attach.
	ids := make([]uuid.UUID, 0, len(out))
	for _, m := range out {
		ids = append(ids, m.ID)
	}
	irows, err := s.pool.Query(ctx, `
		SELECT meal_id, id, thai_food_id, name, grams, kcal, protein_g, carbs_g, fat_g, source, confidence, position
		FROM meal_items WHERE meal_id = ANY($1) ORDER BY position`, ids)
	if err != nil {
		return nil, err
	}
	defer irows.Close()
	for irows.Next() {
		var mealID uuid.UUID
		var it domain.MealItem
		if err := irows.Scan(&mealID, &it.ID, &it.ThaiFoodID, &it.Name, &it.Grams, &it.Kcal, &it.ProteinG, &it.CarbsG, &it.FatG, &it.Source, &it.Confidence, &it.Position); err != nil {
			return nil, err
		}
		if idx, ok := byID[mealID]; ok {
			out[idx].Items = append(out[idx].Items, it)
		}
	}
	return out, irows.Err()
}

// CreateMeal persists a meal and its items in one transaction, recomputing totals.
func (s *Store) CreateMeal(ctx context.Context, uid uuid.UUID, slot, title string, photoKey *string, items []domain.MealItem) (domain.Meal, error) {
	var m domain.Meal
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return m, err
	}
	defer tx.Rollback(ctx)

	var kcal int
	var prot, carb, fat float64
	for _, it := range items {
		kcal += it.Kcal
		prot += it.ProteinG
		carb += it.CarbsG
		fat += it.FatG
	}

	err = tx.QueryRow(ctx, `
		INSERT INTO meals (user_id, slot, title, photo_key, kcal, protein_g, carbs_g, fat_g)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		RETURNING id, slot, title, photo_key, kcal, protein_g, carbs_g, fat_g, eaten_at`,
		uid, slot, title, photoKey, kcal, prot, carb, fat).
		Scan(&m.ID, &m.Slot, &m.Title, &m.PhotoKey, &m.Kcal, &m.ProteinG, &m.CarbsG, &m.FatG, &m.EatenAt)
	if err != nil {
		return m, err
	}

	for i, it := range items {
		_, err = tx.Exec(ctx, `
			INSERT INTO meal_items (meal_id, thai_food_id, name, grams, kcal, protein_g, carbs_g, fat_g, source, confidence, position)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
			m.ID, it.ThaiFoodID, it.Name, it.Grams, it.Kcal, it.ProteinG, it.CarbsG, it.FatG, it.Source, it.Confidence, i)
		if err != nil {
			return m, err
		}
		it.Position = i
		m.Items = append(m.Items, it)
	}
	if err := tx.Commit(ctx); err != nil {
		return m, err
	}
	return m, nil
}

// UpdateMeal replaces a meal's items (edit flow), recomputing totals. Owner-scoped.
func (s *Store) UpdateMeal(ctx context.Context, uid, mealID uuid.UUID, slot, title string, items []domain.MealItem) (domain.Meal, error) {
	var m domain.Meal
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return m, err
	}
	defer tx.Rollback(ctx)

	// ownership check
	var owner uuid.UUID
	if err := tx.QueryRow(ctx, `SELECT user_id FROM meals WHERE id=$1`, mealID).Scan(&owner); err != nil {
		return m, err
	}
	if owner != uid {
		return m, pgx.ErrNoRows
	}

	var kcal int
	var prot, carb, fat float64
	for _, it := range items {
		kcal += it.Kcal
		prot += it.ProteinG
		carb += it.CarbsG
		fat += it.FatG
	}
	if _, err := tx.Exec(ctx, `DELETE FROM meal_items WHERE meal_id=$1`, mealID); err != nil {
		return m, err
	}
	err = tx.QueryRow(ctx, `
		UPDATE meals SET slot=$2, title=$3, kcal=$4, protein_g=$5, carbs_g=$6, fat_g=$7
		WHERE id=$1 RETURNING id, slot, title, photo_key, kcal, protein_g, carbs_g, fat_g, eaten_at`,
		mealID, slot, title, kcal, prot, carb, fat).
		Scan(&m.ID, &m.Slot, &m.Title, &m.PhotoKey, &m.Kcal, &m.ProteinG, &m.CarbsG, &m.FatG, &m.EatenAt)
	if err != nil {
		return m, err
	}
	for i, it := range items {
		if _, err := tx.Exec(ctx, `
			INSERT INTO meal_items (meal_id, thai_food_id, name, grams, kcal, protein_g, carbs_g, fat_g, source, confidence, position)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
			mealID, it.ThaiFoodID, it.Name, it.Grams, it.Kcal, it.ProteinG, it.CarbsG, it.FatG, it.Source, it.Confidence, i); err != nil {
			return m, err
		}
		it.Position = i
		m.Items = append(m.Items, it)
	}
	if err := tx.Commit(ctx); err != nil {
		return m, err
	}
	return m, nil
}

// MatchThaiFood implements food.Matcher via trigram similarity over TH + EN + aliases.
func (s *Store) MatchThaiFood(ctx context.Context, name string) (*food.ThaiFood, float64, error) {
	var tf food.ThaiFood
	var score float64
	err := s.pool.QueryRow(ctx, `
		SELECT id, name_th, name_en, kcal_100g, protein_100g, carbs_100g, fat_100g,
		       GREATEST(
		         similarity(name_th, $1),
		         similarity(name_en, $1),
		         COALESCE((SELECT MAX(similarity(a, $1)) FROM unnest(aliases) a), 0)
		       ) AS score
		FROM thai_foods
		ORDER BY score DESC
		LIMIT 1`, name).
		Scan(&tf.ID, &tf.NameTH, &tf.NameEN, &tf.Kcal100, &tf.Prot100, &tf.Carb100, &tf.Fat100, &score)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, 0, nil
	}
	if err != nil {
		return nil, 0, err
	}
	return &tf, score, nil
}

// ── Pet & streak ─────────────────────────────────────────────

func (s *Store) GetPet(ctx context.Context, uid uuid.UUID) (domain.Pet, error) {
	var p domain.Pet
	var level, xp int
	var name, mood string
	err := s.pool.QueryRow(ctx, `SELECT name, level, xp, mood FROM pets WHERE user_id=$1`, uid).
		Scan(&name, &level, &xp, &mood)
	if err != nil {
		return p, err
	}
	return domain.Pet{Name: name, Level: level, XP: xp, XPMax: game.XPForLevel(level), Mood: mood}, nil
}

// SetPetName renames the user's pet (user-chosen name).
func (s *Store) SetPetName(ctx context.Context, uid uuid.UUID, name string) (domain.Pet, error) {
	if _, err := s.pool.Exec(ctx, `UPDATE pets SET name=$2, updated_at=now() WHERE user_id=$1`, uid, name); err != nil {
		return domain.Pet{}, err
	}
	return s.GetPet(ctx, uid)
}

// AwardXP applies XP and persists the new level/xp, returning levels gained.
func (s *Store) AwardXP(ctx context.Context, uid uuid.UUID, gained int) (domain.Pet, int, error) {
	var level, xp int
	if err := s.pool.QueryRow(ctx, `SELECT level, xp FROM pets WHERE user_id=$1`, uid).Scan(&level, &xp); err != nil {
		return domain.Pet{}, 0, err
	}
	newLevel, newXP, gainedLevels := game.AddXP(level, xp, gained)
	_, err := s.pool.Exec(ctx, `UPDATE pets SET level=$2, xp=$3, updated_at=now() WHERE user_id=$1`, uid, newLevel, newXP)
	if err != nil {
		return domain.Pet{}, 0, err
	}
	pet, err := s.GetPet(ctx, uid)
	return pet, gainedLevels, err
}

func (s *Store) GetStreak(ctx context.Context, uid uuid.UUID) (domain.Streak, error) {
	var st domain.Streak
	var last *time.Time
	err := s.pool.QueryRow(ctx, `SELECT count, freezes_left, last_active FROM streaks WHERE user_id=$1`, uid).
		Scan(&st.Count, &st.FreezesLeft, &last)
	if err != nil {
		return st, err
	}
	if last != nil {
		st.LastActive = last.Format("2006-01-02")
	}
	return st, nil
}

// TouchStreak records activity for today, applying freeze rules.
func (s *Store) TouchStreak(ctx context.Context, uid uuid.UUID, today time.Time) (domain.Streak, error) {
	var count, freezes int
	var last *time.Time
	if err := s.pool.QueryRow(ctx, `SELECT count, freezes_left, last_active FROM streaks WHERE user_id=$1`, uid).
		Scan(&count, &freezes, &last); err != nil {
		return domain.Streak{}, err
	}
	newCount, newFreezes, already := game.StreakOnActivity(count, freezes, last, today)
	if !already {
		if _, err := s.pool.Exec(ctx, `UPDATE streaks SET count=$2, freezes_left=$3, last_active=$4 WHERE user_id=$1`,
			uid, newCount, newFreezes, today); err != nil {
			return domain.Streak{}, err
		}
	}
	return s.GetStreak(ctx, uid)
}

// ── Workouts ─────────────────────────────────────────────────

func (s *Store) CreateWorkout(ctx context.Context, uid uuid.UUID, title string) (uuid.UUID, error) {
	var id uuid.UUID
	err := s.pool.QueryRow(ctx, `INSERT INTO workouts (user_id, title) VALUES ($1,$2) RETURNING id`, uid, title).Scan(&id)
	return id, err
}

func (s *Store) CompleteWorkout(ctx context.Context, uid, workoutID uuid.UUID, burned, durationS int) error {
	ct, err := s.pool.Exec(ctx, `
		UPDATE workouts SET status='done', kcal_burned=$3, duration_s=$4, finished_at=now()
		WHERE id=$2 AND user_id=$1`, uid, workoutID, burned, durationS)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// ── Body scans ───────────────────────────────────────────────

func (s *Store) CreateBodyScan(ctx context.Context, uid uuid.UUID, sc domain.BodyScan, notesJSON []byte, frontKey, sideKey *string) (domain.BodyScan, error) {
	err := s.pool.QueryRow(ctx, `
		INSERT INTO body_scans (user_id, weight_kg, bf_pct, bf_low, bf_high, front_key, side_key, notes)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		RETURNING id, scanned_at`,
		uid, sc.WeightKg, sc.BfPct, sc.BfLow, sc.BfHigh, frontKey, sideKey, notesJSON).
		Scan(&sc.ID, &sc.ScannedAt)
	return sc, err
}

func (s *Store) ListBodyScans(ctx context.Context, uid uuid.UUID, limit int) ([]domain.BodyScan, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, weight_kg, bf_pct, bf_low, bf_high, notes, scanned_at
		FROM body_scans WHERE user_id=$1 ORDER BY scanned_at DESC LIMIT $2`, uid, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.BodyScan
	for rows.Next() {
		var b domain.BodyScan
		if err := rows.Scan(&b.ID, &b.WeightKg, &b.BfPct, &b.BfLow, &b.BfHigh, &b.Notes, &b.ScannedAt); err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

// ── Subscription & AI usage ──────────────────────────────────

func (s *Store) Tier(ctx context.Context, uid uuid.UUID) (string, error) {
	var tier string
	var expires *time.Time
	err := s.pool.QueryRow(ctx, `SELECT tier, expires_at FROM subscriptions WHERE user_id=$1`, uid).Scan(&tier, &expires)
	if err != nil {
		return "free", err
	}
	if tier != "free" && expires != nil && expires.Before(time.Now()) {
		return "free", nil
	}
	return tier, nil
}

// AIUsageThisMonth returns the count of AI food logs used in the given month.
func (s *Store) AIUsageThisMonth(ctx context.Context, uid uuid.UUID, yyyymm int) (int, error) {
	var n int
	err := s.pool.QueryRow(ctx, `SELECT COALESCE(food_logs,0) FROM ai_usage WHERE user_id=$1 AND yyyymm=$2`, uid, yyyymm).Scan(&n)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, nil
	}
	return n, err
}

func (s *Store) IncAIUsage(ctx context.Context, uid uuid.UUID, yyyymm int) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO ai_usage (user_id, yyyymm, food_logs) VALUES ($1,$2,1)
		ON CONFLICT (user_id, yyyymm) DO UPDATE SET food_logs = ai_usage.food_logs + 1`, uid, yyyymm)
	return err
}

func nz(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
