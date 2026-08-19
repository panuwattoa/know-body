package calc

import "testing"

func TestDailyMaleModerateLose(t *testing.T) {
	// 30yo male, 180cm, 80kg, moderate, lose.
	// BMR = 10*80 + 6.25*180 - 5*30 + 5 = 800+1125-150+5 = 1780
	// TDEE = 1780*1.55 = 2759 ; lose → -500 = 2259 → round10 = 2260
	got := Daily("m", 30, 180, 80, "moderate", "lose")
	if got.BMR != 1780 {
		t.Fatalf("BMR=%d want 1780", got.BMR)
	}
	if got.Kcal != 2260 {
		t.Fatalf("Kcal=%d want 2260", got.Kcal)
	}
	if got.ProteinG != 144 { // 1.8*80
		t.Fatalf("protein=%d want 144", got.ProteinG)
	}
}

func TestDailyFloor(t *testing.T) {
	got := Daily("f", 60, 150, 45, "sedentary", "lose")
	if got.Kcal < 1200 {
		t.Fatalf("kcal=%d below floor", got.Kcal)
	}
}
