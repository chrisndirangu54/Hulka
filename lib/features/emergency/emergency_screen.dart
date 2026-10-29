import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/functions_service.dart';
import '../../services/safety_tips_catalog.dart';
import '../../ui/hulka_board.dart';
import '../../ui/hulka_look.dart';
import '../safety/safety_tips_screen.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final bloodGroup = TextEditingController();
  final allergies = TextEditingController();
  final conditions = TextEditingController();
  final medications = TextEditingController();
  final contactName = TextEditingController();
  final contactPhone = TextEditingController();
  final implants = TextEditingController();
  final locationNote = TextEditingController();
  final api = HulkaFunctions();
  bool loaded = false;
  bool saving = false;
  bool requesting = false;
  String? message;

  @override
  void dispose() {
    bloodGroup.dispose();
    allergies.dispose();
    conditions.dispose();
    medications.dispose();
    contactName.dispose();
    contactPhone.dispose();
    implants.dispose();
    locationNote.dispose();
    super.dispose();
  }

  List<String> split(String value) => value
      .split(',')
      .map((x) => x.trim())
      .where((x) => x.isNotEmpty)
      .toSet()
      .toList();

  void populate(Map<String, dynamic>? d) {
    if (loaded || d == null) return;
    loaded = true;
    bloodGroup.text = (d['bloodGroup'] as String?) ?? '';
    allergies.text = ((d['criticalAllergies'] as List?) ?? const []).join(', ');
    conditions.text = ((d['majorConditions'] as List?) ?? const []).join(', ');
    medications.text = ((d['currentMedications'] as List?) ?? const []).join(', ');
    contactName.text = (d['emergencyContactName'] as String?) ?? '';
    contactPhone.text = (d['emergencyContactPhone'] as String?) ?? '';
    implants.text = ((d['implants'] as List?) ?? const []).join(', ');
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      message = null;
    });
    try {
      await api.saveEmergencyProfile({
        'bloodGroup': bloodGroup.text.trim().isEmpty ? null : bloodGroup.text.trim(),
        'criticalAllergies': split(allergies.text),
        'majorConditions': split(conditions.text),
        'currentMedications': split(medications.text),
        'emergencyContactName': contactName.text.trim().isEmpty ? null : contactName.text.trim(),
        'emergencyContactPhone': contactPhone.text.trim().isEmpty ? null : contactPhone.text.trim(),
        'implants': split(implants.text),
      });
      if (mounted) setState(() => message = 'Emergency health card updated.');
    } catch (e) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => message = 'Could not update emergency card: $e');
      } else {
        try {
          await FirebaseFirestore.instance.collection('emergencyProfiles').doc(uid).set({
            'bloodGroup': bloodGroup.text.trim().isEmpty ? null : bloodGroup.text.trim(),
            'criticalAllergies': split(allergies.text),
            'majorConditions': split(conditions.text),
            'currentMedications': split(medications.text),
            'emergencyContactName': contactName.text.trim().isEmpty ? null : contactName.text.trim(),
            'emergencyContactPhone': contactPhone.text.trim().isEmpty ? null : contactPhone.text.trim(),
            'implants': split(implants.text),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          if (mounted) setState(() => message = 'Emergency health card updated.');
        } catch (inner) {
          if (mounted) setState(() => message = 'Could not update emergency card: $inner');
        }
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _call(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    await launchUrl(Uri.parse('tel:$cleaned'), mode: LaunchMode.externalApplication);
  }

  Future<void> requestAmbulance(Map<String, dynamic> hospital, String hospitalId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      requesting = true;
      message = null;
    });
    try {
      await FirebaseFirestore.instance.collection('ambulanceRequests').add({
        'patientId': uid,
        'hospitalId': hospitalId,
        'hospitalName': hospital['name'] ?? 'Partner hospital',
        'phone': hospital['ambulancePhone'] ?? hospital['phone'],
        'county': hospital['county'],
        'locationNote': locationNote.text.trim(),
        'status': 'requested',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => message =
            'Ambulance requested from ${hospital['name'] ?? 'the partner hospital'}. Call 999 if the person is collapsing now.');
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Could not request ambulance: $e');
    } finally {
      if (mounted) setState(() => requesting = false);
    }
  }

  Future<void> cancelRequest(String id) async {
    await FirebaseFirestore.instance.collection('ambulanceRequests').doc(id).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text(
          'Emergency',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: HulkaLook.ink),
        ),
        const SizedBox(height: 8),
        Text(
          'Call 999 or 112 first when life is at risk. Partner-hospital ambulances in Hulka are an extra dispatch path, not a replacement.',
          style: TextStyle(color: HulkaLook.atrium.withValues(alpha: 0.95), height: 1.4),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _call('999'),
                icon: const Icon(Icons.call),
                label: const Text('999'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _call('112'),
                icon: const Icon(Icons.call_outlined),
                label: const Text('112'),
              ),
            ),
          ],
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!, style: const TextStyle(color: HulkaLook.atrium, height: 1.35)),
        ],
        const SizedBox(height: 18),
        HulkaBoard(
          title: 'Safety tips',
          subtitle: 'WHO, CDC, Kenya Red Cross and IFRC — cited on each card.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final tip in SafetyTipsCatalog.byCategory(SafetyTipCategory.emergency).take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• ${tip.title}', style: const TextStyle(color: HulkaLook.ink)),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SafetyTipsScreen()),
                    );
                  },
                  child: const Text('Open health, emergency and outbreak tips'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Partner hospital ambulance',
          subtitle: 'Verified Hulka hospitals that published a dispatch line.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: locationNote,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Where should they find you?',
                  hintText: 'Estate, landmark, floor, gate colour',
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('ambulanceRequests')
                    .where('patientId', isEqualTo: uid)
                    .limit(8)
                    .snapshots(),
                builder: (context, snap) {
                  final open = snap.data?.docs
                          .where((d) => !['cancelled', 'arrived'].contains(d.data()['status']))
                          .toList() ??
                      const [];
                  if (open.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: open.map((doc) {
                      final d = doc.data();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.emergency_share_outlined, color: HulkaLook.ember),
                        title: Text((d['hospitalName'] as String?) ?? 'Ambulance'),
                        subtitle: Text('Status: ${d['status'] ?? 'requested'}'),
                        trailing: TextButton(
                          onPressed: () => cancelRequest(doc.id),
                          child: const Text('Cancel'),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('organizations')
                    .where('verified', isEqualTo: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final hospitals = snap.data!.docs.where((doc) {
                    final d = doc.data();
                    final type = (d['type'] as String?)?.toLowerCase() ?? '';
                    final phone = (d['ambulancePhone'] as String?) ?? (d['phone'] as String?) ?? '';
                    return phone.trim().isNotEmpty &&
                        (type.contains('hospital') || type.contains('clinic') || d['ambulanceAvailable'] == true);
                  }).toList();
                  if (hospitals.isEmpty) {
                    return const Text(
                      'No partner ambulance line is published yet. Call 999. An administrator can onboard hospital dispatch numbers.',
                    );
                  }
                  return Column(
                    children: hospitals.map((doc) {
                      final d = doc.data();
                      final phone = (d['ambulancePhone'] as String?) ?? (d['phone'] as String?) ?? '';
                      return Card(
                        elevation: 0,
                        color: HulkaLook.linen,
                        child: ListTile(
                          title: Text((d['name'] as String?) ?? 'Hospital'),
                          subtitle: Text(
                            [
                              if ((d['county'] as String?)?.isNotEmpty == true) d['county'],
                              phone,
                              if (d['ambulanceNotes'] != null) d['ambulanceNotes'],
                            ].join(' · '),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Call dispatch',
                                onPressed: () => _call(phone),
                                icon: const Icon(Icons.call),
                              ),
                              FilledButton(
                                onPressed: requesting ? null : () => requestAmbulance(d, doc.id),
                                child: const Text('Request'),
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
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('emergencyProfiles').doc(uid).snapshots(),
          builder: (context, snap) {
            populate(snap.data?.data());
            return HulkaBoard(
              title: 'Emergency health card',
              subtitle: 'Only what responders need. Separate from the full record.',
              child: Column(
                children: [
                  TextField(controller: bloodGroup, decoration: const InputDecoration(labelText: 'Blood group')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: allergies,
                    decoration: const InputDecoration(labelText: 'Critical allergies', helperText: 'Comma-separated'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: conditions,
                    decoration: const InputDecoration(labelText: 'Major conditions', helperText: 'Comma-separated'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: medications,
                    decoration: const InputDecoration(labelText: 'Current medications', helperText: 'Comma-separated'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: implants,
                    decoration: const InputDecoration(labelText: 'Implants / important devices'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: contactName, decoration: const InputDecoration(labelText: 'Emergency contact name')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Emergency contact phone'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: const Icon(Icons.emergency_outlined),
                    label: Text(saving ? 'Saving…' : 'Save emergency card'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
