import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui/health_workspace.dart';
import '../../ui/hulka_look.dart';

class LabsScreen extends StatelessWidget {
  const LabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Authentication required.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('labResults')
          .where('patientId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const HealthPageBody(
            children: [
              HealthEmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Results could not be loaded',
                message: 'Go back and open Labs again to retry.',
              ),
            ],
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs.toList();
        docs.sort((a, b) {
          final aa = a.data()['collectedAt'];
          final bb = b.data()['collectedAt'];
          final at = aa is Timestamp
              ? aa.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          final bt = bb is Timestamp
              ? bb.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });

        return HealthPageBody(
          children: [
            Text(
              'Labs & diagnostics',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Structured laboratory results across participating facilities.',
            ),
            const SizedBox(height: 20),
            if (docs.isEmpty)
              const HealthEmptyState(
                icon: Icons.biotech_outlined,
                title: 'Your results will appear here',
                message:
                    'Results shared by participating facilities are collected here, with their reference ranges.',
              )
            else
              ...docs.map((doc) {
                final d = doc.data();
                final collected = d['collectedAt'];
                final date = collected is Timestamp ? collected.toDate() : null;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.biotech_outlined,
                              color: Color(0xFF0E6F6A),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                (d['testName'] as String?) ??
                                    'Laboratory result',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${d['value'] ?? "Not supplied"} ${d['unit'] ?? ""}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: HulkaLook.atrium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          d['referenceRange'] == null
                              ? 'Reference range not supplied'
                              : 'Reference: ${d['referenceRange']}',
                        ),
                        if (date != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Collected ${date.day}/${date.month}/${date.year}',
                            style: const TextStyle(color: HulkaLook.atrium),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
