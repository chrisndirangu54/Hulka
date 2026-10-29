import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui/health_workspace.dart';

import '../../services/bima_guardian_insurance.dart';
import '../../services/functions_service.dart';
import '../../ui/hulka_board.dart';
import '../../ui/hulka_look.dart';

class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key});
  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> {
  // â”€â”€ Section 1: Coverage form â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final insurerId = TextEditingController();
  final plan = TextEditingController();
  final memberRef = TextEditingController();
  final api = HulkaFunctions();
  bool busy = false;
  String? message;

  // â”€â”€ Section 2: Bima Guardian â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // shared_preferences is not in pubspec.yaml; using local state instead.
  final gatewayUrl = TextEditingController();
  bool bimabusy = false;
  String? bimaResult;

  Future<void> save() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await api.saveInsuranceCoverage({
        'insurerId': insurerId.text.trim(),
        'planName': plan.text.trim(),
        'memberReference': memberRef.text.trim(),
      });
      setState(() => message = 'Coverage saved.');
    } catch (e) {
      setState(() => message = 'Could not save coverage: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> checkEligibility() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final r = await api.insuranceEligibility();
      setState(
        () => message =
            (r['message'] as String?) ?? 'Eligibility response received.',
      );
    } catch (e) {
      setState(() => message = 'Eligibility check failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // â”€â”€ Bima Guardian helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<String> _idToken() async =>
      await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';

  BimaGuardianInsuranceClient? _buildClient() {
    final raw = gatewayUrl.text.trim();
    if (raw.isEmpty) {
      setState(() => bimaResult = 'Enter a Gateway URL first.');
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https') {
      setState(() => bimaResult = 'Gateway URL must be a valid HTTPS address.');
      return null;
    }
    return BimaGuardianInsuranceClient(gateway: uri, userAccessToken: _idToken);
  }

  String _prettyJson(Map<String, dynamic> m) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(m);
  }

  void _showResultDialog(BuildContext ctx, String title, String body) {
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(
            body,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _getQuote(BuildContext ctx, String uid) async {
    final client = _buildClient();
    if (client == null) return;
    final ref = memberRef.text.trim();
    if (ref.isEmpty) {
      setState(() => bimaResult = 'Enter a Member Reference first.');
      return;
    }
    setState(() {
      bimabusy = true;
      bimaResult = null;
    });
    try {
      final result = await client.quote(
        applicantId: uid,
        consentReference: ref,
        sumInsured: 100000,
      );
      if (!mounted) return;
      _showResultDialog(context, 'Quote', _prettyJson(result));
    } catch (e) {
      setState(() => bimaResult = 'Quote failed: $e');
    } finally {
      client.close();
      if (mounted) setState(() => bimabusy = false);
    }
  }

  Future<void> _getBenefitBalance(BuildContext ctx, String uid) async {
    final client = _buildClient();
    if (client == null) return;
    final ref = memberRef.text.trim();
    if (ref.isEmpty) {
      setState(() => bimaResult = 'Enter a Member Reference first.');
      return;
    }
    setState(() {
      bimabusy = true;
      bimaResult = null;
    });
    try {
      final result = await client.benefitBalance(
        applicantId: uid,
        consentReference: ref,
      );
      if (!mounted) return;
      _showResultDialog(context, 'Benefit Balance', _prettyJson(result));
    } catch (e) {
      setState(() => bimaResult = 'Benefit balance check failed: $e');
    } finally {
      client.close();
      if (mounted) setState(() => bimabusy = false);
    }
  }

  Future<void> _preauthorize(BuildContext ctx, String uid) async {
    final client = _buildClient();
    if (client == null) return;
    final ref = memberRef.text.trim();
    if (ref.isEmpty) {
      setState(() => bimaResult = 'Enter a Member Reference first.');
      return;
    }

    final serviceCodeCtrl = TextEditingController();
    final providerIdCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('Pre-authorization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: serviceCodeCtrl,
              decoration: const InputDecoration(labelText: 'Service code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: providerIdCtrl,
              decoration: const InputDecoration(labelText: 'Provider ID'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      client.close();
      return;
    }

    setState(() {
      bimabusy = true;
      bimaResult = null;
    });
    try {
      final result = await client.preauthorize(
        applicantId: uid,
        consentReference: ref,
        serviceCode: serviceCodeCtrl.text.trim(),
        providerId: providerIdCtrl.text.trim(),
      );
      if (!mounted) return;
      _showResultDialog(context, 'Pre-authorization', _prettyJson(result));
    } catch (e) {
      setState(() => bimaResult = 'Pre-authorization failed: $e');
    } finally {
      client.close();
      if (mounted) setState(() => bimabusy = false);
    }
  }

  Future<void> _claimsHistory(BuildContext ctx, String uid) async {
    final client = _buildClient();
    if (client == null) return;
    final ref = memberRef.text.trim();
    if (ref.isEmpty) {
      setState(() => bimaResult = 'Enter a Member Reference first.');
      return;
    }
    setState(() {
      bimabusy = true;
      bimaResult = null;
    });
    try {
      final result = await client.claimsHistory(
        applicantId: uid,
        consentReference: ref,
      );
      if (!mounted) return;
      _showResultDialog(context, 'Claims History', _prettyJson(result));
    } catch (e) {
      setState(() => bimaResult = 'Claims history failed: $e');
    } finally {
      client.close();
      if (mounted) setState(() => bimabusy = false);
    }
  }

  @override
  void dispose() {
    insurerId.dispose();
    plan.dispose();
    memberRef.dispose();
    gatewayUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Authentication required.'));
    }

    return HealthPageBody(
      children: [
        // â”€â”€ Section 1: Coverage form â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Text('Insurance', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Keep your coverage details handy and check the services available through your insurer.',
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Your coverage',
          subtitle: 'Keep your insurer and membership details together.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: insurerId,
                decoration: const InputDecoration(labelText: 'Insurer ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plan,
                decoration: const InputDecoration(labelText: 'Plan name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: memberRef,
                decoration: const InputDecoration(
                  labelText: 'Member reference',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy ? null : save,
                    child: const Text('Save coverage'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : checkEligibility,
                    child: const Text('Check eligibility'),
                  ),
                ],
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(message!),
              ],
            ],
          ),
        ),

        // â”€â”€ Section 2: Bima Guardian Connect â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        const SizedBox(height: 28),
        HulkaBoard(
          title: 'Bima Guardian',
          subtitle:
              'Get an instant insurance quote, check your benefit balance, and request pre-authorization for procedures.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Consent notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: HulkaLook.copper.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: HulkaLook.copper.withValues(alpha: 0.35),
                  ),
                ),
                child: const Text(
                  'By connecting Bima Guardian, you consent to sharing your coverage reference with the Bima Guardian gateway for the purpose of insurance services.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: gatewayUrl,
                decoration: const InputDecoration(
                  labelText: 'Gateway URL',
                  hintText: 'https://gateway.example.com',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              // Member reference is shared with Section 1 controller
              TextField(
                controller: memberRef,
                decoration: const InputDecoration(
                  labelText: 'Member Reference',
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: bimabusy ? null : () => _getQuote(context, uid),
                    icon: const Icon(Icons.request_quote_outlined, size: 18),
                    label: const Text('Get quote'),
                  ),
                  OutlinedButton.icon(
                    onPressed: bimabusy
                        ? null
                        : () => _getBenefitBalance(context, uid),
                    icon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                    ),
                    label: const Text('Benefit balance'),
                  ),
                  OutlinedButton.icon(
                    onPressed: bimabusy
                        ? null
                        : () => _preauthorize(context, uid),
                    icon: const Icon(Icons.assignment_outlined, size: 18),
                    label: const Text('Pre-authorize'),
                  ),
                  OutlinedButton.icon(
                    onPressed: bimabusy
                        ? null
                        : () => _claimsHistory(context, uid),
                    icon: const Icon(Icons.history_outlined, size: 18),
                    label: const Text('Claims history'),
                  ),
                ],
              ),
              if (bimabusy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (bimaResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HulkaLook.paper,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: HulkaLook.copper.withValues(alpha: 0.25),
                    ),
                  ),
                  child: SelectableText(
                    bimaResult!,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        ),

        // â”€â”€ Section 3: Coverage list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        const SizedBox(height: 28),
        Text('Saved coverage', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('insuranceCoverage')
              .where('patientId', isEqualTo: uid)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text(
                'Saved coverage could not be loaded. Try again later.',
              );
            }
            if (!snap.hasData) return const LinearProgressIndicator();
            if (snap.data!.docs.isEmpty) {
              return const HealthEmptyState(
                icon: Icons.shield_outlined,
                title: 'No coverage saved',
                message:
                    'Add your insurer, plan and member reference above to keep them on your record.',
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text((d['planName'] as String?) ?? 'Health plan'),
                    subtitle: Text((d['memberReference'] as String?) ?? ''),
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
