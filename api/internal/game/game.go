// Package game holds KnowBody's pet-XP and streak rules — pure functions, no I/O.
package game

import "time"

// XPForLevel returns the XP needed to advance FROM the given level to the next.
// Gentle curve: level 1 needs 100, growing ~1.35x per level (Lv7 ≈ 400 in the design).
func XPForLevel(level int) int {
	if level < 1 {
		level = 1
	}
	xp := 100.0
	for i := 1; i < level; i++ {
		xp *= 1.35
	}
	return int(xp/10) * 10 // round to nearest 10 for tidy UI
}

// AddXP applies gained XP to a (level, xp-within-level) pair and returns the new
// state plus how many levels were gained (for the reward modal).
func AddXP(level, xp, gained int) (newLevel, newXP, levelsGained int) {
	level, xp = max(level, 1), max(xp, 0)
	xp += max(gained, 0)
	for xp >= XPForLevel(level) {
		xp -= XPForLevel(level)
		level++
		levelsGained++
	}
	return level, xp, levelsGained
}

// XP awards per action — the visible "+N XP" chips in the design.
const (
	XPLogMeal        = 10
	XPFinishWorkout  = 8
	XPBodyScan       = 15
	XPPartialWorkout = 4
)

// Mood derives Mochi's mood from recent activity.
func Mood(streak int, loggedToday, workedOutToday bool) string {
	switch {
	case workedOutToday:
		return "cheering"
	case loggedToday && streak >= 3:
		return "happy"
	case loggedToday:
		return "content"
	default:
		return "sleepy"
	}
}

// StreakOnActivity updates a streak given the last active date and today.
// Missing exactly one day consumes a freeze if available; a longer gap resets.
// Returns the new count, remaining freezes, and whether today was already counted.
func StreakOnActivity(count, freezes int, last *time.Time, today time.Time) (newCount, newFreezes int, alreadyCounted bool) {
	td := today.Truncate(24 * time.Hour)
	if last == nil {
		return 1, freezes, false
	}
	ld := last.Truncate(24 * time.Hour)
	days := int(td.Sub(ld).Hours() / 24)
	switch {
	case days <= 0:
		return count, freezes, true // already active today
	case days == 1:
		return count + 1, freezes, false
	case days == 2 && freezes > 0:
		return count + 1, freezes - 1, false // one missed day, freeze saves it
	default:
		return 1, freezes, false // streak broken
	}
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
