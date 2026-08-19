// Package domain holds the core data types shared across the API.
package domain

import (
	"time"

	"github.com/google/uuid"
)

type Profile struct {
	UserID        uuid.UUID `json:"userId"`
	Goal          string    `json:"goal"`
	Locale        string    `json:"locale"`
	DailyKcalGoal int       `json:"dailyKcalGoal"`
	ProteinGoal   int       `json:"proteinGoalG"`
	CarbsGoal     int       `json:"carbsGoalG"`
	FatGoal       int       `json:"fatGoalG"`
}

type MealItem struct {
	ID         uuid.UUID  `json:"id"`
	ThaiFoodID *uuid.UUID `json:"thaiFoodId,omitempty"`
	Name       string     `json:"name"`
	Grams      float64    `json:"grams"`
	Kcal       int        `json:"kcal"`
	ProteinG   float64    `json:"proteinG"`
	CarbsG     float64    `json:"carbsG"`
	FatG       float64    `json:"fatG"`
	Source     string     `json:"source"`     // thai_db | ai | manual
	Confidence *float64   `json:"confidence,omitempty"`
	Position   int        `json:"position"`
}

type Meal struct {
	ID        uuid.UUID  `json:"id"`
	Slot      string     `json:"slot"`
	Title     string     `json:"title"`
	PhotoKey  *string    `json:"photoKey,omitempty"`
	Kcal      int        `json:"kcal"`
	ProteinG  float64    `json:"proteinG"`
	CarbsG    float64    `json:"carbsG"`
	FatG      float64    `json:"fatG"`
	EatenAt   time.Time  `json:"eatenAt"`
	Items     []MealItem `json:"items,omitempty"`
}

type Pet struct {
	Name  string `json:"name"`
	Level int    `json:"level"`
	XP    int    `json:"xp"`
	XPMax int    `json:"xpMax"`
	Mood  string `json:"mood"`
}

type Streak struct {
	Count       int    `json:"count"`
	FreezesLeft int    `json:"freezesLeft"`
	LastActive  string `json:"lastActive,omitempty"` // YYYY-MM-DD
}

// DaySummary is a compact recap for a single day (used for "yesterday").
type DaySummary struct {
	KcalEaten  int  `json:"kcalEaten"`
	KcalGoal   int  `json:"kcalGoal"`
	Meals      int  `json:"meals"`
	WorkedOut  bool `json:"workedOut"`
	OnTarget   bool `json:"onTarget"` // within ±10% of goal
}

// Home is the aggregated payload behind the Home screen's calorie ring.
type Home struct {
	Profile    Profile    `json:"profile"`
	KcalGoal   int        `json:"kcalGoal"`
	KcalEaten  int        `json:"kcalEaten"`
	KcalBurned int        `json:"kcalBurned"`
	KcalLeft   int        `json:"kcalLeft"`
	ProteinG   float64    `json:"proteinG"`
	CarbsG     float64    `json:"carbsG"`
	FatG       float64    `json:"fatG"`
	Meals      []Meal     `json:"meals"`
	Pet        Pet        `json:"pet"`
	Streak     Streak     `json:"streak"`
	Tier       string     `json:"tier"` // free | plus | coach
	Yesterday  DaySummary `json:"yesterday"`
	Suggestion string     `json:"suggestion"` // suggested next workout title
}

type BodyScan struct {
	ID        uuid.UUID `json:"id"`
	WeightKg  *float64  `json:"weightKg,omitempty"`
	BfPct     *float64  `json:"bodyFatPct,omitempty"`
	BfLow     *float64  `json:"bodyFatLow,omitempty"`
	BfHigh    *float64  `json:"bodyFatHigh,omitempty"`
	Notes     []string  `json:"notes"`
	ScannedAt time.Time `json:"scannedAt"`
}
