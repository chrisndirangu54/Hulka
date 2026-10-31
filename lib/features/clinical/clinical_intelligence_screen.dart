import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

/// Evidence-linked clinician notes and laboratory review requests.
/// Does not generate diagnosis, prescriptions or unvalidated predictions.
class ClinicalIntelligenceScreen extends StatefulWidget {
  const ClinicalIntelligenceScreen({super.key});
  @override
  State<ClinicalIntelligenceScreen> createState() => _ClinicalIntelligenceScreenState();
}
class _ClinicalIntelligenceScreenState extends State<ClinicalIntelligenceScreen> {
  final api = HulkaFunctions();
  final patientId = TextEditingController();
  final resultId = TextEditingController();
  bool busy = false;
  String message = '';
  List<dynamic> insights = [];
  @override
  void initState() {
    super.initState();
    patientId.text = FirebaseAuth.instance.currentUser?.uid ?? '';
  }
  @override
  void dispose() {
    patientId.dispose();
    resultId.dispose();
    super.dispose();
  }
  Future<void> refresh() async {
    if (patientId.text.trim().isEmpty) return;
    setState(() { busy = true; message = ''; });
    try {
      final r = await api.listClinicalInsights(patientId.text.trim());
      if (!mounted) return;
      setState(() => insights = (r['insights'] as List?) ?? []);
    } catch (e) {
      if (mounted) setState(() => message = 'Unable to load authorized insights: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  Future<void> requestReview() async {
    if (patientId.text.trim().isEmpty || resultId.text.trim().isEmpty) return;
    setState(() { busy = true; message = ''; });
    try {
      final r = await api.requestLabIntelligenceReview(patientId.text.trim(), resultId.text.trim());
      if (mounted) setState(() => message = 'Laboratory review requested: ${r['status']}');
    } catch (e) {
      if (mounted) setState(() => message = 'Review request unsuccessful: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Clinical intelligence', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Clinician-reviewed records and evidence-linked observations. '
          'No automated diagnosis or antimicrobial prescribing.'),
      const SizedBox(height: 16),
      TextField(controller: patientId,
        decoration: const InputDecoration(labelText: 'Patient identifier')),
      TextField(controller: resultId,
        decoration: const InputDecoration(labelText: 'Laboratory result identifier (for review requests)')),
      const SizedBox(height: 12),
      Wrap(spacing: 12, children: [
        FilledButton.icon(onPressed: busy ? null : refresh,
          icon: const Icon(Icons.refresh), label: const Text('Load clinical insights')),
        OutlinedButton.icon(onPressed: busy ? null : requestReview,
          icon: const Icon(Icons.biotech), label: const Text('Request laboratory review')),
      ]),
      if (busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      if (message.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(message)),
      for (final item in insights)
        Card(child: ListTile(
          title: Text((item as Map)['domain']?.toString() ?? 'Clinical note'),
          subtitle: Text('${item['summary'] ?? ''}\nEvidence: ${item['evidenceRef'] ?? 'Not supplied'}'),
          trailing: const Icon(Icons.verified_user_outlined),
        )),
    ],
  );
}
