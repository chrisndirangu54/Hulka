import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TelemedicineScreen extends StatelessWidget {
  const TelemedicineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));
    final stream = FirebaseFirestore.instance.collection('appointments')
        .where('patientId', isEqualTo: uid).snapshots();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Telemedicine', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Cross-hospital appointments, referrals, secure messaging and remote consultations.'),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) return const Card(child: ListTile(title: Text('No consultations scheduled')));
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.video_call_outlined),
                    title: Text((d['reason'] as String?) ?? 'Consultation'),
                    subtitle: Text('Status: ${d['status'] ?? 'requested'}'),
                    trailing: const Icon(Icons.chevron_right),
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
