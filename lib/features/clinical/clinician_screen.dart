import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class ClinicianScreen extends StatefulWidget {
  const ClinicianScreen({super.key});

  @override
  State<ClinicianScreen> createState() => _ClinicianScreenState();
}

class _ClinicianScreenState extends State<ClinicianScreen> {
  final patientId = TextEditingController();
  final api = HulkaFunctions();
  bool loading = false;
  String? error;
  Map<String, dynamic>? summary;

  Future<void> loadPatient() async {
    final id = patientId.text.trim();
    if (id.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
      summary = null;
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

  @override
  Widget build(BuildContext context) {
    final timeline = (summary?['timeline'] as List?) ?? const [];
    final observations = (summary?['observations'] as List?) ?? const [];
    final patient = summary?['patient'] is Map
        ? Map<String, dynamic>.from(summary!['patient'] as Map)
        : <String, dynamic>{};

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Clinician Workspace', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Retrieve a longitudinal record only when the patient has granted the '
          'required scope. Every server-side access is audited.',
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
          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
          Text('Recent observations', style: Theme.of(context).textTheme.titleMedium),
          if (observations.isEmpty)
            const Text('No observations available.')
          else
            ...observations.map((raw) {
              final d = Map<String, dynamic>.from(raw as Map);
              return ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: Text((d['display'] as String?) ?? (d['code'] as String?) ?? 'Observation'),
                trailing: Text('${d['value'] ?? ''} ${d['unit'] ?? ''}'),
              );
            }),
        ],
      ],
    );
  }
}
