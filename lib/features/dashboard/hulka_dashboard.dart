import 'package:flutter/material.dart';

class HulkaDashboard extends StatelessWidget {
  const HulkaDashboard({super.key});

  static const modules = <_Module>[
    _Module('Health Timeline', Icons.timeline,
        'Longitudinal visits, labs, medicines, symptoms and procedures.'),
    _Module('Telemedicine', Icons.video_call_outlined,
        'Cross-hospital appointments, referrals, video and follow-up care.'),
    _Module('Pharmacy', Icons.local_pharmacy_outlined,
        'Match verified prescriptions to available medicines and pharmacies.'),
    _Module('Wearables', Icons.watch_outlined,
        'Normalize watch and medical-device signals with provenance.'),
    _Module('AI Health Copilot', Icons.auto_awesome_outlined,
        'Evidence-linked explanations, summaries and appointment preparation.'),
    _Module('Consent & Access', Icons.verified_user_outlined,
        'Control who can access which health domains, for what purpose and for how long.'),
    _Module('Clinician Workspace', Icons.medical_services_outlined,
        'Record search, trends, referrals, SOAP drafts and clinical review queues.'),
    _Module('Health Analytics', Icons.analytics_outlined,
        'De-identified outcomes, pharmacovigilance, fairness and population trends.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hulka'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1100
              ? 4
              : constraints.maxWidth >= 720
                  ? 2
                  : 1;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Your health, connected across care.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'A consent-aware longitudinal record for patients, clinicians, hospitals, pharmacies and connected devices.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: modules.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: columns == 1 ? 2.8 : 1.45,
                ),
                itemBuilder: (context, index) {
                  final module = modules[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(module.icon, size: 32),
                            const Spacer(),
                            Text(module.title,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(module.description),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Module {
  const _Module(this.title, this.icon, this.description);

  final String title;
  final IconData icon;
  final String description;
}
