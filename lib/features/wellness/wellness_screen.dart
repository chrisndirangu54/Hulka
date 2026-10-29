import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/sokonis_client.dart';
import '../../ui/hulka_look.dart';
import 'nutrition_workspace.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key, this.client});

  final SokonisClient? client;

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  late final SokonisClient _client;
  final email = TextEditingController();
  final password = TextEditingController();
  final search = TextEditingController();
  final note = TextEditingController();
  final value = TextEditingController();
  final unit = TextEditingController();

  String type = 'meal';
  bool restoring = true;
  bool linking = false;
  bool loading = false;
  bool saving = false;
  bool analyzing = false;
  bool cartBusy = false;
  String? linkedEmail;
  String? error;
  String? message;
  SokonisIntelligence? intelligence;
  List<SokonisProduct> products = const [];

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? SokonisClient();
    _restore();
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    search.dispose();
    note.dispose();
    value.dispose();
    unit.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      await _client.ensureApp();
      if (_client.user != null) {
        linkedEmail = _client.user!.email;
        await _loadIntelligence();
        return;
      }
      final hulka = FirebaseAuth.instance.currentUser;
      if (hulka != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(hulka.uid)
            .get();
        final link = doc.data()?['sokonisLink'];
        if (link is Map && link['email'] is String) {
          email.text = link['email'] as String;
        }
      }
    } catch (e) {
      error = 'Could not reach Sokonis: $e';
    } finally {
      if (mounted) setState(() => restoring = false);
    }
  }

  Future<void> _persistLink({required bool linked}) async {
    final hulka = FirebaseAuth.instance.currentUser;
    if (hulka == null) return;
    try {
      if (linked) {
        final soko = _client.user;
        if (soko == null) return;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(hulka.uid)
            .update({
              'sokonisLink': {
                'uid': soko.uid,
                'email': soko.email,
                'linkedAt': FieldValue.serverTimestamp(),
              },
            });
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(hulka.uid)
            .update({'sokonisLink': FieldValue.delete()});
      }
    } catch (e) {
      debugPrint('sokonisLink persist: $e');
    }
  }

  Future<void> _link() async {
    setState(() {
      linking = true;
      error = null;
      message = null;
    });
    try {
      await _client.linkAccount(email.text, password.text);
      password.clear();
      linkedEmail = _client.user?.email ?? email.text.trim();
      await _persistLink(linked: true);
      await _loadIntelligence();
      if (mounted) setState(() => message = 'Sokonis linked as $linkedEmail.');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not link Sokonis: $e');
    } finally {
      if (mounted) setState(() => linking = false);
    }
  }

  Future<void> _unlink() async {
    await _client.unlink();
    await _persistLink(linked: false);
    if (!mounted) return;
    setState(() {
      linkedEmail = null;
      intelligence = null;
      products = const [];
      message = 'Sokonis unlinked on this device.';
    });
  }

  Future<void> _loadIntelligence() async {
    if (_client.user == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final recent = note.text
          .split(RegExp(r'[,;\n]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final intel = await _client.loadIntelligence(recentFoods: recent);
      if (mounted) setState(() => intelligence = intel);
    } catch (e) {
      if (mounted) setState(() => error = 'Intelligence failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _search() async {
    final q = search.text.trim();
    if (q.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final hits = await _client.searchProducts(q);
      if (mounted) setState(() => products = hits);
    } catch (e) {
      if (mounted) setState(() => error = 'Search failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _analyze() async {
    final foods = note.text
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (foods.isEmpty) {
      setState(() => error = 'List the foods first, separated by commas.');
      return;
    }
    setState(() {
      analyzing = true;
      error = null;
    });
    try {
      final report = await _client.analyzeFoods(foods);
      if (!mounted) return;
      setState(() {
        intelligence = SokonisIntelligence(
          mcpReachable: intelligence?.mcpReachable ?? false,
          source: intelligence?.source ?? 'Sokonis',
          overall: intelligence?.overall,
          level: intelligence?.level ?? 1,
          xp: intelligence?.xp ?? 0,
          coins: intelligence?.coins ?? 0,
          bodyStory: intelligence?.bodyStory,
          systems: intelligence?.systems ?? const {},
          pantry: intelligence?.pantry ?? const [],
          meals: intelligence?.meals ?? const [],
          analysis: report,
        );
      });
    } catch (e) {
      if (mounted) setState(() => error = 'Analysis failed: $e');
    } finally {
      if (mounted) setState(() => analyzing = false);
    }
  }

  Future<void> _addToCart(List<String> items) async {
    setState(() {
      cartBusy = true;
      error = null;
      message = null;
    });
    try {
      final id = await _client.addToCart(items);
      if (mounted) setState(() => message = 'Sent to Sokonis cart ($id).');
    } catch (e) {
      if (mounted) setState(() => error = 'Cart failed: $e');
    } finally {
      if (mounted) setState(() => cartBusy = false);
    }
  }

  Future<void> _addEntry() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final parsed = value.text.trim().isEmpty
        ? null
        : num.tryParse(value.text.trim());
    if (value.text.trim().isNotEmpty && parsed == null) {
      setState(() => error = 'Value must be numeric when provided.');
      return;
    }

    setState(() {
      saving = true;
      error = null;
      message = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(uid)
          .collection('wellnessEntries')
          .add({
            'patientId': uid,
            'type': type,
            'note': note.text.trim(),
            'value': parsed,
            'unit': unit.text.trim().isEmpty ? null : unit.text.trim(),
            'recordedAt': FieldValue.serverTimestamp(),
            'provenance': 'patientReported',
            'synthetic': false,
            if (linkedEmail != null) 'sokonisEmail': linkedEmail,
          });
      if (type == 'meal' &&
          linkedEmail != null &&
          note.text.trim().isNotEmpty) {
        await _analyze();
      }
      value.clear();
      unit.clear();
      if (mounted) setState(() => message = 'Entry added.');
    } catch (e) {
      if (mounted) setState(() => error = 'Could not add entry: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null && !kDebugMode) {
      return const Center(child: Text('Authentication required.'));
    }

    final stream = uid == null
        ? null
        : FirebaseFirestore.instance
              .collection('patients')
              .doc(uid)
              .collection('wellnessEntries')
              .orderBy('recordedAt', descending: true)
              .limit(50)
              .snapshots();

    Widget body(List<NutritionLogRow> rows) {
      return NutritionWorkspace(
        healthSyncCard: uid == null
            ? null
            : NutritionHealthSyncCard(
                sokonisClient: _client,
                uid: uid,
                recentFoods: rows
                    .where((row) => row.type == 'meal')
                    .map((row) => row.note)
                    .toList(),
              ),
        restoring: restoring,
        linking: linking,
        loading: loading,
        saving: saving,
        analyzing: analyzing,
        cartBusy: cartBusy,
        linkedEmail: linkedEmail,
        intelligence: intelligence,
        entries: rows,
        products: products,
        entryType: type,
        email: email,
        password: password,
        search: search,
        note: note,
        value: value,
        unit: unit,
        error: error,
        message: message,
        onLink: _link,
        onUnlink: _unlink,
        onRefresh: _loadIntelligence,
        onSearch: _search,
        onAnalyze: _analyze,
        onAddEntry: _addEntry,
        onAddToCart: _addToCart,
        onEntryType: (next) => setState(() => type = next),
      );
    }

    final page = stream == null
        ? body(const [])
        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              final rows =
                  snap.data?.docs.map((doc) {
                    final d = doc.data();
                    return NutritionLogRow(
                      type: (d['type'] as String?) ?? 'entry',
                      note: (d['note'] as String?) ?? '',
                      value: d['value'] as num?,
                      unit: d['unit'] as String?,
                    );
                  }).toList() ??
                  const <NutritionLogRow>[];
              return body(rows);
            },
          );

    final canPop = Navigator.of(context).canPop();
    if (!canPop) return page;
    return Scaffold(
      backgroundColor: HulkaLook.linen,
      appBar: AppBar(title: const Text('Nutrition')),
      body: page,
    );
  }
}

/// Debug-only screenshot surface: linked or unlinked Nutrition UI without Firebase.
class NutritionPreviewPage extends StatefulWidget {
  const NutritionPreviewPage({super.key, required this.linked});
  final bool linked;

  @override
  State<NutritionPreviewPage> createState() => _NutritionPreviewPageState();
}

class _NutritionPreviewPageState extends State<NutritionPreviewPage> {
  final email = TextEditingController(text: 'ada@sokonis.shop');
  final password = TextEditingController();
  final search = TextEditingController();
  final note = TextEditingController(text: 'ugali, sukuma');
  final value = TextEditingController();
  final unit = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    search.dispose();
    note.dispose();
    value.dispose();
    unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HulkaLook.linen,
      body: NutritionWorkspace(
        restoring: false,
        linking: false,
        loading: false,
        saving: false,
        analyzing: false,
        cartBusy: false,
        linkedEmail: widget.linked ? 'ada@sokonis.shop' : null,
        intelligence: widget.linked
            ? NutritionWorkspace.sampleIntelligence()
            : null,
        entries: widget.linked
            ? const [
                NutritionLogRow(
                  type: 'meal',
                  note: 'Ugali and sukuma',
                  value: 1,
                  unit: 'plate',
                ),
                NutritionLogRow(
                  type: 'activity',
                  note: 'Walk to the market',
                  value: 28,
                  unit: 'min',
                ),
              ]
            : const [],
        products: widget.linked
            ? const [
                SokonisProduct(
                  id: 's1',
                  name: 'Sukuma wiki bunch',
                  price: 40,
                  calories: 36,
                  hasHealthBenefits: true,
                ),
                SokonisProduct(
                  id: 's2',
                  name: 'Unga 2kg',
                  price: 220,
                  calories: 130,
                ),
              ]
            : const [],
        entryType: 'meal',
        email: email,
        password: password,
        search: search,
        note: note,
        value: value,
        unit: unit,
        error: null,
        message: widget.linked ? null : null,
        onLink: () {},
        onUnlink: () {},
        onRefresh: () {},
        onSearch: () {},
        onAnalyze: () {},
        onAddEntry: () {},
        onAddToCart: (_) {},
        onEntryType: (_) {},
      ),
    );
  }
}
