// Package food turns a meal photo into an editable draft of ingredients:
// Claude vision proposes items, then each is reconciled against the Thai food DB.
package food

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"

	"knowbody/api/internal/ai"
	"knowbody/api/internal/domain"
)

var errAINotEnabled = errors.New("ai not enabled")

// ThaiFood is a reference row used to reconcile AI guesses with curated data.
type ThaiFood struct {
	ID       string
	NameTH   string
	NameEN   string
	Kcal100  float64
	Prot100  float64
	Carb100  float64
	Fat100   float64
}

// Matcher finds the closest curated Thai food for a free-text name (trigram search).
type Matcher interface {
	MatchThaiFood(ctx context.Context, name string) (*ThaiFood, float64, error)
}

// Vision is any structured multimodal model (Gemini, Claude, …). Providers live in
// package ai; the service only depends on this interface so we can switch freely.
type Vision interface {
	Enabled() bool
	AnalyzeStructured(ctx context.Context, instruction string, imgs []ai.Image, toolName string, schema map[string]any) (json.RawMessage, error)
}

type Service struct {
	ai      Vision
	matcher Matcher
}

func NewService(v Vision, m Matcher) *Service {
	return &Service{ai: v, matcher: m}
}

// Draft is the editable analysis returned to the app before the user saves.
type Draft struct {
	Title string             `json:"title"`
	Slot  string             `json:"slot"`
	Items []domain.MealItem  `json:"items"`
}

var foodSchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"title": map[string]any{"type": "string", "description": "Short dish name, Thai if visible."},
		"slot":  map[string]any{"type": "string", "enum": []string{"breakfast", "lunch", "dinner", "snack"}},
		"items": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"name":       map[string]any{"type": "string"},
					"grams":      map[string]any{"type": "number"},
					"kcal":       map[string]any{"type": "number"},
					"protein_g":  map[string]any{"type": "number"},
					"carbs_g":    map[string]any{"type": "number"},
					"fat_g":      map[string]any{"type": "number"},
					"confidence": map[string]any{"type": "number", "description": "0..1"},
				},
				"required": []string{"name", "grams", "kcal"},
			},
		},
	},
	"required": []string{"title", "slot", "items"},
}

const instruction = `You are KnowBody's food vision model for Thai cuisine.
Identify each distinct food/drink in the photo. Estimate the edible weight in grams and the
calories and macros for that portion. Prefer Thai dish names. Keep it a best-effort estimate —
set a confidence 0..1 per item. Call the record_meal tool with your result.`

// Analyze runs the photo through Claude (or the stub), then reconciles each item
// with the Thai food DB, recomputing kcal/macros from curated per-100g values when matched.
func (s *Service) Analyze(ctx context.Context, jpegBase64 string) (*Draft, error) {
	var raw json.RawMessage
	if s.ai.Enabled() {
		out, err := s.ai.AnalyzeStructured(ctx, instruction,
			[]ai.Image{{MediaType: "image/jpeg", Base64: jpegBase64}}, "record_meal", foodSchema)
		if err != nil {
			return nil, err
		}
		raw = out
	} else {
		raw = stubMeal // keyless local dev
	}

	var parsed struct {
		Title string `json:"title"`
		Slot  string `json:"slot"`
		Items []struct {
			Name       string  `json:"name"`
			Grams      float64 `json:"grams"`
			Kcal       float64 `json:"kcal"`
			ProteinG   float64 `json:"protein_g"`
			CarbsG     float64 `json:"carbs_g"`
			FatG       float64 `json:"fat_g"`
			Confidence float64 `json:"confidence"`
		} `json:"items"`
	}
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return nil, err
	}

	draft := &Draft{Title: parsed.Title, Slot: orDefault(parsed.Slot, "snack")}
	for i, it := range parsed.Items {
		conf := it.Confidence
		item := domain.MealItem{
			Name:       it.Name,
			Grams:      it.Grams,
			Kcal:       int(it.Kcal + 0.5),
			ProteinG:   it.ProteinG,
			CarbsG:     it.CarbsG,
			FatG:       it.FatG,
			Source:     "ai",
			Confidence: &conf,
			Position:   i,
		}
		// Reconcile with curated Thai data when we get a confident name match.
		if s.matcher != nil {
			if tf, score, err := s.matcher.MatchThaiFood(ctx, it.Name); err == nil && tf != nil && score >= 0.35 {
				f := it.Grams / 100.0
				item.ThaiFoodID = parseUUIDPtr(tf.ID)
				item.Kcal = int(tf.Kcal100*f + 0.5)
				item.ProteinG = round1(tf.Prot100 * f)
				item.CarbsG = round1(tf.Carb100 * f)
				item.FatG = round1(tf.Fat100 * f)
				item.Source = "thai_db"
			}
		}
		draft.Items = append(draft.Items, item)
	}
	return draft, nil
}

// BodyDraft is the AI body-scan estimate — always expressed as a range, never a verdict.
type BodyDraft struct {
	BodyFatPct  float64  `json:"bodyFatPct"`
	BodyFatLow  float64  `json:"bodyFatLow"`
	BodyFatHigh float64  `json:"bodyFatHigh"`
	Notes       []string `json:"notes"`
	Disclaimer  string   `json:"disclaimer"`
}

var bodySchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"bodyFatPct":  map[string]any{"type": "number"},
		"bodyFatLow":  map[string]any{"type": "number"},
		"bodyFatHigh": map[string]any{"type": "number"},
		"notes": map[string]any{
			"type":  "array",
			"items": map[string]any{"type": "string"},
			"description": "Short observations, e.g. 'Shoulders a little wider', 'Waist down ~2cm'.",
		},
	},
	"required": []string{"bodyFatPct", "bodyFatLow", "bodyFatHigh", "notes"},
}

const bodyInstruction = `You are KnowBody's supportive body-composition estimator.
From these two photos (front and side) and the optional weight, estimate body-fat percentage as a
RANGE, never a single verdict. Add a few gentle, non-judgemental observations about visible change.
These are estimates that drift with light and posture. Call record_scan.`

// AnalyzeBody estimates body composition as a range (Plus feature).
func (s *Service) AnalyzeBody(ctx context.Context, frontB64, sideB64 string, weightKg float64) (*BodyDraft, error) {
	const disclaimer = "Estimates only — not a medical measurement. Trust the trend, not one number."
	var raw json.RawMessage
	if s.ai.Enabled() {
		imgs := []ai.Image{{MediaType: "image/jpeg", Base64: frontB64}, {MediaType: "image/jpeg", Base64: sideB64}}
		out, err := s.ai.AnalyzeStructured(ctx, bodyInstruction, imgs, "record_scan", bodySchema)
		if err != nil {
			return nil, err
		}
		raw = out
	} else {
		raw = stubScan
	}
	var d BodyDraft
	if err := json.Unmarshal(raw, &d); err != nil {
		return nil, err
	}
	d.Disclaimer = disclaimer
	return &d, nil
}

var stubScan = json.RawMessage(`{
  "bodyFatPct": 21.6, "bodyFatLow": 20.4, "bodyFatHigh": 22.8,
  "notes": ["Shoulders a little wider — matches your push work","Waist down about 2 cm this month","Head sits slightly forward — desk posture"]
}`)

// ── AI personal-trainer program ──────────────────────────────

// ProgramInput is the profile data handed to the AI trainer.
type ProgramInput struct {
	Sex        string
	Age        int
	HeightCm   float64
	WeightKg   float64
	Activity   string
	Goal       string
	GoalDir    string
	TargetDate string // "YYYY-MM-DD" or ""
	Weeks      int
	Locale     string
}

var programSchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"summary": map[string]any{"type": "string", "description": "One-line plan summary in the user's language."},
		"workouts": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"title":   map[string]any{"type": "string"},
					"titleEn": map[string]any{"type": "string"},
					"day":     map[string]any{"type": "string", "description": "Weekday label in the user's language, e.g. จันทร์/Mon."},
					"minutes": map[string]any{"type": "number"},
					"kcal":    map[string]any{"type": "number"},
					"focus":   map[string]any{"type": "string"},
					"moves": map[string]any{
						"type": "array",
						"items": map[string]any{
							"type": "object",
							"properties": map[string]any{
								"name":   map[string]any{"type": "string"},
								"nameEn": map[string]any{"type": "string"},
								"sets":   map[string]any{"type": "number"},
								"reps":   map[string]any{"type": "number"},
								"secs":   map[string]any{"type": "number"},
							},
							"required": []string{"name", "sets"},
						},
					},
				},
				"required": []string{"title", "day", "minutes", "moves"},
			},
		},
	},
	"required": []string{"summary", "workouts"},
}

// GenerateProgram asks the model for a personalized weekly workout program.
// Returns the raw JSON (matching programSchema) or an error if AI is disabled/failed.
func (s *Service) GenerateProgram(ctx context.Context, in ProgramInput) (json.RawMessage, error) {
	if !s.ai.Enabled() {
		return nil, errAINotEnabled
	}
	lang := "Thai"
	if in.Locale == "en" {
		lang = "English"
	}
	target := "no fixed date"
	if in.TargetDate != "" {
		target = in.TargetDate
	}
	prompt := fmt.Sprintf(`You are an experienced personal trainer building a weekly workout program for one client.
Client: sex=%s, age=%d, height=%.0fcm, weight=%.0fkg, activity level=%s, main goal=%s, direction=%s.
Target date: %s (about %d weeks away).
Design a realistic, progressive weekly program of 4-6 sessions the client can do mostly at home/bodyweight,
appropriate for their level and goal, building toward the target date. Give each session a weekday label,
estimated minutes and kcal, a focus, and 3-6 exercises with sets and reps (use secs for timed holds).
Write all names and the summary in %s. Call record_program.`,
		orDefault(in.Sex, "unspecified"), in.Age, in.HeightCm, in.WeightKg, in.Activity, in.Goal, in.GoalDir, target, in.Weeks, lang)

	return s.ai.AnalyzeStructured(ctx, prompt, nil, "record_program", programSchema)
}

func orDefault(v, def string) string {
	if strings.TrimSpace(v) == "" {
		return def
	}
	return v
}

func round1(v float64) float64 { return float64(int(v*10+0.5)) / 10 }

func parseUUIDPtr(s string) *uuid.UUID {
	id, err := uuid.Parse(s)
	if err != nil {
		return nil
	}
	return &id
}

// stubMeal mirrors the design's "Chicken rice bowl · 4 ingredients".
var stubMeal = json.RawMessage(`{
  "title": "Chicken rice bowl",
  "slot": "lunch",
  "items": [
    {"name":"ข้าวสวย","grams":180,"kcal":234,"protein_g":4.9,"carbs_g":50.4,"fat_g":0.5,"confidence":0.9},
    {"name":"อกไก่","grams":120,"kcal":144,"protein_g":27.6,"carbs_g":0,"fat_g":3.1,"confidence":0.86},
    {"name":"ผัดผักบุ้ง","grams":90,"kcal":68,"protein_g":2.3,"carbs_g":5.4,"fat_g":4.1,"confidence":0.7},
    {"name":"ไข่ดาว","grams":50,"kcal":98,"protein_g":6.8,"carbs_g":0.4,"fat_g":7.5,"confidence":0.8}
  ]
}`)
