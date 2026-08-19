// Package calc computes personalized calorie and macro targets — pure functions.
package calc

import "math"

// Targets is a daily nutrition goal.
type Targets struct {
	Kcal      int `json:"dailyKcalGoal"`
	ProteinG  int `json:"proteinGoalG"`
	CarbsG    int `json:"carbsGoalG"`
	FatG      int `json:"fatGoalG"`
	BMR       int `json:"bmr"`
	TDEE      int `json:"tdee"`
}

func activityFactor(level string) float64 {
	switch level {
	case "sedentary":
		return 1.2
	case "moderate":
		return 1.55
	case "active":
		return 1.725
	case "very":
		return 1.9
	default: // light
		return 1.375
	}
}

// Daily computes targets via Mifflin-St Jeor BMR × activity, then adjusts for goal.
// sex: "m"|"f"; missing/odd inputs fall back to sensible defaults.
func Daily(sex string, age int, heightCm, weightKg float64, activity, goalDir string) Targets {
	if age <= 0 || age > 120 {
		age = 30
	}
	if heightCm <= 0 {
		heightCm = 170
	}
	if weightKg <= 0 {
		weightKg = 70
	}

	s := -161.0 // female
	if sex == "m" {
		s = 5.0
	}
	bmr := 10*weightKg + 6.25*heightCm - 5*float64(age) + s
	tdee := bmr * activityFactor(activity)

	kcal := tdee
	switch goalDir {
	case "lose":
		kcal = tdee - 500 // ~0.45 kg/week deficit
	case "gain":
		kcal = tdee + 300
	}
	if kcal < 1200 {
		kcal = 1200 // safety floor
	}

	// Macros: protein 1.8 g/kg, fat 25% of kcal, carbs the remainder.
	protein := 1.8 * weightKg
	fat := (kcal * 0.25) / 9.0
	carbs := (kcal - protein*4 - fat*9) / 4.0
	if carbs < 0 {
		carbs = 0
	}

	return Targets{
		Kcal:     roundTo(kcal, 10),
		ProteinG: int(math.Round(protein)),
		CarbsG:   int(math.Round(carbs)),
		FatG:     int(math.Round(fat)),
		BMR:      int(math.Round(bmr)),
		TDEE:     int(math.Round(tdee)),
	}
}

func roundTo(v float64, step int) int {
	return int(math.Round(v/float64(step))) * step
}
