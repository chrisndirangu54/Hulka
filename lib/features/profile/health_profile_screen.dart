import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
    if (id == null) return;
    final snap = await FirebaseFirestore.instance.collection('patients').doc(id).get();
    final d = snap.data() ?? {};
    displayName.text = (d['displayName'] as String?) ?? '';
    dateOfBirth.text = (d['dateOfBirth'] as String?) ?? '';
    sex.text = (d['sex'] as String?) ?? '';
    ethnicityOrRace.text = (d['ethnicityOrRace'] as String?) ?? '';
    allergies.text = ((d['allergies'] as List?) ?? const []).join(', ');
    conditions.text = ((d['conditions'] as List?) ?? const []).join(', ');
    if (mounted) setState(() => loading = false);
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Health profile', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Keep core details current so clinicians can interpret your history in context. '
          'Demographic fields are optional; where used in analytics, they support fairness '
          'and epidemiological analysis rather than being treated as biological causation.',
        ),
        const SizedBox(height: 20),
        TextField(controller: displayName, decoration: const InputDecoration(labelText: 'Full name')),
        const SizedBox(height: 12),
        TextField(controller: dateOfBirth, decoration: const InputDecoration(labelText: 'Date of birth', hintText: 'YYYY-MM-DD')),
        const SizedBox(height: 12),
        TextField(controller: sex, decoration: const InputDecoration(labelText: 'Sex / clinically relevant sex field')),
        const SizedBox(height: 12),
        TextField(controller: ethnicityOrRace, decoration: const InputDecoration(labelText: 'Ethnicity or race', helperText: 'Optional; primarily for equity/fairness analysis.')),
        const SizedBox(height: 12),
        TextField(controller: allergies, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Allergies', helperText: 'Separate multiple entries with commas.')),
        const SizedBox(height: 12),
        TextField(controller: conditions, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Known conditions', helperText: 'Separate multiple entries with commas.')),
        if (message != null) ...[const SizedBox(height: 12), Text(message!)],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'Saving…' : 'Save profile'),
        ),
      ],
    );
  }
}
