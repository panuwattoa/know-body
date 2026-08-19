// Package plan builds suggested workout lists from a user's goal — no I/O.
package plan

// Exercise is one movement in a workout.
type Exercise struct {
	Name    string `json:"name"`
	NameEN  string `json:"nameEn"`
	Sets    int    `json:"sets"`
	Reps    int    `json:"reps"`
	Secs    int    `json:"secs"` // for timed holds (0 if rep-based)
}

// Workout is a suggested session.
type Workout struct {
	Title   string     `json:"title"`
	TitleEN string     `json:"titleEn"`
	Day     string     `json:"day"`    // e.g. "จันทร์" / "Mon" (program label)
	Minutes int        `json:"minutes"`
	Kcal    int        `json:"kcal"`
	Focus   string     `json:"focus"` // easy | strength | cardio | mobility
	Moves   []Exercise `json:"moves"`
}

// Suggest returns a small weekly plan tailored to the goal.
// goal: eat_better | move_more | keep_pet_happy ; goalDir: lose | maintain | gain.
func Suggest(goal, goalDir string) []Workout {
	easy := Workout{
		Title: "วอร์มเบา ๆ", TitleEN: "Easy warm-up", Minutes: 5, Kcal: 40, Focus: "easy",
		Moves: []Exercise{
			{Name: "หมุนไหล่", NameEN: "Shoulder rolls", Sets: 2, Reps: 15},
			{Name: "ย่อเข่า", NameEN: "Bodyweight squat", Sets: 2, Reps: 10},
			{Name: "ยืดสะโพก", NameEN: "Hip hinge stretch", Sets: 1, Secs: 40},
		},
	}
	strength := Workout{
		Title: "เวทบอดี้เวท", TitleEN: "Bodyweight strength", Minutes: 15, Kcal: 150, Focus: "strength",
		Moves: []Exercise{
			{Name: "สควอท", NameEN: "Squat", Sets: 3, Reps: 12},
			{Name: "วิดพื้นเอียง", NameEN: "Incline push-up", Sets: 3, Reps: 8},
			{Name: "โน้มตัวดึง", NameEN: "Row (band/table)", Sets: 3, Reps: 10},
			{Name: "แพลงก์", NameEN: "Plank", Sets: 2, Secs: 30},
		},
	}
	cardio := Workout{
		Title: "คาร์ดิโอกระฉับกระเฉง", TitleEN: "Brisk cardio", Minutes: 12, Kcal: 120, Focus: "cardio",
		Moves: []Exercise{
			{Name: "จ๊อกกิ้งอยู่กับที่", NameEN: "Jog in place", Sets: 3, Secs: 60},
			{Name: "กระโดดตบ", NameEN: "Jumping jacks", Sets: 3, Reps: 20},
			{Name: "เข่าสูง", NameEN: "High knees", Sets: 3, Secs: 30},
		},
	}
	mobility := Workout{
		Title: "ยืดเหยียดผ่อนคลาย", TitleEN: "Mobility & stretch", Minutes: 8, Kcal: 45, Focus: "mobility",
		Moves: []Exercise{
			{Name: "ยืดคอ", NameEN: "Neck stretch", Sets: 1, Secs: 30},
			{Name: "ยืดหลังแมว-วัว", NameEN: "Cat-cow", Sets: 2, Reps: 10},
			{Name: "ยืดต้นขาหลัง", NameEN: "Hamstring stretch", Sets: 1, Secs: 40},
		},
	}

	upper := Workout{
		Title: "ช่วงบน (อก-หลัง-แขน)", TitleEN: "Upper body", Minutes: 18, Kcal: 160, Focus: "strength",
		Moves: []Exercise{
			{Name: "วิดพื้น", NameEN: "Push-up", Sets: 3, Reps: 10},
			{Name: "โน้มตัวดึง", NameEN: "Bent-over row", Sets: 3, Reps: 12},
			{Name: "ดันไหล่", NameEN: "Pike push-up", Sets: 3, Reps: 8},
			{Name: "แพลงก์", NameEN: "Plank", Sets: 3, Secs: 30},
		},
	}
	lower := Workout{
		Title: "ช่วงล่าง (ขา-สะโพก)", TitleEN: "Lower body", Minutes: 18, Kcal: 170, Focus: "strength",
		Moves: []Exercise{
			{Name: "สควอท", NameEN: "Squat", Sets: 4, Reps: 12},
			{Name: "ลันจ์", NameEN: "Lunge", Sets: 3, Reps: 10},
			{Name: "กลูตบริดจ์", NameEN: "Glute bridge", Sets: 3, Reps: 15},
			{Name: "ยืนเขย่งน่อง", NameEN: "Calf raise", Sets: 3, Reps: 20},
		},
	}
	core := Workout{
		Title: "แกนกลางลำตัว", TitleEN: "Core", Minutes: 10, Kcal: 80, Focus: "strength",
		Moves: []Exercise{
			{Name: "แพลงก์", NameEN: "Plank", Sets: 3, Secs: 40},
			{Name: "ครันช์", NameEN: "Crunch", Sets: 3, Reps: 15},
			{Name: "เมาน์เทนไคลม์เบอร์", NameEN: "Mountain climber", Sets: 3, Secs: 30},
		},
	}

	days := []string{"จันทร์", "อังคาร", "พุธ", "พฤหัส", "ศุกร์", "เสาร์"}
	var program []Workout
	switch {
	case goalDir == "gain":
		program = []Workout{upper, lower, core, upper, mobility}
	case goalDir == "lose":
		program = []Workout{cardio, lower, cardio, upper, core, easy}
	case goal == "move_more":
		program = []Workout{easy, cardio, strength, mobility, cardio}
	default:
		program = []Workout{easy, upper, lower, core, mobility}
	}
	// Label each session as a program day.
	for i := range program {
		if i < len(days) {
			program[i].Day = days[i]
		}
	}
	return program
}
