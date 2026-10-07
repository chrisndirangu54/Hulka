import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../ai/ai_copilot_screen.dart';
import '../analytics/analytics_screen.dart';
import '../clinical/clinician_screen.dart';
import '../consent/consent_screen.dart';
import '../emergency/emergency_screen.dart';
import '../hospital/hospital_screen.dart';
import '../more/more_health_screen.dart';
import '../pharmacy/pharmacy_screen.dart';
import '../telemedicine/telemedicine_screen.dart';
import '../timeline/timeline_screen.dart';
import '../wearables/wearables_screen.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    NotificationService().initializeForCurrentUser();
  }

  List<_Destination> destinationsFor(String role) {
    final base = <_Destination>[
      const _Destination('Timeline', Icons.timeline, TimelineScreen()),
      const _Destination('Telemedicine', Icons.video_call_outlined, TelemedicineScreen()),
      const _Destination('Pharmacy', Icons.local_pharmacy_outlined, PharmacyScreen()),
      const _Destination('Wearables', Icons.watch_outlined, WearablesScreen()),
      const _Destination('AI Copilot', Icons.auto_awesome_outlined, AiCopilotScreen()),
      const _Destination('Care network', Icons.local_hospital_outlined, HospitalDirectoryScreen()),
      const _Destination('Emergency', Icons.emergency_outlined, EmergencyScreen()),
      const _Destination('Consent', Icons.verified_user_outlined, ConsentScreen()),
      const _Destination('More', Icons.apps_outlined, MoreHealthScreen()),
    ];
    if (role == 'clinician') {
      base.add(const _Destination('Clinician', Icons.medical_services_outlined, ClinicianScreen()));
    }
    if (role == 'researcher' || role == 'hospitalAdmin') {
      base.add(const _Destination('Analytics', Icons.analytics_outlined, AnalyticsScreen()));
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final role = snap.data?.data()?['role'] as String? ?? 'patient';
        final destinations = destinationsFor(role);
        final selected = index < destinations.length ? index : 0;

        return Scaffold(
          appBar: AppBar(
            title: Text('Hulka • ${destinations[selected].label}'),
            actions: [
              IconButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
              ),
            ],
          ),
          drawer: MediaQuery.sizeOf(context).width < 760
              ? Drawer(
                  child: SafeArea(
                    child: ListView(
                      children: [
                        const ListTile(
                          leading: Icon(Icons.health_and_safety_outlined),
                          title: Text('Hulka'),
                          subtitle: Text('Connected healthcare'),
                        ),
                        const Divider(),
                        for (var i = 0; i < destinations.length; i++)
                          ListTile(
                            selected: i == selected,
                            leading: Icon(destinations[i].icon),
                            title: Text(destinations[i].label),
                            onTap: () {
                              setState(() => index = i);
                              Navigator.pop(context);
                            },
                          ),
                      ],
                    ),
                  ),
                )
              : null,
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return destinations[selected].page;
              }
              return Row(
                children: [
                  NavigationRail(
                    selectedIndex: selected,
                    onDestinationSelected: (value) => setState(() => index = value),
                    labelType: NavigationRailLabelType.all,
                    destinations: destinations
                        .map((d) => NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)))
                        .toList(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: destinations[selected].page),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
