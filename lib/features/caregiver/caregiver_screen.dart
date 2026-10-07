import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({super.key});
  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  final caregiverId = TextEditingController();
  final api = HulkaFunctions();
  bool busy = false;
  String? message;

  Future<void> add() async {
    if (caregiverId.text.trim().isEmpty) return;
    setState(() { busy = true; message = null; });
    try {
      await api.linkCaregiver({
        'caregiverId': caregiverId.text.trim(),
        'scopes': ['medication.reminders', 'appointments.read'],
      });
      caregiverId.clear();
      setState(() => message = 'Caregiver access created.');
    } catch (e) {
      setState(() => message = 'Could not link caregiver: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Family & caregivers', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Grant limited caregiver access without exposing your entire medical record.'),
        const SizedBox(height: 16),
        TextField(
          controller: caregiverId,
          decoration: const InputDecoration(
            labelText: 'Caregiver Hulka user ID',
            helperText: 'Default scope: medication reminders and appointment visibility.',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : add,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add caregiver'),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!),
        ],
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('caregiverGrants')
              .where('patientId', isEqualTo: uid).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Text('No caregiver grants.');
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.group_outlined),
                    title: Text((d['caregiverId'] as String?) ?? 'Caregiver'),
                    subtitle: Text('Scopes: ${(d['scopes'] as List?)?.join(', ') ?? ''}'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
