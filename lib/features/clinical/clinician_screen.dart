import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class ClinicianScreen extends StatefulWidget {
  const ClinicianScreen({super.key});

  @override
  State<ClinicianScreen> createState() => _ClinicianScreenState();
}

class _ClinicianScreenState extends State<ClinicianScreen> {
  final patientId = TextEditingController();
  final genericName = TextEditingController();
  final strength = TextEditingController();
  final form = TextEditingController(text: 'tablet');
  final quantity = TextEditingController();
  final instructions = TextEditingController();
  final organizationId = TextEditingController();
  final api = HulkaFunctions();

  bool loading = false;
  bool actionBusy = false;
  String? error;
  String? message;
  Map<String, dynamic>? summary;

  Future<void> loadPatient() async {
    final id = patientId.text.trim();
    if (id.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
      summary = null;
      message = null;
    });
    try {
      final result = await api.getPatientSummary(id);
      if (mounted) setState(() => summary = result);
    } catch (e) {
      if (mounted) {
        setState(() => error =
            'Could not access patient history. Confirm verified clinician status '
            'and patient consent. $e');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> prescribe() async {
    final id = patientId.text.trim();
    final qty = int.tryParse(quantity.text.trim());
    if (id.isEmpty ||
        genericName.text.trim().isEmpty ||
        strength.text.trim().isEmpty ||
        form.text.trim().isEmpty ||
        instructions.text.trim().isEmpty ||
        qty == null ||
        qty <= 0) {
      setState(() => message = 'Complete all prescription fields with a valid quantity.');
      return;
    }

    setState(() {
      actionBusy = true;
      message = null;
    });
    try {
      final prescriptionId = await api.issuePrescription({
        'patientId': id,
        'organizationId':
            organizationId.text.trim().isEmpty ? null : organizationId.text.trim(),
        'genericName': genericName.text.trim(),
        'strength': strength.text.trim(),
        'form': form.text.trim(),
        'quantity': qty,
        'instructions': instructions.text.trim(),
        'substitutionAllowed': true,
      });
      if (mounted) {
        setState(() => message = 'Prescription issued: $prescriptionId');
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Prescription could not be issued: $e');
    } finally {
      if (mounted) setState(() => actionBusy = false);
    }
  }

  Future<void> setAppointmentStatus(String id, String status) async {
    setState(() {
      actionBusy = true;
      message = null;
    });
    try {
      await api.updateAppointmentStatus(id, status);
      if (mounted) setState(() => message = 'Appointment updated to $status.');
    } catch (e) {
      if (mounted) setState(() => message = 'Appointment update failed: $e');
    } finally {
      if (mounted) setState(() => actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeline = (summary?['timeline'] as List?) ?? const [];
    final observations = (summary?['observations'] as List?) ?? const [];
    final patient = summary?['patient'] is Map
        ? Map<String, dynamic>.from(summary!['patient'] as Map)
        : <String, dynamic>{};
    final clinicianUid = FirebaseAuth.instance.currentUser?.uid;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Clinician Workspace',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Retrieve longitudinal records only after patient consent. '
          'Clinical access, prescribing and appointment actions are audited server-side.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: patientId,
          decoration: const InputDecoration(labelText: 'Patient Hulka ID'),
          onSubmitted: (_) => loadPatient(),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: loading ? null : loadPatient,
          icon: const Icon(Icons.person_search_outlined),
          label: Text(loading ? 'Loading…' : 'Load patient history'),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!),
        ],
        if (summary != null) ...[
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text((patient['displayName'] as String?) ?? 'Patient'),
              subtitle: Text(
                'Allergies: ${(patient['allergies'] as List?)?.join(', ') ?? 'Not recorded'}\n'
                'Conditions: ${(patient['conditions'] as List?)?.join(', ') ?? 'Not recorded'}',
              ),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 16),
          Text('Recent timeline', style: Theme.of(context).textTheme.titleMedium),
          if (timeline.isEmpty)
            const Text('No timeline events available.')
          else
            ...timeline.map((raw) {
              final d = Map<String, dynamic>.from(raw as Map);
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text((d['title'] as String?) ?? 'Health event'),
                subtitle: Text((d['summary'] as String?) ?? ''),
              );
            }),
          const SizedBox(height: 16),
          Text('Recent observations',
              style: Theme.of(context).textTheme.titleMedium),
          if (observations.isEmpty)
            const Text('No observations available.')
          else
            ...observations.map((raw) {
              final d = Map<String, dynamic>.from(raw as Map);
              return ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: Text(
                  (d['display'] as String?) ??
                      (d['code'] as String?) ??
                      'Observation',
                ),
                trailing: Text('${d['value'] ?? ''} ${d['unit'] ?? ''}'),
              );
            }),
          const Divider(height: 36),
          Text('Issue prescription',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Prescription creation is restricted to verified clinicians and requires '
            'the patient to grant the clinical write scope.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: organizationId,
            decoration: const InputDecoration(
              labelText: 'Organization ID (optional if managed elsewhere)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: genericName,
            decoration: const InputDecoration(labelText: 'Generic medicine name'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: strength,
                  decoration: const InputDecoration(labelText: 'Strength'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: form,
                  decoration: const InputDecoration(labelText: 'Dose form'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: instructions,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Instructions'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: actionBusy ? null : prescribe,
            icon: const Icon(Icons.medication_outlined),
            label: const Text('Issue prescription'),
          ),
        ],
        const Divider(height: 40),
        Text('Consultation queue',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (clinicianUid == null)
          const Text('Authentication required.')
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('clinicianId', isEqualTo: clinicianUid)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.data!.docs.isEmpty) {
                return const Text('No consultation requests.');
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
                        'Patient: ${d['patientId'] ?? ''}\nStatus: $status',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        enabled: !actionBusy,
                        onSelected: (value) =>
                            setAppointmentStatus(doc.id, value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'confirmed',
                            child: Text('Confirm'),
                          ),
                          PopupMenuItem(
                            value: 'inProgress',
                            child: Text('Start'),
                          ),
                          PopupMenuItem(
                            value: 'completed',
                            child: Text('Complete'),
                          ),
                          PopupMenuItem(
                            value: 'cancelled',
                            child: Text('Cancel'),
                          ),
                        ],
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
