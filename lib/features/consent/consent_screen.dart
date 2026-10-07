import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  final granteeId = TextEditingController();
  final purpose = TextEditingController(text: 'care');
  final api = HulkaFunctions();
  bool saving = false;
  String? message;

  final scopes = <String, bool>{
    'patient.profile.read': true,
    'patient.timeline.read': true,
    'patient.observations.read': true,
    'patient.timeline.write': false,
    'patient.observations.write': false,
  };

  Future<void> grant() async {
    final target = granteeId.text.trim();
    final selected = scopes.entries
        .where((x) => x.value)
        .map((x) => x.key)
        .toList();
    if (target.isEmpty || selected.isEmpty) {
      setState(() => message = 'Enter a grantee ID and select at least one scope.');
      return;
    }
    setState(() {
      saving = true;
      message = null;
    });
    try {
      await api.grantConsent({
        'granteeId': target,
        'granteeType': 'user',
        'scopes': selected,
        'purpose': purpose.text.trim().isEmpty ? 'care' : purpose.text.trim(),
      });
      granteeId.clear();
      if (mounted) setState(() => message = 'Access grant saved.');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not grant access: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> revoke(String consentId) async {
    setState(() {
      saving = true;
      message = null;
    });
    try {
      await api.revokeConsent(consentId);
      if (mounted) setState(() => message = 'Access revoked.');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not revoke access: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));

    final stream = FirebaseFirestore.instance
        .collection('consents')
        .where('patientId', isEqualTo: uid)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Consent & Access', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Grant a verified clinician, laboratory or pharmacy only the scopes needed '
          'for a specific purpose. Access can be revoked at any time.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: granteeId,
          decoration: const InputDecoration(
            labelText: 'Clinician / provider Hulka user ID',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: purpose,
          decoration: const InputDecoration(labelText: 'Purpose'),
        ),
        const SizedBox(height: 12),
        ...scopes.entries.map(
          (entry) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: entry.value,
            title: Text(entry.key),
            onChanged: saving
                ? null
                : (value) => setState(() => scopes[entry.key] = value ?? false),
          ),
        ),
        FilledButton.icon(
          onPressed: saving ? null : grant,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Grant access'),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!),
        ],
        const SizedBox(height: 28),
        Text('Existing grants', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) return const Text('No sharing grants.');
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                final active = d['revokedAt'] == null;
                return Card(
                  child: ListTile(
                    leading: Icon(active
                        ? Icons.lock_open_outlined
                        : Icons.lock_outline),
                    title: Text((d['granteeId'] as String?) ?? 'Healthcare participant'),
                    subtitle: Text(
                      'Purpose: ${d['purpose'] ?? 'care'}\n'
                      'Scopes: ${(d['scopes'] as List?)?.join(', ') ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: active
                        ? TextButton(
                            onPressed: saving ? null : () => revoke(doc.id),
                            child: const Text('Revoke'),
                          )
                        : const Chip(label: Text('Revoked')),
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
