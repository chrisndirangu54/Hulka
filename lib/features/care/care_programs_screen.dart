import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui/health_workspace.dart';
import '../../ui/hulka_look.dart';
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
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await api.enrollCareProgram({'type': type, 'goals': <String>[]});
      if (mounted) setState(() => message = 'Care program enrolled.');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not enroll: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Authentication required.'));
    }

    return HealthPageBody(
      children: [
        Text('Care programs', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Choose a program to keep your care and follow-ups together.',
        ),
        if (message != null) ...[const SizedBox(height: 12), Text(message!)],
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 600 ? 2 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: programs
                  .map(
                    (p) => SizedBox(
                      width: width,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                p.$3,
                                color: const Color(0xFF0E6F6A),
                                size: 28,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                p.$2,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: HulkaLook.ink,
                                ),
                              ),
                              const SizedBox(height: 18),
                              OutlinedButton(
                                onPressed: busy ? null : () => enroll(p.$1),
                                child: const Text('Join program'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('carePrograms')
              .where('patientId', isEqualTo: uid)
              .where('active', isEqualTo: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text(
                'Active programs could not be loaded. Try again later.',
              );
            }
            if (!snap.hasData) return const LinearProgressIndicator();
            if (snap.data!.docs.isEmpty) {
              return const HealthEmptyState(
                icon: Icons.favorite_outline,
                title: 'Your care programs',
                message:
                    'Programs you join will appear here so you can keep track of your ongoing care.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active programs',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...snap.data!.docs.map(
                  (d) => ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(
                      programs
                              .where((p) => p.$1 == d.data()['type'])
                              .map((p) => p.$2)
                              .firstOrNull ??
                          'Care program',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
