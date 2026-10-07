import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));
    final stream = FirebaseFirestore.instance.collection('consents')
        .where('patientId', isEqualTo: uid).snapshots();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Consent & Access', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Control who can access which health domains, for what purpose and for how long.'),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) return const Text('No active sharing grants.');
            return Column(children: snap.data!.docs.map((doc) {
              final d = doc.data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text((d['granteeId'] as String?) ?? 'Healthcare participant'),
                  subtitle: Text('Purpose: ${d['purpose'] ?? 'care'}'),
                  trailing: d['revokedAt'] == null ? const Chip(label: Text('Active')) : const Chip(label: Text('Revoked')),
                ),
              );
            }).toList());
          },
        ),
      ],
    );
  }
}
