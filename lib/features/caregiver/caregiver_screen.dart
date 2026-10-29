import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui/health_workspace.dart';
import '../../ui/hulka_board.dart';
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

  @override
  void dispose() {
    caregiverId.dispose();
    super.dispose();
  }

  Future<void> add() async {
    if (caregiverId.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await api.linkCaregiver({
        'caregiverId': caregiverId.text.trim(),
        'scopes': ['medication.reminders', 'appointments.read'],
      });
      caregiverId.clear();
      if (mounted) setState(() => message = 'Caregiver access created.');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not link caregiver: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Authentication required.'));
    }

    return HealthPageBody(
      children: [
        Text(
          'Family & caregivers',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Grant limited caregiver access without exposing your entire medical record.',
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Invite someone you trust',
          subtitle:
              'They can see medication reminders and appointments. Your other health records stay private.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: caregiverId,
                decoration: const InputDecoration(
                  labelText: 'Caregiver Hulka user ID',
                  helperText:
                      'Ask them for the user ID on their Hulka account.',
                  helperMaxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : add,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(busy ? 'Adding...' : 'Add caregiver'),
              ),
            ],
          ),
        ),
        if (message != null) ...[const SizedBox(height: 12), Text(message!)],
        const SizedBox(height: 28),
        Text(
          'People with access',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('caregiverGrants')
              .where('patientId', isEqualTo: uid)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text(
                'Caregiver access could not be loaded. Try again later.',
              );
            }
            if (!snap.hasData) return const LinearProgressIndicator();
            if (snap.data!.docs.isEmpty) {
              return const HealthEmptyState(
                icon: Icons.group_outlined,
                title: 'You decide who can help',
                message:
                    'Add a caregiver above to share reminders and appointments.',
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.group_outlined),
                    title: Text((d['caregiverId'] as String?) ?? 'Caregiver'),
                    subtitle: Text(
                      ((d['scopes'] as List?) ?? [])
                          .map(
                            (scope) => scope == 'medication.reminders'
                                ? 'Medication reminders'
                                : scope == 'appointments.read'
                                ? 'Appointments'
                                : scope.toString(),
                          )
                          .join(', '),
                    ),
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
