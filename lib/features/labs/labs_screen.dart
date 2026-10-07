import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LabsScreen extends StatelessWidget {
  const LabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('labResults')
          .where('patientId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs.toList();
        docs.sort((a, b) {
          final aa = a.data()['collectedAt'];
          final bb = b.data()['collectedAt'];
          final at = aa is Timestamp ? aa.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          final bt = bb is Timestamp ? bb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Labs & diagnostics', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Structured laboratory results across participating facilities.'),
            const SizedBox(height: 20),
            if (docs.isEmpty)
              const Card(child: ListTile(title: Text('No laboratory results available yet.')))
            else
              ...docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.biotech_outlined),
                    title: Text((d['testName'] as String?) ?? 'Laboratory result'),
                    subtitle: Text((d['referenceRange'] as String?) == null
                        ? 'Reference range not supplied'
                        : 'Reference: ${d['referenceRange']}'),
                    trailing: Text('${d['value'] ?? ''} ${d['unit'] ?? ''}'),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
