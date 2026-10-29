import 'package:flutter/material.dart';
import '../../ui/health_workspace.dart';
import '../../ui/hulka_look.dart';
import '../care/care_programs_screen.dart';
import '../caregiver/caregiver_screen.dart';
import '../insurance/insurance_screen.dart';
import '../labs/labs_screen.dart';
import '../preventive/preventive_screen.dart';
import '../profile/health_profile_screen.dart';
import '../safety/safety_tips_screen.dart';
import '../wellness/wellness_screen.dart';

class MoreHealthScreen extends StatelessWidget {
  const MoreHealthScreen({super.key});

  static const modules = <(String, IconData, String, Widget)>[
    (
      'Health profile',
      Icons.person_outline,
      'Your details, allergies and known conditions.',
      HealthProfileScreen(),
    ),
    (
      'Labs & diagnostics',
      Icons.biotech_outlined,
      'Test results and reference ranges in one place.',
      LabsScreen(),
    ),
    (
      'Chronic & maternal care',
      Icons.favorite_outline,
      'Care programs for ongoing conditions and family health.',
      CareProgramsScreen(),
    ),
    (
      'Family & caregivers',
      Icons.group_outlined,
      'Choose who can help with your care.',
      CaregiverScreen(),
    ),
    (
      'Insurance',
      Icons.shield_outlined,
      'Manage coverage, benefits and insurance requests.',
      InsuranceScreen(),
    ),
    (
      'Preventive care',
      Icons.event_available_outlined,
      'Keep track of screenings and follow-ups.',
      PreventiveScreen(),
    ),
    (
      'Safety tips',
      Icons.health_and_safety_outlined,
      'Practical guidance from trusted health agencies.',
      SafetyTipsScreen(embedded: true),
    ),
    (
      'Nutrition & activity',
      Icons.restaurant_outlined,
      'Connect your meals, pantry and daily habits.',
      WellnessScreen(embedded: true),
    ),
  ];

  void open(BuildContext context, int index) {
    final module = modules[index];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HealthDetailPage(title: module.$1, child: module.$4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your health, connected.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                height: 1.15,
                color: HulkaLook.ink,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Manage your record, find support and plan your next steps.',
              style: TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 16,
                color: HulkaLook.atrium,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 680 ? 2 : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (var i = 0; i < modules.length; i++)
                      SizedBox(
                        width: width,
                        child: _ModuleTile(
                          title: modules[i].$1,
                          icon: modules[i].$2,
                          description: modules[i].$3,
                          onTap: () => open(context, i),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.title,
    required this.icon,
    required this.description,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: HulkaLook.paper,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: HulkaLook.atrium.withValues(alpha: .14)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HulkaLook.pulse.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF0E6F6A), size: 25),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: HulkaLook.ink,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 14,
                      height: 1.5,
                      color: HulkaLook.atrium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 21, color: Color(0xFF0E6F6A)),
          ],
        ),
      ),
    ),
  );
}
