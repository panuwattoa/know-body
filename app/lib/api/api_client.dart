import 'dart:convert';
import 'package:dio/dio.dart';

import 'models.dart';

/// Thin client over the KnowBody Go API.
///
/// Auth: in production, inject the Supabase access token via [tokenProvider].
/// For local dev the API accepts `Bearer dev:<uuid>` when AUTH_DEV_BYPASS=1.
class ApiClient {
  ApiClient({required String baseUrl, required this.tokenProvider})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 70),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
      o.headers['Authorization'] = 'Bearer ${await tokenProvider()}';
      h.next(o);
    }));
  }

  final Dio _dio;
  final Future<String> Function() tokenProvider;

  Future<Home> home() async {
    final r = await _dio.get('/v1/home');
    return Home.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Profile> updateProfile({
    required String goal,
    required String locale,
    required int kcal,
    int protein = 120,
    int carbs = 220,
    int fat = 60,
  }) async {
    final r = await _dio.put('/v1/profile', data: {
      'goal': goal,
      'locale': locale,
      'dailyKcalGoal': kcal,
      'proteinGoalG': protein,
      'carbsGoalG': carbs,
      'fatGoalG': fat,
    });
    return Profile.fromJson(r.data as Map<String, dynamic>);
  }

  /// Save body metrics + goal; server computes and returns the calorie/macro target.
  Future<CalcResult> setupProfile({
    required String goal,
    required String locale,
    required String sex,
    required int age,
    required double heightCm,
    required double weightKg,
    required String activity,
    required String goalDir,
    String targetDate = '',
  }) async {
    final r = await _dio.post('/v1/profile/setup', data: {
      'goal': goal,
      'locale': locale,
      'sex': sex,
      'age': age,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'activity': activity,
      'goalDir': goalDir,
      'targetDate': targetDate,
    });
    return CalcResult.fromJson((r.data as Map<String, dynamic>)['calc']);
  }

  Future<List<FoodSearchItem>> searchFoods(String q) async {
    final r = await _dio.get('/v1/foods/search', queryParameters: {'q': q});
    return ((r.data as Map<String, dynamic>)['foods'] as List).map((e) => FoodSearchItem.fromJson(e)).toList();
  }

  Future<void> deleteMeal(String id) => _dio.delete('/v1/meals/$id');

  Future<void> updateMeal(String id, MealDraft draft) async {
    await _dio.put('/v1/meals/$id', data: {
      'slot': draft.slot,
      'title': draft.title,
      'items': draft.items.map((i) => i.toJson()).toList(),
    });
  }

  List<WeighIn> _weights(dynamic data) =>
      ((data as Map<String, dynamic>)['weights'] as List).map((e) => WeighIn.fromJson(e)).toList();

  Future<List<WeighIn>> addWeight(double kg, {double? muscleKg}) async {
    final r = await _dio.post('/v1/weight', data: {'weightKg': kg, if (muscleKg != null) 'muscleKg': muscleKg});
    return _weights(r.data);
  }

  Future<List<WeighIn>> updateWeight(String id, double kg, {double? muscleKg}) async {
    final r = await _dio.put('/v1/weight/$id', data: {'weightKg': kg, if (muscleKg != null) 'muscleKg': muscleKg});
    return _weights(r.data);
  }

  Future<List<WeighIn>> deleteWeight(String id) async {
    final r = await _dio.delete('/v1/weight/$id');
    return _weights(r.data);
  }

  Future<List<WeighIn>> listWeights() async {
    final r = await _dio.get('/v1/weight');
    return _weights(r.data);
  }

  Future<ActivityMonth> activity({int ym = 0}) async {
    final r = await _dio.get('/v1/activity', queryParameters: {if (ym > 0) 'ym': ym});
    return ActivityMonth.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<WorkoutPlan>> workoutPlan({String goalDir = ''}) async {
    final r = await _dio.get('/v1/workouts/plan', queryParameters: {if (goalDir.isNotEmpty) 'goalDir': goalDir});
    return ((r.data as Map<String, dynamic>)['workouts'] as List).map((e) => WorkoutPlan.fromJson(e)).toList();
  }

  /// AI-personalized program. Pass regenerate:true to force a fresh generation.
  Future<WorkoutProgram> workoutProgram({bool regenerate = false}) async {
    final r = regenerate
        ? await _dio.post('/v1/workouts/program')
        : await _dio.get('/v1/workouts/program');
    return WorkoutProgram.fromJson(r.data as Map<String, dynamic>);
  }

  /// Analyze a meal photo. Throws [FreeLimitReached] on the free-tier cap (HTTP 402).
  Future<MealDraft> analyzeMeal(List<int> jpegBytes) async {
    try {
      final r = await _dio.post('/v1/meals/analyze',
          data: {'imageBase64': base64Encode(jpegBytes)});
      return MealDraft.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        final d = e.response?.data as Map<String, dynamic>? ?? {};
        throw FreeLimitReached(limit: d['limit'] ?? 3, used: d['used'] ?? 0);
      }
      rethrow;
    }
  }

  Future<Meal> saveMeal(MealDraft draft) async {
    final r = await _dio.post('/v1/meals', data: {
      'slot': draft.slot,
      'title': draft.title,
      'items': draft.items.map((i) => i.toJson()).toList(),
    });
    return Meal.fromJson((r.data as Map<String, dynamic>)['meal']);
  }

  Future<Pet> renamePet(String name) async {
    final r = await _dio.put('/v1/pet', data: {'name': name});
    return Pet.fromJson(r.data as Map<String, dynamic>);
  }

  Future<String> createWorkout(String title) async {
    final r = await _dio.post('/v1/workouts', data: {'title': title});
    return (r.data as Map<String, dynamic>)['id'];
  }

  /// Completes a workout; returns the reward payload {xpGained, pet, levelsGained, streak}.
  Future<Map<String, dynamic>> completeWorkout(String id,
      {int kcalBurned = 0, int durationS = 0, bool partial = false}) async {
    final r = await _dio.post('/v1/workouts/$id/complete',
        data: {'kcalBurned': kcalBurned, 'durationS': durationS, 'partial': partial});
    return r.data as Map<String, dynamic>;
  }

  /// One-tap: create a quick workout and immediately complete it.
  Future<Map<String, dynamic>> quickWorkout(String title, {required int kcalBurned, required int durationS}) async {
    final id = await createWorkout(title);
    return completeWorkout(id, kcalBurned: kcalBurned, durationS: durationS);
  }
}

class FreeLimitReached implements Exception {
  final int limit, used;
  FreeLimitReached({required this.limit, required this.used});
}
