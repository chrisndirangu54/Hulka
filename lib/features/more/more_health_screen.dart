import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MoreHealthScreen extends StatelessWidget {
  const MoreHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));

    final modules = const [
      ('Labs & diagnostics', Icons.biotech_outlined, 'Longitudinal laboratory results, trends and imaging references.'),
      ('Chronic care', Icons.favorite_outline, 'Diabetes, hypertension, asthma and cardiovascular care pathways.'),
      ('Maternal & child health', Icons.family_restroom_outlined, 'Antenatal, postpartum, immunization and growth tracking.'),
      ('Family & caregivers', Icons.group_outlined, 'Granular caregiver permissions without exposing the whole record.'),
      ('Insurance', Icons.shield_outlined, 'Eligibility, benefits, preauthorization and claims workflow adapters.'),
      ('Preventive care', Icons.event_available_outlined, 'Screening, vaccination and check-up reminders.'),
      ('Nutrition & activity', Icons.restaurant_outlined, 'Meal, activity, sleep and rehabilitation support.'),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('More health services', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Additional longitudinal care modules share the same consent and audit model.'),
        const SizedBox(height: 20),
        ...modules.map((m) => Card(
          child: ListTile(
            leading: Icon(m.$2),
            title: Text(m.$1),
            subtitle: Text(m.$3),
            trailing: const Icon(Icons.chevron_right),
          ),
        )),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('carePrograms')
              .where('patientId', isEqualTo: uid)
              .where('active', isEqualTo: true)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Active care programs: ${snap.data!.docs.length}'),
              ),
            );
          },
        ),
      ],
    );
  }
}
