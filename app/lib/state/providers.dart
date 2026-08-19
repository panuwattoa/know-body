import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth.dart';

/// Base URL of the Go API. Override at build time:
///   flutter run --dart-define=API_BASE_URL=https://api.knowbody.app
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: _apiBaseUrl,
    // Real Supabase JWT when configured, else the dev-token bypass.
    tokenProvider: Auth.token,
  );
});

/// App locale (Thai default), toggled from settings.
final localeProvider = StateProvider<Locale>((ref) => const Locale('th'));

/// Home screen data.
final homeProvider = FutureProvider.autoDispose<Home>((ref) async {
  return ref.watch(apiClientProvider).home();
});

/// Carried between onboarding steps.
final onboardingGoalProvider = StateProvider<String>((ref) => 'eat_better');
final lastCalcProvider = StateProvider<CalcResult?>((ref) => null);

/// Weight trend for the Trend tab.
final weightsProvider = FutureProvider.autoDispose<List<WeighIn>>((ref) async {
  return ref.watch(apiClientProvider).listWeights();
});

/// Suggested workout plan for the Move tab.
final workoutPlanProvider = FutureProvider.autoDispose<List<WorkoutPlan>>((ref) async {
  return ref.watch(apiClientProvider).workoutPlan();
});

/// AI-personalized workout program for the Move tab.
final workoutProgramProvider = FutureProvider.autoDispose<WorkoutProgram>((ref) async {
  return ref.watch(apiClientProvider).workoutProgram();
});

/// Month activity for the streak calendar (defaults to current month).
final activityProvider = FutureProvider.autoDispose.family<ActivityMonth, int>((ref, ym) async {
  return ref.watch(apiClientProvider).activity(ym: ym);
});
