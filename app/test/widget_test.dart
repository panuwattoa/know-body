import 'package:flutter_test/flutter_test.dart';

import 'package:knowbody/api/models.dart';

void main() {
  test('Home.ringPct is fraction of goal eaten, clamped 0..1', () {
    final home = Home.fromJson({
      'profile': {'dailyKcalGoal': 2000},
      'kcalGoal': 2000,
      'kcalEaten': 1000,
      'kcalLeft': 1000,
      'pet': {'name': 'Mochi', 'level': 1, 'xp': 0, 'xpMax': 100},
      'streak': {'count': 0, 'freezesLeft': 2},
      'tier': 'free',
    });
    expect(home.ringPct, 0.5);
    expect(home.pet.xpPct, 0.0);
  });
}
