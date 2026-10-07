import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final medicationCode = TextEditingController();
  final api = HulkaFunctions();
  bool busy = false;
  String? result;

  Future<void> rebuild() async {
    final code = medicationCode.text.trim();
    if (code.isEmpty) return;
    setState(() { busy = true; result = null; });
    try {
      final r = await api.medicationReactionAggregate(code);
      setState(() => result =
          'Events: ${r['eventCount'] ?? 0}; published cohorts: ${r['publishedCohorts'] ?? 0}; minimum cohort: ${r['minimumCohort'] ?? 10}.');
    } catch (e) {
      setState(() => result = 'Analytics request failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const metrics = [
      ('Medication outcomes', 'Temporal response and adverse-event signals'),
      ('Population health', 'De-identified prevalence and longitudinal trends'),
      ('Health equity', 'Outcome disparities and model fairness checks'),
      ('Readmissions', 'Hospital quality and follow-up patterns'),
      ('Adherence', 'Medication and care-plan adherence trends'),
      ('Pharmacovigilance', 'Potential safety signals requiring clinical review'),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Health Analytics', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Aggregate and de-identified analysis only. Demographics support fairness and epidemiology, not simplistic biological assumptions.'),
        const SizedBox(height: 20),
        ...metrics.map((x) => Card(
          child: ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: Text(x.$1),
            subtitle: Text(x.$2),
          ),
        )),
        const SizedBox(height: 20),
        Text('Medication reaction cohorts', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Small cohorts are suppressed before demographic subgroup results are published.'),
        const SizedBox(height: 12),
        TextField(
          controller: medicationCode,
          decoration: const InputDecoration(labelText: 'Medication code'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : rebuild,
          child: Text(busy ? 'Building aggregate…' : 'Rebuild aggregate'),
        ),
        if (result != null) ...[
          const SizedBox(height: 12),
          Text(result!),
        ],
      ],
    );
  }
}
