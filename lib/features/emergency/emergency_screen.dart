import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));
    final stream = FirebaseFirestore.instance.collection('emergencyProfiles').doc(uid).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final d = snap.data?.data();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Emergency Health Card', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('A deliberately restricted emergency view; it does not expose your full medical record.'),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: d == null
                    ? const Text('No emergency profile configured yet.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Blood group: ${d['bloodGroup'] ?? 'Not set'}'),
                          Text('Critical allergies: ${(d['criticalAllergies'] as List?)?.join(', ') ?? 'None recorded'}'),
                          Text('Major conditions: ${(d['majorConditions'] as List?)?.join(', ') ?? 'None recorded'}'),
                          Text('Emergency contact: ${d['emergencyContactName'] ?? ''} ${d['emergencyContactPhone'] ?? ''}'),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
