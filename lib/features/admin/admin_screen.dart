import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final api = HulkaFunctions();

  final organizationName = TextEditingController();
  final organizationType = TextEditingController(text: 'hospital');
  final countryCode = TextEditingController(text: 'KE');
  final facilityCode = TextEditingController();

  final providerUid = TextEditingController();
  final providerRole = TextEditingController(text: 'clinician');
  final providerOrganizationId = TextEditingController();

  bool busy = false;
  String? message;

  Future<void> createOrganization() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final id = await api.upsertHealthcareOrganization({
        'name': organizationName.text.trim(),
        'type': organizationType.text.trim(),
        'countryCode': countryCode.text.trim(),
        'facilityCode': facilityCode.text.trim().isEmpty
            ? null
            : facilityCode.text.trim(),
        'verified': true,
      });
      providerOrganizationId.text = id;
      if (mounted) setState(() => message = 'Organization created: $id');
    } catch (e) {
      if (mounted) setState(() => message = 'Organization update failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verifyProvider() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await api.verifyProviderAccount({
        'providerUid': providerUid.text.trim(),
        'role': providerRole.text.trim(),
        'organizationId': providerOrganizationId.text.trim(),
      });
      if (mounted) setState(() => message = 'Provider account verified.');
    } catch (e) {
      if (mounted) setState(() => message = 'Provider verification failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Trusted Administration',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Administrative verification controls provider roles and organizations. '
          'Administrative status does not automatically grant access to patient records.',
        ),
        const SizedBox(height: 24),
        Text('Healthcare organization',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: organizationName,
          decoration: const InputDecoration(labelText: 'Organization name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: organizationType,
          decoration: const InputDecoration(
            labelText: 'Type',
            hintText: 'hospital, clinic, pharmacy, laboratory, insurer',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: countryCode,
                decoration: const InputDecoration(labelText: 'Country code'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: facilityCode,
                decoration: const InputDecoration(labelText: 'Facility code'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : createOrganization,
          child: const Text('Create / verify organization'),
        ),
        const SizedBox(height: 28),
        Text('Verify provider', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: providerUid,
          decoration: const InputDecoration(labelText: 'Provider Firebase UID'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: providerRole,
          decoration: const InputDecoration(
            labelText: 'Role',
            hintText: 'clinician, pharmacist, laboratory, hospitalAdmin, researcher',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: providerOrganizationId,
          decoration: const InputDecoration(labelText: 'Organization ID'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : verifyProvider,
          child: const Text('Verify provider'),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!),
        ],
      ],
    );
  }
}
