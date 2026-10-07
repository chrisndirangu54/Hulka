import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WearablesScreen extends StatelessWidget {
  const WearablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));
    final stream = FirebaseFirestore.instance.collection('patients').doc(uid)
        .collection('observations').where('provenance', isEqualTo: 'wearable').limit(50).snapshots();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Wearables & Devices', style: Theme.of(context).textTheme.headlineSmall),
        const Text('Apple Health, Health Connect, Garmin, Samsung and medical-device adapters feed one normalized model.'),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: const [
          Chip(label: Text('Apple Health')), Chip(label: Text('Health Connect')),
          Chip(label: Text('Garmin')), Chip(label: Text('Samsung Health')),
          Chip(label: Text('Blood pressure')), Chip(label: Text('Glucose')),
        ]),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) return const Text('No wearable observations synchronized yet.');
            return Column(children: snap.data!.docs.map((doc) {
              final d = doc.data();
              return ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: Text((d['display'] as String?) ?? (d['code'] as String?) ?? 'Observation'),
                subtitle: Text('Source: ${d['sourceId'] ?? 'device'}'),
                trailing: Text('${d['value'] ?? ''} ${d['unit'] ?? ''}'),
              );
            }).toList());
          },
        ),
      ],
    );
  }
}
