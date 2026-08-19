/// Data models mirroring the Go API's JSON (see api/internal/domain).
class Profile {
  final String goal, locale;
  final int dailyKcalGoal, proteinGoalG, carbsGoalG, fatGoalG;
  Profile({
    required this.goal,
    required this.locale,
    required this.dailyKcalGoal,
    required this.proteinGoalG,
    required this.carbsGoalG,
    required this.fatGoalG,
  });
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        goal: j['goal'] ?? 'eat_better',
        locale: j['locale'] ?? 'th',
        dailyKcalGoal: j['dailyKcalGoal'] ?? 2000,
        proteinGoalG: j['proteinGoalG'] ?? 120,
        carbsGoalG: j['carbsGoalG'] ?? 220,
        fatGoalG: j['fatGoalG'] ?? 60,
      );
}

class MealItem {
  final String? thaiFoodId;
  final String name, source;
  final double grams, proteinG, carbsG, fatG;
  final int kcal;
  final double? confidence;
  MealItem({
    this.thaiFoodId,
    required this.name,
    required this.grams,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.source,
    this.confidence,
  });
  factory MealItem.fromJson(Map<String, dynamic> j) => MealItem(
        thaiFoodId: j['thaiFoodId'],
        name: j['name'] ?? '',
        grams: (j['grams'] ?? 0).toDouble(),
        kcal: j['kcal'] ?? 0,
        proteinG: (j['proteinG'] ?? 0).toDouble(),
        carbsG: (j['carbsG'] ?? 0).toDouble(),
        fatG: (j['fatG'] ?? 0).toDouble(),
        source: j['source'] ?? 'ai',
        confidence: (j['confidence'] as num?)?.toDouble(),
      );
  Map<String, dynamic> toJson() => {
        'thaiFoodId': thaiFoodId,
        'name': name,
        'grams': grams,
        'kcal': kcal,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'source': source,
        'confidence': confidence,
      };
}

class Meal {
  final String id, slot, title;
  final int kcal;
  final double proteinG, carbsG, fatG;
  final DateTime eatenAt;
  final List<MealItem> items;
  Meal({
    required this.id,
    required this.slot,
    required this.title,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.eatenAt,
    this.items = const [],
  });
  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        id: j['id'] ?? '',
        slot: j['slot'] ?? 'snack',
        title: j['title'] ?? '',
        kcal: j['kcal'] ?? 0,
        proteinG: (j['proteinG'] ?? 0).toDouble(),
        carbsG: (j['carbsG'] ?? 0).toDouble(),
        fatG: (j['fatG'] ?? 0).toDouble(),
        eatenAt: DateTime.tryParse(j['eatenAt'] ?? '') ?? DateTime.now(),
        items: (j['items'] as List? ?? []).map((e) => MealItem.fromJson(e)).toList(),
      );
}

class Pet {
  final String name, mood;
  final int level, xp, xpMax;
  Pet({required this.name, required this.mood, required this.level, required this.xp, required this.xpMax});
  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
        name: j['name'] ?? 'Mochi',
        mood: j['mood'] ?? 'content',
        level: j['level'] ?? 1,
        xp: j['xp'] ?? 0,
        xpMax: j['xpMax'] ?? 100,
      );
  double get xpPct => xpMax == 0 ? 0 : (xp / xpMax).clamp(0, 1).toDouble();
}

class Streak {
  final int count, freezesLeft;
  Streak({required this.count, required this.freezesLeft});
  factory Streak.fromJson(Map<String, dynamic> j) =>
      Streak(count: j['count'] ?? 0, freezesLeft: j['freezesLeft'] ?? 0);
}

class DaySummary {
  final int kcalEaten, kcalGoal, meals;
  final bool workedOut, onTarget;
  DaySummary({required this.kcalEaten, required this.kcalGoal, required this.meals, required this.workedOut, required this.onTarget});
  factory DaySummary.fromJson(Map<String, dynamic> j) => DaySummary(
        kcalEaten: j['kcalEaten'] ?? 0,
        kcalGoal: j['kcalGoal'] ?? 0,
        meals: j['meals'] ?? 0,
        workedOut: j['workedOut'] ?? false,
        onTarget: j['onTarget'] ?? false,
      );
  bool get hasData => kcalEaten > 0 || meals > 0 || workedOut;
}

class Home {
  final Profile profile;
  final int kcalGoal, kcalEaten, kcalBurned, kcalLeft;
  final double proteinG, carbsG, fatG;
  final List<Meal> meals;
  final Pet pet;
  final Streak streak;
  final String tier;
  final DaySummary yesterday;
  final String suggestion;
  Home({
    required this.profile,
    required this.kcalGoal,
    required this.kcalEaten,
    required this.kcalBurned,
    required this.kcalLeft,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.meals,
    required this.pet,
    required this.streak,
    required this.tier,
    required this.yesterday,
    required this.suggestion,
  });
  factory Home.fromJson(Map<String, dynamic> j) => Home(
        profile: Profile.fromJson(j['profile'] ?? {}),
        kcalGoal: j['kcalGoal'] ?? 2000,
        kcalEaten: j['kcalEaten'] ?? 0,
        kcalBurned: j['kcalBurned'] ?? 0,
        kcalLeft: j['kcalLeft'] ?? 0,
        proteinG: (j['proteinG'] ?? 0).toDouble(),
        carbsG: (j['carbsG'] ?? 0).toDouble(),
        fatG: (j['fatG'] ?? 0).toDouble(),
        meals: (j['meals'] as List? ?? []).map((e) => Meal.fromJson(e)).toList(),
        pet: Pet.fromJson(j['pet'] ?? {}),
        streak: Streak.fromJson(j['streak'] ?? {}),
        tier: j['tier'] ?? 'free',
        yesterday: DaySummary.fromJson(j['yesterday'] ?? {}),
        suggestion: j['suggestion'] ?? '',
      );

  double get ringPct => kcalGoal == 0 ? 0 : (kcalEaten / kcalGoal).clamp(0, 1).toDouble();
}

/// Month activity for the streak calendar.
class ActivityMonth {
  final int year, month, streak;
  final Set<String> activeDays; // "YYYY-MM-DD"
  ActivityMonth({required this.year, required this.month, required this.streak, required this.activeDays});
  factory ActivityMonth.fromJson(Map<String, dynamic> j) => ActivityMonth(
        year: j['year'] ?? 0,
        month: j['month'] ?? 0,
        streak: (j['streak']?['count']) ?? 0,
        activeDays: ((j['activeDays'] as List?) ?? []).map((e) => e.toString()).toSet(),
      );
}

/// A Thai food from search (/foods/search) with per-100g values.
class FoodSearchItem {
  final String id, nameTh, nameEn;
  final double kcal100, protein100, carbs100, fat100;
  FoodSearchItem({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.kcal100,
    required this.protein100,
    required this.carbs100,
    required this.fat100,
  });
  factory FoodSearchItem.fromJson(Map<String, dynamic> j) => FoodSearchItem(
        id: j['id'] ?? '',
        nameTh: j['nameTh'] ?? '',
        nameEn: j['nameEn'] ?? '',
        kcal100: (j['kcal100'] ?? 0).toDouble(),
        protein100: (j['protein100'] ?? 0).toDouble(),
        carbs100: (j['carbs100'] ?? 0).toDouble(),
        fat100: (j['fat100'] ?? 0).toDouble(),
      );

  /// Build a MealItem for the given grams, scaling from per-100g.
  MealItem toMealItem(double grams) {
    final f = grams / 100.0;
    return MealItem(
      thaiFoodId: id,
      name: nameTh,
      grams: grams,
      kcal: (kcal100 * f).round(),
      proteinG: double.parse((protein100 * f).toStringAsFixed(1)),
      carbsG: double.parse((carbs100 * f).toStringAsFixed(1)),
      fatG: double.parse((fat100 * f).toStringAsFixed(1)),
      source: 'thai_db',
    );
  }
}

class WeighIn {
  final String id;
  final double weightKg;
  final double? muscleKg;
  final DateTime at;
  WeighIn({required this.id, required this.weightKg, this.muscleKg, required this.at});
  factory WeighIn.fromJson(Map<String, dynamic> j) => WeighIn(
        id: j['id'] ?? '',
        weightKg: (j['weightKg'] ?? 0).toDouble(),
        muscleKg: (j['muscleKg'] as num?)?.toDouble(),
        at: DateTime.tryParse(j['at'] ?? '') ?? DateTime.now(),
      );
}

class Exercise {
  final String name, nameEn;
  final int sets, reps, secs;
  Exercise({required this.name, required this.nameEn, required this.sets, required this.reps, required this.secs});
  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        name: j['name'] ?? '',
        nameEn: j['nameEn'] ?? '',
        // AI returns numbers as doubles (schema "number") — coerce to int.
        sets: (j['sets'] as num?)?.toInt() ?? 0,
        reps: (j['reps'] as num?)?.toInt() ?? 0,
        secs: (j['secs'] as num?)?.toInt() ?? 0,
      );
  String get detail => secs > 0 ? '$sets × ${secs}s' : '$sets × $reps';
}

class WorkoutPlan {
  final String title, titleEn, focus, day;
  final int minutes, kcal;
  final List<Exercise> moves;
  WorkoutPlan({
    required this.title,
    required this.titleEn,
    required this.focus,
    required this.minutes,
    required this.kcal,
    required this.moves,
    this.day = '',
  });
  factory WorkoutPlan.fromJson(Map<String, dynamic> j) => WorkoutPlan(
        title: j['title'] ?? '',
        titleEn: j['titleEn'] ?? '',
        focus: j['focus'] ?? '',
        day: j['day'] ?? '',
        minutes: (j['minutes'] as num?)?.toInt() ?? 0,
        kcal: (j['kcal'] as num?)?.toInt() ?? 0,
        moves: (j['moves'] as List? ?? []).map((e) => Exercise.fromJson(e)).toList(),
      );
}

/// An AI-generated (or fallback) workout program.
class WorkoutProgram {
  final String source, summary, targetDate;
  final int weeksToTarget;
  final List<WorkoutPlan> workouts;
  WorkoutProgram({
    required this.source,
    required this.summary,
    required this.targetDate,
    required this.weeksToTarget,
    required this.workouts,
  });
  factory WorkoutProgram.fromJson(Map<String, dynamic> j) => WorkoutProgram(
        source: j['source'] ?? 'builtin',
        summary: j['summary'] ?? '',
        targetDate: j['targetDate'] ?? '',
        weeksToTarget: j['weeksToTarget'] ?? 0,
        workouts: (j['workouts'] as List? ?? []).map((e) => WorkoutPlan.fromJson(e)).toList(),
      );
  bool get isAI => source == 'ai';
}

/// Result of the calorie calculation returned by /profile/setup.
class CalcResult {
  final int kcal, proteinG, carbsG, fatG, bmr, tdee;
  CalcResult({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.bmr,
    required this.tdee,
  });
  factory CalcResult.fromJson(Map<String, dynamic> j) => CalcResult(
        kcal: j['dailyKcalGoal'] ?? 0,
        proteinG: j['proteinGoalG'] ?? 0,
        carbsG: j['carbsGoalG'] ?? 0,
        fatG: j['fatGoalG'] ?? 0,
        bmr: j['bmr'] ?? 0,
        tdee: j['tdee'] ?? 0,
      );
}

/// Editable draft returned by /meals/analyze.
class MealDraft {
  final String title, slot;
  final List<MealItem> items;
  MealDraft({required this.title, required this.slot, required this.items});
  factory MealDraft.fromJson(Map<String, dynamic> j) => MealDraft(
        title: j['title'] ?? '',
        slot: j['slot'] ?? 'snack',
        items: (j['items'] as List? ?? []).map((e) => MealItem.fromJson(e)).toList(),
      );
  int get totalKcal => items.fold(0, (s, i) => s + i.kcal);
}
