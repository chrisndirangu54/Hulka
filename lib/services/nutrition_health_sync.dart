import 'package:cloud_firestore/cloud_firestore.dart';

import 'sokonis_client.dart';

/// Bridges the user's Hulka health profile with Sokonis eating data to
/// produce personalised nutrition guidance.
class NutritionHealthSync {
  const NutritionHealthSync(this.sokonisClient);
  final SokonisClient sokonisClient;

  // ---------------------------------------------------------------------------
  // Condition → alert rules
  // ---------------------------------------------------------------------------

  static const Map<String, String> _conditionAlerts = {
    'diabetes':
        'Diabetic: monitor carbohydrate intake, prefer low-GI foods like beans, sweet potato',
    'type 2 diabetes':
        'Diabetic: monitor carbohydrate intake, prefer low-GI foods like beans, sweet potato',
    'hypertension':
        'Hypertension: limit sodium/salt, eat more potassium-rich foods like bananas, avocado',
    'high blood pressure':
        'Hypertension: limit sodium/salt, eat more potassium-rich foods like bananas, avocado',
    'anaemia':
        'Anaemia: increase iron-rich foods like ndengu, meat, leafy greens with vitamin C',
    'anemia':
        'Anaemia: increase iron-rich foods like ndengu, meat, leafy greens with vitamin C',
    'kidney disease':
        'Kidney disease: limit phosphorus and potassium — consult a dietitian',
    'heart disease':
        'Heart: reduce saturated fats, increase omega-3s (fish), fibre',
    'celiac': 'Gluten-free: avoid wheat, barley, rye. Ugali (maize) is safe.',
    'gluten intolerance':
        'Gluten-free: avoid wheat, barley, rye. Ugali (maize) is safe.',
  };

  // Foods to avoid for common allergy keywords
  static const Map<String, List<String>> _allergyAvoids = {
    'peanut': ['peanuts', 'groundnuts'],
    'peanuts': ['peanuts', 'groundnuts'],
    'groundnut': ['peanuts', 'groundnuts'],
    'nut': ['tree nuts', 'almonds', 'cashews', 'walnuts'],
    'tree nut': ['tree nuts', 'almonds', 'cashews', 'walnuts'],
    'dairy': ['milk', 'cheese', 'yoghurt', 'butter', 'cream'],
    'milk': ['milk', 'cheese', 'yoghurt', 'butter', 'cream'],
    'lactose': ['milk', 'cheese', 'yoghurt', 'butter', 'cream'],
    'egg': ['eggs', 'mayonnaise'],
    'eggs': ['eggs', 'mayonnaise'],
    'gluten': ['wheat', 'barley', 'rye', 'wheat flour'],
    'wheat': ['wheat', 'wheat flour', 'bread', 'pasta'],
    'soy': ['soy', 'soya', 'tofu', 'soy sauce'],
    'soya': ['soy', 'soya', 'tofu', 'soy sauce'],
    'fish': ['fish', 'tilapia', 'sardines', 'omena'],
    'shellfish': ['shellfish', 'shrimp', 'prawns', 'crab', 'lobster'],
    'sesame': ['sesame', 'sesame oil', 'tahini'],
  };

  // Condition-specific pantry suggestions
  static const Map<String, List<String>> _conditionSuggestions = {
    'diabetes': ['ndengu', 'beans', 'sweet potato', 'oats', 'leafy greens'],
    'type 2 diabetes': [
      'ndengu',
      'beans',
      'sweet potato',
      'oats',
      'leafy greens',
    ],
    'hypertension': ['banana', 'avocado', 'spinach', 'garlic', 'oats'],
    'high blood pressure': ['banana', 'avocado', 'spinach', 'garlic', 'oats'],
    'anaemia': ['ndengu', 'spinach', 'sukuma wiki', 'meat', 'oranges'],
    'anemia': ['ndengu', 'spinach', 'sukuma wiki', 'meat', 'oranges'],
    'kidney disease': ['cabbage', 'cauliflower', 'apple', 'white rice'],
    'heart disease': ['fish', 'oats', 'avocado', 'sukuma wiki', 'olive oil'],
    'celiac': ['ugali', 'rice', 'sweet potato', 'cassava', 'millet'],
    'gluten intolerance': [
      'ugali',
      'rice',
      'sweet potato',
      'cassava',
      'millet',
    ],
  };

  // ---------------------------------------------------------------------------

  /// Loads Hulka health profile + Sokonis intelligence and merges them into
  /// personalised [NutritionSyncReport].
  Future<NutritionSyncReport> sync(
    String uid, {
    List<String> recentFoods = const [],
  }) async {
    // 1. Load health profile
    final doc = await FirebaseFirestore.instance
        .collection('patients')
        .doc(uid)
        .get();
    final data = doc.data() ?? const <String, dynamic>{};

    final conditions = _asList(data['conditions']);
    final allergies = _asList(data['allergies']);

    // 2. Pull Sokonis intelligence
    final intelligence = await sokonisClient.loadIntelligence(
      recentFoods: recentFoods,
    );

    return evaluate(
      conditions: conditions,
      allergies: allergies,
      intelligence: intelligence,
      recentFoods: recentFoods,
    );
  }

  static NutritionSyncReport evaluate({
    required List<String> conditions,
    required List<String> allergies,
    required SokonisIntelligence intelligence,
    List<String> recentFoods = const [],
  }) {
    // 3. Build health alerts
    final healthAlerts = <String>[];
    for (final condition in conditions) {
      final key = condition.toLowerCase().trim();
      if (conditions.any((c) => c.toLowerCase().contains('kidney')) &&
          ['hypertension', 'high blood pressure'].contains(key)) {
        continue;
      }
      final alert = _conditionAlerts[key];
      if (alert != null && !healthAlerts.contains(alert)) {
        healthAlerts.add(alert);
      }
    }

    // 4. Build avoid list from allergies
    final avoidSet = <String>{};
    for (final allergy in allergies) {
      final key = allergy.toLowerCase().trim();
      // Try exact match first, then partial
      final matched = _allergyAvoids[key];
      if (matched != null) {
        avoidSet.addAll(matched);
      } else {
        // Partial keyword scan
        for (final entry in _allergyAvoids.entries) {
          if (key.contains(entry.key)) {
            avoidSet.addAll(entry.value);
          }
        }
        // Fall back to the allergy name itself
        if (avoidSet.isEmpty ||
            !_allergyAvoids.keys.any((k) => key.contains(k))) {
          avoidSet.add(allergy.trim());
        }
      }
    }
    if (conditions.any(
      (condition) => [
        'celiac',
        'gluten intolerance',
      ].contains(condition.toLowerCase().trim()),
    )) {
      avoidSet.addAll(_allergyAvoids['gluten']!);
    }
    final avoidList = avoidSet.toList();

    // 5. Build dietary recommendations by cross-referencing pantry vs conditions
    final pantryNames = intelligence.pantry
        .map((p) => p.name.toLowerCase())
        .toSet();
    final recommendations = <String>[];

    for (final condition in conditions) {
      final key = condition.toLowerCase().trim();
      final suggested = _conditionSuggestions[key] ?? [];
      for (final item in suggested) {
        if (avoidList.any(
          (avoid) => item.contains(avoid) || avoid.contains(item),
        )) {
          continue;
        }
        if (conditions.any((c) => c.toLowerCase().contains('kidney')) &&
            key != 'kidney disease') {
          continue;
        }
        final alreadyHave = pantryNames.any(
          (p) => p.contains(item) || item.contains(p),
        );
        if (!alreadyHave) {
          final rec =
              'Add $item to your pantry — beneficial for ${_friendlyCondition(condition)}';
          if (!recommendations.contains(rec)) recommendations.add(rec);
        }
      }
    }

    if (recommendations.isEmpty && healthAlerts.isEmpty) {
      recommendations.add(
        'No condition-specific recommendations are available for this profile.',
      );
    }

    final observedFoods = [
      ...pantryNames,
      ...recentFoods.map((food) => food.toLowerCase()),
    ];
    for (final avoid in avoidList) {
      if (observedFoods.any((food) => food.contains(avoid.toLowerCase()))) {
        healthAlerts.add(
          'Your pantry or recent meals include $avoid, which is on your avoid list.',
        );
      }
    }

    // 6. Add disclaimer
    recommendations.add('AI-generated wellness estimate — not medical advice.');

    return NutritionSyncReport(
      intelligence: intelligence,
      healthAlerts: healthAlerts,
      dietaryRecommendations: recommendations,
      avoidList: avoidList,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static List<String> _asList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String && value.trim().isNotEmpty) return [value];
    return const [];
  }

  static String _friendlyCondition(String condition) {
    final c = condition.trim().toLowerCase();
    if (c.contains('diabetes')) return 'blood sugar management';
    if (c.contains('hypertension') || c.contains('blood pressure')) {
      return 'blood pressure';
    }
    if (c.contains('anaemia') || c.contains('anemia')) return 'iron levels';
    if (c.contains('kidney')) return 'kidney health';
    if (c.contains('heart')) return 'heart health';
    if (c.contains('celiac') || c.contains('gluten')) return 'gluten-free diet';
    return condition;
  }
}

// ---------------------------------------------------------------------------
// Report model
// ---------------------------------------------------------------------------

class NutritionSyncReport {
  const NutritionSyncReport({
    required this.intelligence,
    required this.healthAlerts,
    required this.dietaryRecommendations,
    required this.avoidList,
  });

  final SokonisIntelligence intelligence;

  /// Alerts derived from health profile (e.g., "Diabetic: watch carb load").
  final List<String> healthAlerts;

  /// Personalised recommendations based on conditions + pantry.
  final List<String> dietaryRecommendations;

  /// Foods/ingredients to avoid based on allergies/conditions.
  final List<String> avoidList;
}
