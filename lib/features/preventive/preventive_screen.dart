import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui/health_workspace.dart';
import '../../ui/hulka_board.dart';
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
      if (!mounted) return;
      final configured = result['configured'] == true;
      if (!configured) {
        setState(
          () => message =
              (result['message'] as String?) ??
              'No clinically reviewed preventive-care rule pack is configured.',
        );
      } else {
        setState(
          () => message =
              'Preventive-care review complete. ${result['generated'] ?? 0} applicable task(s) evaluated.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = 'Preventive-care review failed: $e');
      }
    } finally {
      if (mounted) setState(() => evaluating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Authentication required.'));
    }

    final tasks = FirebaseFirestore.instance
        .collection('preventiveTasks')
        .where('patientId', isEqualTo: uid)
        .snapshots();

    return HealthPageBody(
      children: [
        Text(
          'Preventive care',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'See screenings, vaccinations and follow-ups recommended for your record. Recommendations require a clinically reviewed care plan.',
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Check what is due',
          subtitle:
              'Review your record for the next steps in your preventive care.',
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: evaluating ? null : evaluate,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: Text(
                evaluating ? 'Reviewing…' : 'Review my preventive care',
              ),
            ),
          ),
        ),
        if (message != null) ...[const SizedBox(height: 12), Text(message!)],
        const SizedBox(height: 24),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: tasks,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text(
                'Your preventive-care tasks could not be loaded. Try again later.',
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return const HealthEmptyState(
                icon: Icons.event_available_outlined,
                title: 'No tasks to show yet',
                message:
                    'Run a review to check for follow-ups. If a care plan has not been configured, ask your care team about your next screening.',
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(
                      (d['title'] as String?) ?? 'Preventive-care task',
                    ),
                    subtitle: Text(
                      [
                        'Status: ${d['status'] ?? 'due'}',
                        if (d['description'] != null)
                          d['description'].toString(),
                        if (d['source'] != null) 'Source: ${d['source']}',
                      ].join('\n'),
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
