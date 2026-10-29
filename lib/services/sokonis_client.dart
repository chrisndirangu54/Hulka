import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'sokonis_options.dart';

const sokonisDisclaimer =
    'AI-generated wellness estimate from dietary patterns — not a medical diagnosis, treatment, or prediction.';

class SokonisProduct {
  const SokonisProduct({
    required this.id,
    required this.name,
    this.price,
    this.pictureUrl,
    this.hasHealthBenefits = false,
    this.calories,
    this.nutritionNote,
  });

  final String id;
  final String name;
  final num? price;
  final String? pictureUrl;
  final bool hasHealthBenefits;
  final int? calories;
  final String? nutritionNote;
}

class SokonisMeal {
  const SokonisMeal({required this.name, required this.uses});
  final String name;
  final List<String> uses;
}

class SokonisNutritionReport {
  const SokonisNutritionReport({
    required this.foods,
    required this.matches,
    required this.notes,
    this.calories,
  });

  final List<String> foods;
  final List<SokonisProduct> matches;
  final List<String> notes;
  final int? calories;
}

class SokonisIntelligence {
  const SokonisIntelligence({
    required this.mcpReachable,
    required this.source,
    this.overall,
    this.level = 1,
    this.xp = 0,
    this.coins = 0,
    this.bodyStory,
    this.systems = const {},
    this.pantry = const [],
    this.meals = const [],
    this.analysis,
    this.disclaimer = sokonisDisclaimer,
  });

  final bool mcpReachable;
  final String source;
  final num? overall;
  final int level;
  final int xp;
  final int coins;
  final String? bodyStory;
  final Map<String, num> systems;
  final List<SokonisProduct> pantry;
  final List<SokonisMeal> meals;
  final SokonisNutritionReport? analysis;
  final String disclaimer;
}

class SokonisClient {
  SokonisClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  static const appName = 'sokonis';
  final http.Client _http;
  FirebaseApp? _app;

  Future<FirebaseApp> ensureApp() async {
    if (_app != null) return _app!;
    try {
      _app = Firebase.app(appName);
    } catch (_) {
      _app = await Firebase.initializeApp(
        name: appName,
        options: SokonisFirebaseOptions.currentPlatform,
      );
    }
    return _app!;
  }

  FirebaseAuth get auth => FirebaseAuth.instanceFor(app: _app!);
  FirebaseFirestore get db => FirebaseFirestore.instanceFor(app: _app!);

  User? get user => _app == null ? null : FirebaseAuth.instanceFor(app: _app!).currentUser;

  Future<UserCredential> linkAccount(String email, String password) async {
    await ensureApp();
    return auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> unlink() async {
    if (_app == null) return;
    await auth.signOut();
  }

  Future<bool> pingMcp() async {
    try {
      final r = await _http.get(Uri.parse(SokonisFirebaseOptions.mcpUrl)).timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> mcpCall(String name, Map<String, dynamic> args) async {
    final token = await user?.getIdToken();
    try {
      final r = await _http
          .post(
            Uri.parse(SokonisFirebaseOptions.mcpUrl),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'method': 'tools/call',
              'params': {'name': name, 'arguments': args},
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final body = jsonDecode(r.body);
      if (body is Map && body['result'] is Map) {
        final result = body['result'] as Map;
        if (result['structuredContent'] is Map) {
          return Map<String, dynamic>.from(result['structuredContent'] as Map);
        }
        final content = result['content'];
        if (content is List && content.isNotEmpty && content.first is Map) {
          final text = (content.first as Map)['text'];
          if (text is String) {
            final parsed = jsonDecode(text);
            if (parsed is Map) return Map<String, dynamic>.from(parsed);
          }
        }
      }
    } catch (e) {
      debugPrint('Sokonis MCP $name: $e');
    }
    return null;
  }

  Future<List<SokonisProduct>?> mcpSearch(String q) async {
    final r = await mcpCall('search_products', {'q': q, 'limit': 12});
    final products = r?['products'];
    if (products is! List) return null;
    return products.whereType<Map>().map(_productFromMap).toList();
  }

  SokonisProduct _productFromMap(Map raw) {
    final m = Map<String, dynamic>.from(raw);
    final info = m['nutritionInfo'] is Map ? Map<String, dynamic>.from(m['nutritionInfo'] as Map) : null;
    return SokonisProduct(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? 'Item').toString(),
      price: m['basePrice'] as num?,
      pictureUrl: m['pictureUrl'] as String?,
      hasHealthBenefits: m['hasHealthBenefits'] == true,
      calories: (info?['caloriesPerServing'] as num?)?.toInt(),
      nutritionNote: info?['servingSize'] as String?,
    );
  }

  SokonisProduct _productFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    m['id'] = doc.id;
    return _productFromMap(m);
  }

  Future<List<SokonisProduct>> searchProducts(String q, {int limit = 12}) async {
    final needle = q.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final mcp = await mcpSearch(needle);
    if (mcp != null) return mcp;

    await ensureApp();
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await db.collection('products').where('isAvailable', isEqualTo: true).limit(120).get();
    } catch (_) {
      snap = await db.collection('products').limit(80).get();
    }
    final hits = <SokonisProduct>[];
    for (final doc in snap.docs) {
      final name = (doc.data()['name'] ?? '').toString().toLowerCase();
      final tags = (doc.data()['tags'] as List?)?.map((t) => t.toString().toLowerCase()).join(' ') ?? '';
      if (name.contains(needle) || tags.contains(needle)) {
        hits.add(_productFromDoc(doc));
      }
      if (hits.length >= limit) break;
    }
    return hits;
  }

  Future<SokonisNutritionReport> analyzeFoods(List<String> foods) async {
    final cleaned = foods.map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
    final mcp = await mcpCall('nutrition_analysis', {'foods': cleaned});
    final matches = <SokonisProduct>[];
    var calories = 0;
    for (final food in cleaned.take(8)) {
      final found = await searchProducts(food, limit: 2);
      matches.addAll(found);
      for (final p in found) {
        calories += p.calories ?? 0;
      }
    }
    final notes = <String>[
      if (mcp?['note'] is String) mcp!['note'] as String,
      if (matches.isEmpty) 'No Sokonis catalog match yet — log the meal and link groceries when they appear on the shelf.',
      if (matches.any((m) => m.hasHealthBenefits)) 'Some matched items are tagged with health benefits in the Sokonis catalog.',
      sokonisDisclaimer,
    ];
    return SokonisNutritionReport(
      foods: cleaned,
      matches: matches,
      notes: notes.where((n) => n.trim().isNotEmpty).toList(),
      calories: calories == 0 ? null : calories,
    );
  }

  Future<List<SokonisMeal>> recommendMeals(List<String> preferences) async {
    final mcp = await mcpCall('recommend_meals', {'preferences': preferences});
    final meals = mcp?['meals'];
    if (meals is List && meals.isNotEmpty) {
      return meals.whereType<Map>().map((m) {
        final uses = (m['uses'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
        return SokonisMeal(name: (m['name'] ?? 'Meal').toString(), uses: uses);
      }).toList();
    }
    return const [
      SokonisMeal(name: 'Veggie omelette', uses: ['eggs', 'spinach', 'tomato']),
      SokonisMeal(name: 'Bean stew + rice', uses: ['beans', 'rice', 'onion']),
      SokonisMeal(name: 'Grilled fish + greens', uses: ['fish', 'sukuma', 'lemon']),
    ];
  }

  Future<String> addToCart(List<String> items) async {
    final uid = user?.uid;
    if (uid == null) throw StateError('Link a Sokonis account first.');
    final mcp = await mcpCall('add_to_cart', {'items': items, 'uid': uid});
    if (mcp?['intentId'] != null) return mcp!['intentId'].toString();
    final ref = await db.collection('users').doc(uid).collection('voiceIntents').add({
      'items': items,
      'source': 'hulka',
      'fulfilled': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<SokonisIntelligence> loadIntelligence({List<String> recentFoods = const []}) async {
    final uid = user?.uid;
    if (uid == null) {
      throw StateError('Link a Sokonis account first.');
    }
    final mcpUp = await pingMcp();
    final Map<String, dynamic>? score = mcpUp ? await mcpCall('health_score', {'uid': uid}) : null;
    final Map<String, dynamic>? profile = mcpUp ? await mcpCall('body_profile', {'uid': uid}) : null;
    final Map<String, dynamic>? pantryMcp = mcpUp ? await mcpCall('pantry_inventory', {'uid': uid}) : null;

    DocumentSnapshot<Map<String, dynamic>>? wellnessDoc;
    if (score == null || profile == null) {
      wellnessDoc = await db.collection('users').doc(uid).collection('wellness').doc('profile').get();
    }
    final wellness = wellnessDoc?.data() ?? const <String, dynamic>{};
    final lastScore = (profile?['profile'] is Map)
        ? Map<String, dynamic>.from(profile!['profile'] as Map)
        : (wellness['lastScore'] is Map ? Map<String, dynamic>.from(wellness['lastScore'] as Map) : const <String, dynamic>{});

    final systems = <String, num>{};
    final rawSystems = lastScore['systems'];
    if (rawSystems is Map) {
      for (final e in rawSystems.entries) {
        final v = e.value;
        if (v is num) {
          systems[e.key.toString()] = v;
        } else if (v is Map && v['score'] is num) {
          systems[e.key.toString()] = v['score'] as num;
        }
      }
    }

    final pantry = <SokonisProduct>[];
    if (pantryMcp?['items'] is List) {
      for (final item in pantryMcp!['items'] as List) {
        if (item is Map) {
          pantry.add(SokonisProduct(
            id: (item['id'] ?? '').toString(),
            name: (item['name'] ?? item['productName'] ?? 'Pantry item').toString(),
          ));
        }
      }
    } else {
      final snap = await db.collection('users').doc(uid).collection('pantry').limit(40).get();
      for (final doc in snap.docs) {
        pantry.add(SokonisProduct(
          id: doc.id,
          name: (doc.data()['name'] ?? doc.data()['productName'] ?? 'Pantry item').toString(),
        ));
      }
    }

    final prefs = [
      ...pantry.map((p) => p.name),
      ...recentFoods,
    ].take(8).toList();
    final meals = await recommendMeals(prefs);
    final analysis = recentFoods.isEmpty ? null : await analyzeFoods(recentFoods);

    return SokonisIntelligence(
      mcpReachable: mcpUp,
      source: mcpUp ? 'Sokonis MCP' : 'Sokonis account (Firestore)',
      overall: (score?['overall'] ?? lastScore['overall']) as num?,
      level: (score?['level'] as num?)?.toInt() ?? (wellness['level'] as num?)?.toInt() ?? 1,
      xp: (score?['xp'] as num?)?.toInt() ?? (wellness['xp'] as num?)?.toInt() ?? 0,
      coins: (wellness['wellnessCoins'] as num?)?.toInt() ?? 0,
      bodyStory: lastScore['bodyStory'] as String?,
      systems: systems,
      pantry: pantry,
      meals: meals,
      analysis: analysis,
      disclaimer: (score?['disclaimer'] ?? profile?['disclaimer'] ?? sokonisDisclaimer).toString(),
    );
  }
}
