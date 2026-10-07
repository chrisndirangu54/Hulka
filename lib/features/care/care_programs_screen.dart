import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class CareProgramsScreen extends StatefulWidget {
  const CareProgramsScreen({super.key});
  @override
  State<CareProgramsScreen> createState() => _CareProgramsScreenState();
}

class _CareProgramsScreenState extends State<CareProgramsScreen> {
  final api = HulkaFunctions();
  String? message;
  bool busy = false;

  static const programs = [
    ('diabetes', 'Diabetes', Icons.bloodtype_outlined),
    ('hypertension', 'Hypertension', Icons.monitor_heart_outlined),
    ('asthma', 'Asthma', Icons.air_outlined),
    ('cardiovascular', 'Cardiovascular', Icons.favorite_outline),
    ('maternal', 'Maternal health', Icons.pregnant_woman_outlined),
    ('childHealth', 'Child health', Icons.child_care_outlined),
    ('rehabilitation', 'Rehabilitation', Icons.directions_walk_outlined),
  ];

  Future<void> enroll(String type) async {
    setState(() { busy = true; message = null; });
    try {
      await api.enrollCareProgram({'type': type, 'goals': <String>[]});
      setState(() => message = 'Care program enrolled.');
    } catch (e) {
      setState(() => message = 'Could not enroll: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Care programs', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Condition-specific longitudinal pathways instead of one generic chatbot.'),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!),
        ],
        const SizedBox(height: 20),
        ...programs.map((p) => Card(
          child: ListTile(
            leading: Icon(p.$3),
            title: Text(p.$2),
            trailing: FilledButton(
              onPressed: busy ? null : () => enroll(p.$1),
              child: const Text('Enroll'),
            ),
          ),
        )),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('carePrograms')
              .where('patientId', isEqualTo: uid)
              .where('active', isEqualTo: true)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Text('No active care programs yet.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active programs', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...snap.data!.docs.map((d) => ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text((d.data()['type'] as String?) ?? 'Care program'),
                )),
              ],
            );
          },
        ),
      ],
    );
  }
}
