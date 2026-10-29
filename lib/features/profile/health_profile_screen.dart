import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui/health_workspace.dart';
import '../../ui/hulka_board.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  final displayName = TextEditingController();
  final dateOfBirth = TextEditingController();
  final sex = TextEditingController();
  final ethnicityOrRace = TextEditingController();
  final allergies = TextEditingController();
  final conditions = TextEditingController();
  bool loading = true;
  bool saving = false;
  String? message;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final id = uid;
    if (id == null) {
      if (mounted) {
        setState(() {
          loading = false;
          message = 'Sign in to load your health profile.';
        });
      }
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('patients')
          .doc(id)
          .get();
      if (!mounted) return;
      final d = snap.data() ?? {};
      displayName.text = (d['displayName'] as String?) ?? '';
      dateOfBirth.text = (d['dateOfBirth'] as String?) ?? '';
      sex.text = (d['sex'] as String?) ?? '';
      ethnicityOrRace.text = (d['ethnicityOrRace'] as String?) ?? '';
      allergies.text = ((d['allergies'] as List?) ?? const []).join(', ');
      conditions.text = ((d['conditions'] as List?) ?? const []).join(', ');
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Your profile could not be loaded. Go back and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      displayName,
      dateOfBirth,
      sex,
      ethnicityOrRace,
      allergies,
      conditions,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> splitValues(String value) => value
      .split(',')
      .map((x) => x.trim())
      .where((x) => x.isNotEmpty)
      .toSet()
      .toList();

  Future<void> save() async {
    final id = uid;
    if (id == null) return;

    final dob = dateOfBirth.text.trim();
    if (dob.isNotEmpty && DateTime.tryParse(dob) == null) {
      setState(() => message = 'Date of birth must use YYYY-MM-DD format.');
      return;
    }

    setState(() {
      saving = true;
      message = null;
    });

    try {
      await FirebaseFirestore.instance.collection('patients').doc(id).set({
        'displayName': displayName.text.trim(),
        'dateOfBirth': dob.isEmpty ? null : dob,
        'sex': sex.text.trim().isEmpty ? null : sex.text.trim(),
        'ethnicityOrRace': ethnicityOrRace.text.trim().isEmpty
            ? null
            : ethnicityOrRace.text.trim(),
        'allergies': splitValues(allergies.text),
        'conditions': splitValues(conditions.text),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(id).set({
        'displayName': displayName.text.trim(),
      }, SetOptions(merge: true));

      if (mounted) setState(() => message = 'Health profile saved.');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not save profile: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return HealthPageBody(
      children: [
        Text(
          'Your health details',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Keep the details your care team relies on up to date.',
          style: TextStyle(height: 1.5),
        ),
        const SizedBox(height: 24),
        HulkaBoard(
          title: 'Personal details',
          subtitle: 'Add only the information you want to share.',
          child: Column(
            children: [
              TextField(
                controller: displayName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              HealthFieldPair(
                first: TextField(
                  controller: dateOfBirth,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                ),
                second: TextField(
                  controller: sex,
                  decoration: const InputDecoration(
                    labelText: 'Sex (optional)',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ethnicityOrRace,
                decoration: const InputDecoration(
                  labelText: 'Ethnicity or race (optional)',
                  helperText: 'Used to assess fairness and population health.',
                  helperMaxLines: 3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        HulkaBoard(
          title: 'Allergies & conditions',
          subtitle: 'Separate multiple entries with commas.',
          child: Column(
            children: [
              TextField(
                controller: allergies,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Allergies',
                  hintText: 'For example, penicillin, peanuts',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: conditions,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Known conditions',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Semantics(liveRegion: true, child: Text(message!)),
        ],
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.save_outlined),
            label: Text(saving ? 'Saving...' : 'Save profile'),
          ),
        ),
      ],
    );
  }
}
