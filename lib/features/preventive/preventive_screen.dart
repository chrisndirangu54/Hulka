import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class PreventiveScreen extends StatefulWidget {
  const PreventiveScreen({super.key});

  @override
  State<PreventiveScreen> createState() => _PreventiveScreenState();
}

class _PreventiveScreenState extends State<PreventiveScreen> {
  final api = HulkaFunctions();
  bool evaluating = false;
  String? message;

  Future<void> evaluate() async {
    setState(() {
      evaluating = true;
      message = null;
    });

    try {
      final result = await api.evaluatePreventiveCare();
      final configured = result['configured'] == true;
      if (!configured) {
        setState(() => message =
            (result['message'] as String?) ??
            'No clinically reviewed preventive-care rule pack is configured.');
      } else {
        setState(() => message =
            'Preventive-care review complete. ${result['generated'] ?? 0} applicable task(s) evaluated.');
      }
    } catch (e) {
      setState(() => message = 'Preventive-care review failed: $e');
    } finally {
      if (mounted) setState(() => evaluating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));

    final tasks = FirebaseFirestore.instance
        .collection('preventiveTasks')
        .where('patientId', isEqualTo: uid)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Preventive care', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Screening and prevention reminders are generated only from a configured, '
          'clinically reviewed rule pack. Hulka does not invent preventive-care thresholds.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: evaluating ? null : evaluate,
          icon: const Icon(Icons.health_and_safety_outlined),
          label: Text(evaluating ? 'Reviewing…' : 'Review my preventive care'),
        ),
        if (message != null) ...[const SizedBox(height: 12), Text(message!)],
        const SizedBox(height: 24),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: tasks,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) {
              return const Card(
                child: ListTile(
                  title: Text('No preventive-care tasks'),
                  subtitle: Text('Run a review after a clinician-reviewed rule pack is configured.'),
                ),
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text((d['title'] as String?) ?? 'Preventive-care task'),
                    subtitle: Text([
                      if (d['description'] != null) d['description'].toString(),
                      if (d['source'] != null) 'Source: ${d['source']}',
                    ].join('\n')),
                    trailing: Chip(label: Text((d['status'] as String?) ?? 'due')),
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
