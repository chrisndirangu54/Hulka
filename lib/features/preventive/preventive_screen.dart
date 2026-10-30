import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../ui/health_workspace.dart';
import '../../ui/hulka_board.dart';
import '../timeline/patient_records_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/functions_service.dart';

class PreventiveScreen extends StatefulWidget {
  const PreventiveScreen({super.key});

  @override
  State<PreventiveScreen> createState() => _PreventiveScreenState();
}

class _PreventiveScreenState extends State<PreventiveScreen> {
  final api = HulkaFunctions();
  bool evaluating = false;
  String? message;

  Future<void> evaluate() async {
    setState(() {
      evaluating = true;
      message = null;
    });

    try {
      final result = await api.evaluatePreventiveCare();
      if (!mounted) return;
      final configured = result['configured'] == true;
      if (!configured) {
        setState(
          () => message =
              (result['message'] as String?) ??
              'No clinically reviewed preventive-care rule pack is configured.',
        );
      } else {
        setState(
          () => message =
              'Preventive-care review complete. ${result['generated'] ?? 0} applicable task(s) evaluated.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = 'Preventive-care review failed: $e');
      }
    } finally {
      if (mounted) setState(() => evaluating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Authentication required.'));
    }

    final tasks = FirebaseFirestore.instance
        .collection('preventiveTasks')
        .where('patientId', isEqualTo: uid)
        .snapshots();

    return HealthPageBody(
      children: [
        Text(
          'Preventive care',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'See screenings, vaccinations and follow-ups recommended for your record. Recommendations require a clinically reviewed care plan.',
        ),
        const SizedBox(height: 16),
        ClipRRect(borderRadius: BorderRadius.circular(20),
          child: SizedBox(height: 180, width: double.infinity,
            child: Image.asset('assets/images/care.jpg', fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.health_and_safety, size: 64)))),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Check what is due',
          subtitle:
              'Review your record for the next steps in your preventive care.',
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: evaluating ? null : evaluate,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: Text(
                evaluating ? 'Reviewing…' : 'Review my preventive care',
              ),
            ),
          ),
        ),
        if (message != null) ...[const SizedBox(height: 12), Text(message!)],
        const SizedBox(height: 20),
        FutureBuilder<String>(
          future: rootBundle.loadString('assets/preventive/curated_catalog_v1.json'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final data = jsonDecode(snapshot.data!) as Map<String, dynamic>;
            final packages = data['packages'] as List<dynamic>;
            return HulkaBoard(
              title: 'Preventive-care packages',
              subtitle: 'Educational drafts only. Clinical approval is required before personal recommendations.',
              child: Column(children: [
                for (final item in packages)
                  ListTile(
                    leading: const Icon(Icons.health_and_safety_outlined),
                    title: Text(item['name'].toString()),
                    subtitle: Text((item['topics'] as List<dynamic>).join(' • ')),
                  ),
              ]),
            );
          },
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Trusted preventive-care library',
          subtitle: 'Educational references, not individualized prescriptions. Kenyan care pathways require locally approved clinical rules.',
          child: Column(children: [
            for (final source in const [
              ('WHO', 'Global immunization and preventive healthcare', 'https://www.who.int/health-topics/vaccines-and-immunization'),
              ('Kenya Ministry of Health', 'National vaccination services and records', 'https://portal.health.go.ke/dashboard/vaccination-schedule'),
              ('CDC', 'Adult vaccination guidance (US-specific)', 'https://www.cdc.gov/vaccines/hcp/imz-schedules/adult-age.html'),
              ('Red Cross', 'First aid and emergency preparedness', 'https://www.redcross.org/take-a-class/first-aid'),
            ])
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(source.$1), subtitle: Text(source.$2),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => launchUrl(Uri.parse(source.$3), mode: LaunchMode.externalApplication),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Your history, ready for your next doctor',
          subtitle: 'Save consultation documents or request a verified hospital import from TeknTandao Workspace.',
          child: Align(alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const PatientRecordsScreen())),
              icon: const Icon(Icons.folder_shared_outlined),
              label: const Text('Manage medical records'),
            )),
        ),
        const SizedBox(height: 24),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: tasks,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text(
                'Your preventive-care tasks could not be loaded. Try again later.',
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return const HealthEmptyState(
                icon: Icons.event_available_outlined,
                title: 'No tasks to show yet',
                message:
                    'Run a review to check for follow-ups. If a care plan has not been configured, ask your care team about your next screening.',
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(
                      (d['title'] as String?) ?? 'Preventive-care task',
                    ),
                    subtitle: Text(
                      [
                        'Status: ${d['status'] ?? 'due'}',
                        if (d['description'] != null)
                          d['description'].toString(),
                        if (d['source'] != null) 'Source: ${d['source']}',
                      ].join('\n'),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
