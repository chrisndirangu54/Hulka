import 'package:flutter_test/flutter_test.dart';
import 'package:hulka/services/nutrition_health_sync.dart';
import 'package:hulka/features/wellness/nutrition_workspace.dart';

void main() {
  test('allergy excludes condition recommendation and flags recent food', () {
    final report = NutritionHealthSync.evaluate(
      conditions: ['heart disease'],
      allergies: ['fish'],
      intelligence: NutritionWorkspace.sampleIntelligence(),
      recentFoods: ['tilapia stew'],
    );
    expect(report.avoidList, contains('tilapia'));
    expect(report.healthAlerts.any((text) => text.contains('tilapia')), isTrue);
    expect(
      report.dietaryRecommendations.any((text) => text.startsWith('Add fish')),
      isFalse,
    );
  });
  test('kidney condition suppresses conflicting pantry suggestions', () {
    final report = NutritionHealthSync.evaluate(
      conditions: ['hypertension', 'kidney disease'],
      allergies: [],
      intelligence: NutritionWorkspace.sampleIntelligence(),
    );
    expect(
      report.dietaryRecommendations.any(
        (text) => text.startsWith('Add banana'),
      ),
      isFalse,
    );
  });
}
