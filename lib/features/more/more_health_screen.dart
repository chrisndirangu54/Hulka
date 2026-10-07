import 'package:flutter/material.dart';
import '../care/care_programs_screen.dart';
import '../caregiver/caregiver_screen.dart';
import '../insurance/insurance_screen.dart';
import '../labs/labs_screen.dart';
import '../preventive/preventive_screen.dart';
import '../profile/health_profile_screen.dart';
import '../wellness/wellness_screen.dart';

class MoreHealthScreen extends StatelessWidget {
  const MoreHealthScreen({super.key});

  void open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final modules = <(String, IconData, String, Widget)>[
      ('Health profile', Icons.person_outline, 'Core demographics, allergies and known conditions.', const HealthProfileScreen()),
      ('Labs & diagnostics', Icons.biotech_outlined, 'Longitudinal laboratory results and trends.', const LabsScreen()),
      ('Chronic & maternal care', Icons.favorite_outline, 'Diabetes, hypertension, asthma, cardiovascular, maternal and child pathways.', const CareProgramsScreen()),
      ('Family & caregivers', Icons.group_outlined, 'Granular caregiver permissions without exposing the whole record.', const CaregiverScreen()),
      ('Insurance', Icons.shield_outlined, 'Eligibility, benefits and preauthorization adapter.', const InsuranceScreen()),
      ('Preventive care', Icons.event_available_outlined, 'Clinically configured screening, vaccination and check-up reminders.', const PreventiveScreen()),
      ('Nutrition & activity', Icons.restaurant_outlined, 'Patient-reported meals, activity, sleep and rehabilitation logs.', const WellnessScreen()),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('More health services', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Additional longitudinal care modules share the same consent, provenance and audit model.'),
        const SizedBox(height: 20),
        ...modules.map((m) => Card(
          child: ListTile(
            leading: Icon(m.$2),
            title: Text(m.$1),
            subtitle: Text(m.$3),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, m.$4),
          ),
        )),
      ],
    );
  }
}
