import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class TelemedicineScreen extends StatefulWidget {
  const TelemedicineScreen({super.key});

  @override
  State<TelemedicineScreen> createState() => _TelemedicineScreenState();
}

class _TelemedicineScreenState extends State<TelemedicineScreen> {
  final clinicianId = TextEditingController();
  final organizationId = TextEditingController();
  final reason = TextEditingController();
  final startsAt = TextEditingController();
  final api = HulkaFunctions();
  bool busy = false;
  String? message;

  Future<void> request() async {
    final parsed = DateTime.tryParse(startsAt.text.trim());
    if (clinicianId.text.trim().isEmpty ||
        organizationId.text.trim().isEmpty ||
        parsed == null) {
      setState(() => message =
          'Clinician ID, organization ID and a valid ISO date/time are required.');
      return;
    }

    setState(() {
      busy = true;
      message = null;
    });
    try {
      final id = await api.createAppointment({
        'clinicianId': clinicianId.text.trim(),
        'organizationId': organizationId.text.trim(),
        'startsAt': parsed.toUtc().toIso8601String(),
        'reason': reason.text.trim(),
      });
      if (mounted) setState(() => message = 'Consultation requested: $id');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not request consultation: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> join(String appointmentId) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await api.createTelemedicineSession(appointmentId);
      if (mounted) {
        setState(() => message =
            (result['message'] as String?) ??
            'Telemedicine session response received.');
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Could not create session: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));
    final stream = FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: uid)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Telemedicine', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Request cross-hospital consultations. Video session tokens are issued '
          'only when a production video provider is configured.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: clinicianId,
          decoration: const InputDecoration(labelText: 'Clinician Hulka user ID'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: organizationId,
          decoration: const InputDecoration(labelText: 'Hospital / clinic organization ID'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: startsAt,
          decoration: const InputDecoration(
            labelText: 'Requested date & time',
            hintText: '2026-10-08T09:30:00+03:00',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: reason,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Reason for consultation'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : request,
          icon: const Icon(Icons.calendar_add_on_outlined),
          label: const Text('Request consultation'),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!),
        ],
        const SizedBox(height: 24),
        Text('My consultations', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) {
              return const Card(child: ListTile(title: Text('No consultations scheduled')));
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                final status = (d['status'] as String?) ?? 'requested';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.video_call_outlined),
                    title: Text((d['reason'] as String?) ?? 'Consultation'),
                    subtitle: Text(
                      'Status: $status\nClinician: ${d['clinicianId'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: status == 'confirmed' || status == 'inProgress'
                        ? TextButton(
                            onPressed: busy ? null : () => join(doc.id),
                            child: const Text('Join'),
                          )
                        : null,
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
