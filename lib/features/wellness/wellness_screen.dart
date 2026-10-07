import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  String type = 'meal';
  final note = TextEditingController();
  final value = TextEditingController();
  final unit = TextEditingController();
  bool saving = false;
  String? message;

  Future<void> addEntry() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final parsed = value.text.trim().isEmpty ? null : num.tryParse(value.text.trim());

    if (value.text.trim().isNotEmpty && parsed == null) {
      setState(() => message = 'Value must be numeric when provided.');
      return;
    }

    setState(() {
      saving = true;
      message = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('patients').doc(uid).collection('wellnessEntries').add({
        'patientId': uid,
        'type': type,
        'note': note.text.trim(),
        'value': parsed,
        'unit': unit.text.trim().isEmpty ? null : unit.text.trim(),
        'recordedAt': FieldValue.serverTimestamp(),
        'provenance': 'patientReported',
        'synthetic': false,
      });
      note.clear();
      value.clear();
      unit.clear();
      if (mounted) setState(() => message = 'Entry added.');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not add entry: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));

    final stream = FirebaseFirestore.instance
        .collection('patients').doc(uid).collection('wellnessEntries')
        .orderBy('recordedAt', descending: true).limit(50).snapshots();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Nutrition, activity & wellness', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Log meals, exercise, sleep and other patient-reported observations. '
          'These entries remain distinct from clinician-entered or device measurements.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Entry type'),
          items: const [
            DropdownMenuItem(value: 'meal', child: Text('Meal / nutrition')),
            DropdownMenuItem(value: 'activity', child: Text('Activity / exercise')),
            DropdownMenuItem(value: 'sleep', child: Text('Sleep')),
            DropdownMenuItem(value: 'rehabilitation', child: Text('Rehabilitation')),
            DropdownMenuItem(value: 'symptom', child: Text('Symptom / wellbeing')),
          ],
          onChanged: (next) {
            if (next != null) setState(() => type = next);
          },
        ),
        const SizedBox(height: 12),
        TextField(controller: note, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(
              controller: value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Value (optional)'),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit (optional)'))),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: saving ? null : addEntry,
          icon: const Icon(Icons.add),
          label: Text(saving ? 'Saving…' : 'Add entry'),
        ),
        if (message != null) ...[const SizedBox(height: 12), Text(message!)],
        const SizedBox(height: 24),
        Text('Recent entries', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) return const Text('No wellness entries yet.');
            return Column(children: snap.data!.docs.map((doc) {
              final d = doc.data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.self_improvement_outlined),
                  title: Text((d['type'] as String?) ?? 'Wellness entry'),
                  subtitle: Text((d['note'] as String?) ?? ''),
                  trailing: d['value'] == null ? null : Text('${d['value']} ${d['unit'] ?? ''}'),
                ),
              );
            }).toList());
          },
        ),
      ],
    );
  }
}
