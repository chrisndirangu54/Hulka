import 'package:flutter/material.dart';

class ClinicianScreen extends StatelessWidget {
  const ClinicianScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = const [
      ('Patient search', Icons.person_search_outlined),
      ('Longitudinal history', Icons.history),
      ('Labs & imaging', Icons.biotech_outlined),
      ('Medication review', Icons.medication_outlined),
      ('Wearable trends', Icons.monitor_heart_outlined),
      ('Referrals', Icons.alt_route),
      ('SOAP note drafts', Icons.description_outlined),
      ('Clinical review queue', Icons.fact_check_outlined),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Clinician Workspace', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Evidence-linked workflow support. Clinical decisions remain with qualified clinicians.'),
        const SizedBox(height: 20),
        ...sections.map((x) => Card(
          child: ListTile(leading: Icon(x.$2), title: Text(x.$1), trailing: const Icon(Icons.chevron_right)),
        )),
      ],
    );
  }
}
