package game

import (
	"testing"
	"time"
)

func TestAddXPLevelsUp(t *testing.T) {
	// Level 1 needs 100 XP. Adding 250 → level 2 (250-100=150 ≥ XPForLevel(2)=130 → level 3, 20 left).
	lvl, xp, gained := AddXP(1, 0, 250)
	if lvl != 3 || gained != 2 {
		t.Fatalf("got level=%d gained=%d, want level=3 gained=2 (xp=%d)", lvl, gained, xp)
	}
}

func TestStreakFreezeSavesOneMissedDay(t *testing.T) {
	last := time.Date(2026, 8, 17, 0, 0, 0, 0, time.UTC) // 2 days before "today"
	today := time.Date(2026, 8, 19, 0, 0, 0, 0, time.UTC)
	count, freezes, already := StreakOnActivity(5, 2, &last, today)
	if already || count != 6 || freezes != 1 {
		t.Fatalf("got count=%d freezes=%d already=%v, want 6/1/false", count, freezes, already)
	}
}

func TestStreakBreaksAfterGap(t *testing.T) {
	last := time.Date(2026, 8, 10, 0, 0, 0, 0, time.UTC)
	today := time.Date(2026, 8, 19, 0, 0, 0, 0, time.UTC)
	count, _, _ := StreakOnActivity(9, 0, &last, today)
	if count != 1 {
		t.Fatalf("got count=%d, want 1 (reset)", count)
	}
}

func TestStreakSameDayNoDouble(t *testing.T) {
	last := time.Date(2026, 8, 19, 8, 0, 0, 0, time.UTC)
	today := time.Date(2026, 8, 19, 20, 0, 0, 0, time.UTC)
	count, _, already := StreakOnActivity(4, 2, &last, today)
	if !already || count != 4 {
		t.Fatalf("got count=%d already=%v, want 4/true", count, already)
	}
}
