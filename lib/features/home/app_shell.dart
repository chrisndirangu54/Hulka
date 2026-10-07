import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../analytics/analytics_screen.dart';
import '../clinical/clinician_screen.dart';
import '../consent/consent_screen.dart';
import '../dashboard/hulka_dashboard.dart';
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
    HulkaDashboard(), TimelineScreen(), TelemedicineScreen(), PharmacyScreen(),
    WearablesScreen(), ConsentScreen(), ClinicianScreen(), AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    const destinations = [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.timeline), label: 'Timeline'),
      NavigationDestination(icon: Icon(Icons.video_call_outlined), label: 'Telemedicine'),
      NavigationDestination(icon: Icon(Icons.local_pharmacy_outlined), label: 'Pharmacy'),
      NavigationDestination(icon: Icon(Icons.watch_outlined), label: 'Wearables'),
      NavigationDestination(icon: Icon(Icons.verified_user_outlined), label: 'Consent'),
      NavigationDestination(icon: Icon(Icons.medical_services_outlined), label: 'Clinician'),
      NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'Analytics'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hulka'),
        actions: [
          IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout), tooltip: 'Sign out'),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: destinations,
      ),
    );
  }
}
