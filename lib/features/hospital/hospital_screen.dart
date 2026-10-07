import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HospitalDirectoryScreen extends StatelessWidget {
  const HospitalDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('organizations').where('verified', isEqualTo: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Care Network', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Verified hospitals, clinics, laboratories, pharmacies and insurers participating in Hulka.'),
            const SizedBox(height: 20),
            ...snap.data!.docs.map((doc) {
              final d = doc.data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.local_hospital_outlined),
                  title: Text((d['name'] as String?) ?? 'Healthcare organization'),
                  subtitle: Text((d['type'] as String?) ?? ''),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
