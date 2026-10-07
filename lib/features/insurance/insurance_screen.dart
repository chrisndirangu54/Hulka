import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key});
  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> {
  final insurerId = TextEditingController();
  final plan = TextEditingController();
  final memberRef = TextEditingController();
  final api = HulkaFunctions();
  bool busy = false;
  String? message;

  Future<void> save() async {
    setState(() { busy = true; message = null; });
    try {
      await api.saveInsuranceCoverage({
        'insurerId': insurerId.text.trim(),
        'planName': plan.text.trim(),
        'memberReference': memberRef.text.trim(),
      });
      setState(() => message = 'Coverage saved.');
    } catch (e) {
      setState(() => message = 'Could not save coverage: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> checkEligibility() async {
    setState(() { busy = true; message = null; });
    try {
      final r = await api.insuranceEligibility();
      setState(() => message = (r['message'] as String?) ?? 'Eligibility response received.');
    } catch (e) {
      setState(() => message = 'Eligibility check failed: $e');
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
        Text('Insurance', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Store your coverage reference and connect eligibility/preauthorization when an insurer API is configured.'),
        const SizedBox(height: 16),
        TextField(controller: insurerId, decoration: const InputDecoration(labelText: 'Insurer ID')),
        const SizedBox(height: 12),
        TextField(controller: plan, decoration: const InputDecoration(labelText: 'Plan name')),
        const SizedBox(height: 12),
        TextField(controller: memberRef, decoration: const InputDecoration(labelText: 'Member reference')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(onPressed: busy ? null : save, child: const Text('Save coverage')),
            OutlinedButton(onPressed: busy ? null : checkEligibility, child: const Text('Check eligibility')),
          ],
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!),
        ],
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('insuranceCoverage')
              .where('patientId', isEqualTo: uid).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) return const Text('No coverage saved.');
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text((d['planName'] as String?) ?? 'Health plan'),
                    subtitle: Text((d['memberReference'] as String?) ?? ''),
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
