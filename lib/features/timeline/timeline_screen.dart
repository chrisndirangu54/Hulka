import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Sign in to view your timeline.'));
    final stream = FirebaseFirestore.instance.collection('patients').doc(uid)
        .collection('timeline').orderBy('occurredAt', descending: true).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Could not load timeline: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty) {
          return const Center(child: Text('Your longitudinal health timeline will appear here.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: snap.data!.docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final d = snap.data!.docs[i].data();
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.medical_information_outlined)),
              title: Text((d['title'] as String?) ?? 'Health event'),
              subtitle: Text((d['summary'] as String?) ?? (d['type'] as String?) ?? ''),
            );
          },
        );
      },
    );
  }
}
