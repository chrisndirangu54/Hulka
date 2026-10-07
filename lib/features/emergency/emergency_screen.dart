import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final bloodGroup = TextEditingController();
  final allergies = TextEditingController();
  final conditions = TextEditingController();
  final medications = TextEditingController();
  final contactName = TextEditingController();
  final contactPhone = TextEditingController();
  final implants = TextEditingController();
  final api = HulkaFunctions();
  bool loaded = false;
  bool saving = false;
  String? message;

  List<String> split(String value) => value
      .split(',')
      .map((x) => x.trim())
      .where((x) => x.isNotEmpty)
      .toSet()
      .toList();

  void populate(Map<String, dynamic>? d) {
    if (loaded || d == null) return;
    loaded = true;
    bloodGroup.text = (d['bloodGroup'] as String?) ?? '';
    allergies.text = ((d['criticalAllergies'] as List?) ?? const []).join(', ');
    conditions.text = ((d['majorConditions'] as List?) ?? const []).join(', ');
    medications.text =
        ((d['currentMedications'] as List?) ?? const []).join(', ');
    contactName.text = (d['emergencyContactName'] as String?) ?? '';
    contactPhone.text = (d['emergencyContactPhone'] as String?) ?? '';
    implants.text = ((d['implants'] as List?) ?? const []).join(', ');
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      message = null;
    });
    try {
      await api.saveEmergencyProfile({
        'bloodGroup': bloodGroup.text.trim().isEmpty ? null : bloodGroup.text.trim(),
        'criticalAllergies': split(allergies.text),
        'majorConditions': split(conditions.text),
        'currentMedications': split(medications.text),
        'emergencyContactName':
            contactName.text.trim().isEmpty ? null : contactName.text.trim(),
        'emergencyContactPhone':
            contactPhone.text.trim().isEmpty ? null : contactPhone.text.trim(),
        'implants': split(implants.text),
      });
      if (mounted) setState(() => message = 'Emergency health card updated.');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not update emergency card: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));

    final stream = FirebaseFirestore.instance
        .collection('emergencyProfiles')
        .doc(uid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        populate(snap.data?.data());

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Emergency Health Card',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep only information useful during urgent care. This restricted '
              'profile is intentionally separate from your full longitudinal record.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: bloodGroup,
              decoration: const InputDecoration(labelText: 'Blood group'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: allergies,
              decoration: const InputDecoration(
                labelText: 'Critical allergies',
                helperText: 'Comma-separated',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: conditions,
              decoration: const InputDecoration(
                labelText: 'Major conditions',
                helperText: 'Comma-separated',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: medications,
              decoration: const InputDecoration(
                labelText: 'Current medications',
                helperText: 'Comma-separated',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: implants,
              decoration: const InputDecoration(
                labelText: 'Implants / important devices',
                helperText: 'Comma-separated',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactName,
              decoration: const InputDecoration(labelText: 'Emergency contact name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Emergency contact phone'),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: const Icon(Icons.emergency_outlined),
              label: Text(saving ? 'Saving…' : 'Save emergency card'),
            ),
          ],
        );
      },
    );
  }
}
