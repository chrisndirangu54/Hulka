import 'package:flutter/material.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

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
          child: ListTile(leading: const Icon(Icons.insights_outlined), title: Text(x.$1), subtitle: Text(x.$2)),
        )),
      ],
    );
  }
}
