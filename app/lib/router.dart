import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'api/models.dart';
import 'auth/auth.dart';
import 'features/auth/login_screen.dart';
import 'features/food/add_meal_screen.dart';
import 'features/food/food_screen.dart';
import 'features/home/home_screen.dart';
import 'features/move/custom_workout_screen.dart';
import 'features/move/move_screen.dart';
import 'features/move/workout_runner_screen.dart';
import 'features/onboarding/body_metrics_screen.dart';
import 'features/onboarding/calorie_result_screen.dart';
import 'features/onboarding/name_pet_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/pet/pet_screen.dart';
import 'features/share/share_screen.dart';
import 'features/shell/tab_scaffold.dart';
import 'features/streaks/streaks_screen.dart';
import 'features/trend/trend_screen.dart';

/// App navigation. Onboarding flow (goal → metrics → calorie result → name pet)
/// then the main 5-tab shell. Add-meal is a full-screen route above the shell.
final router = GoRouter(
  initialLocation: AuthConfig.enabled ? '/login' : '/onboarding',
  // Re-run redirect when the Supabase auth state changes.
  refreshListenable: AuthConfig.enabled ? _AuthRefresh() : null,
  redirect: (context, state) {
    if (!AuthConfig.enabled) return null; // dev mode: no auth gate
    final loggedIn = Auth.isSignedIn;
    final atLogin = state.matchedLocation == '/login';
    if (!loggedIn) return atLogin ? null : '/login';
    if (atLogin) return '/onboarding';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/setup', builder: (_, __) => const BodyMetricsScreen()),
    GoRoute(path: '/calorie-result', builder: (_, __) => const CalorieResultScreen()),
    GoRoute(path: '/name-pet', builder: (_, __) => const NamePetScreen()),
    GoRoute(path: '/add-meal', builder: (_, __) => const AddMealScreen()),
    GoRoute(path: '/edit-meal', builder: (_, st) => AddMealScreen(editMeal: st.extra as Meal?)),
    GoRoute(path: '/custom-workout', builder: (_, __) => const CustomWorkoutScreen()),
    GoRoute(path: '/workout', builder: (_, st) => WorkoutRunnerScreen(workout: st.extra as WorkoutPlan)),
    GoRoute(path: '/streaks', builder: (_, __) => const StreaksScreen()),
    GoRoute(path: '/share', builder: (_, __) => const ShareScreen()),
    StatefulShellRoute.indexedStack(
      builder: (_, __, shell) => TabScaffold(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/food', builder: (_, __) => const FoodScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/move', builder: (_, __) => const MoveScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/trend', builder: (_, __) => const TrendScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/mochi', builder: (_, __) => const PetScreen())]),
      ],
    ),
  ],
);

/// Bridges the Supabase auth stream to a Listenable for GoRouter refresh.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    _sub = Auth.onChange.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
