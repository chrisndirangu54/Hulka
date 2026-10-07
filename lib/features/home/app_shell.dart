import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../ai/ai_copilot_screen.dart';
import '../analytics/analytics_screen.dart';
import '../clinical/clinician_screen.dart';
import '../consent/consent_screen.dart';
import '../emergency/emergency_screen.dart';
import '../hospital/hospital_screen.dart';
import '../pharmacy/pharmacy_screen.dart';
import '../telemedicine/telemedicine_screen.dart';
import '../timeline/timeline_screen.dart';
import '../wearables/wearables_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final pages = const [
    TimelineScreen(),
    TelemedicineScreen(),
    PharmacyScreen(),
    WearablesScreen(),
    AiCopilotScreen(),
    HospitalDirectoryScreen(),
    EmergencyScreen(),
    ConsentScreen(),
    ClinicianScreen(),
    AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    const destinations = [
      NavigationRailDestination(icon: Icon(Icons.timeline), label: Text('Timeline')),
      NavigationRailDestination(icon: Icon(Icons.video_call_outlined), label: Text('Telemedicine')),
      NavigationRailDestination(icon: Icon(Icons.local_pharmacy_outlined), label: Text('Pharmacy')),
      NavigationRailDestination(icon: Icon(Icons.watch_outlined), label: Text('Wearables')),
      NavigationRailDestination(icon: Icon(Icons.auto_awesome_outlined), label: Text('AI Copilot')),
      NavigationRailDestination(icon: Icon(Icons.local_hospital_outlined), label: Text('Care network')),
      NavigationRailDestination(icon: Icon(Icons.emergency_outlined), label: Text('Emergency')),
      NavigationRailDestination(icon: Icon(Icons.verified_user_outlined), label: Text('Consent')),
      NavigationRailDestination(icon: Icon(Icons.medical_services_outlined), label: Text('Clinician')),
      NavigationRailDestination(icon: Icon(Icons.analytics_outlined), label: Text('Analytics')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hulka'),
        actions: [
          IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout), tooltip: 'Sign out'),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                Expanded(child: pages[index]),
                NavigationBar(
                  selectedIndex: index > 4 ? 0 : index,
                  onDestinationSelected: (value) => setState(() => index = value),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.timeline), label: 'Timeline'),
                    NavigationDestination(icon: Icon(Icons.video_call_outlined), label: 'Care'),
                    NavigationDestination(icon: Icon(Icons.local_pharmacy_outlined), label: 'Pharmacy'),
                    NavigationDestination(icon: Icon(Icons.watch_outlined), label: 'Devices'),
                    NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'AI'),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: (value) => setState(() => index = value),
                labelType: NavigationRailLabelType.all,
                destinations: destinations,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: pages[index]),
            ],
          );
        },
      ),
    );
  }
}
