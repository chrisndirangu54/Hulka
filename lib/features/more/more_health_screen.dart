import 'package:flutter/material.dart';

import '../../ui/care_scenes.dart';
import '../../ui/hulka_look.dart';
import '../../ui/motion_widgets.dart';
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

  void open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: HulkaLook.ui,
        reverseTransitionDuration: HulkaLook.press,
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: screen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modules = <(String, IconData, String, Widget, CareScene)>[
      (
        'Health profile',
        Icons.person_outline,
        'Core demographics, allergies and known conditions.',
        const HealthProfileScreen(),
        careScenes[4],
      ),
      (
        'Labs & diagnostics',
        Icons.biotech_outlined,
        'Longitudinal laboratory results and trends.',
        const LabsScreen(),
        careScenes[5],
      ),
      (
        'Chronic & maternal care',
        Icons.favorite_outline,
        'Diabetes, hypertension, asthma, cardiovascular, maternal and child pathways.',
        const CareProgramsScreen(),
        careScenes[0],
      ),
      (
        'Family & caregivers',
        Icons.group_outlined,
        'Granular caregiver permissions without exposing the whole record.',
        const CaregiverScreen(),
        careScenes[4],
      ),
      (
        'Insurance',
        Icons.shield_outlined,
        'Eligibility, benefits and preauthorization adapter.',
        const InsuranceScreen(),
        careScenes[1],
      ),
      (
        'Preventive care',
        Icons.event_available_outlined,
        'Clinically configured screening, vaccination and check-up reminders.',
        const PreventiveScreen(),
        careScenes[2],
      ),
      (
        'Safety tips',
        Icons.health_and_safety_outlined,
        'WHO, CDC, Kenya Red Cross and IFRC guidance for health, emergencies and outbreaks.',
        const SafetyTipsScreen(),
        careScenes[0],
      ),
      (
        'Nutrition & activity',
        Icons.restaurant_outlined,
        'Sokonis grocery intelligence, meals, activity and sleep on the same record.',
        const WellnessScreen(),
        careScenes[3],
      ),
    ];

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StaggerIn(
                  index: 0,
                  child: Text(
                    'More of the same record.',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: HulkaLook.ink),
                  ),
                ),
                SizedBox(height: 6),
                StaggerIn(
                  index: 1,
                  child: Text(
                    'Labs, family, insurance and prevention sit on the same consent spine.',
                    style: TextStyle(color: HulkaLook.atrium, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: CoverflowCarousel(height: 240)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          sliver: SliverList.builder(
            itemCount: modules.length,
            itemBuilder: (context, i) {
              final m = modules[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StaggerIn(
                  index: i,
                  child: Tilt3D(
                    maxTilt: 0.1,
                    child: PressScale(
                      onTap: () => open(context, m.$4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox(
                          height: 132,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ScenePhoto(scene: m.$5, alignment: Alignment.center),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      HulkaLook.ink.withValues(alpha: 0.82),
                                      HulkaLook.ink.withValues(alpha: 0.28),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  children: [
                                    Icon(m.$2, color: HulkaLook.copper),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            m.$1,
                                            style: const TextStyle(
                                              color: HulkaLook.linen,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            m.$3,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: HulkaLook.linen.withValues(alpha: 0.86),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: HulkaLook.copper),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
