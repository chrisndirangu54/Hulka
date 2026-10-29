import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../ui/hulka_board.dart';
import '../../ui/hulka_look.dart';

class HospitalDirectoryScreen extends StatefulWidget {
  const HospitalDirectoryScreen({super.key});

  @override
  State<HospitalDirectoryScreen> createState() => _HospitalDirectoryScreenState();
}

class _HospitalDirectoryScreenState extends State<HospitalDirectoryScreen> {
  final name = TextEditingController();
  final kind = TextEditingController(text: 'hospital');
  final email = TextEditingController();
  final phone = TextEditingController();
  final note = TextEditingController();
  bool sending = false;
  String? message;

  @override
  void dispose() {
    name.dispose();
    kind.dispose();
    email.dispose();
    phone.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> apply() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (name.text.trim().isEmpty) {
      setState(() => message = 'Name of the hospital, clinic, doctor or pharmacy is required.');
      return;
    }
    setState(() {
      sending = true;
      message = null;
    });
    try {
      await FirebaseFirestore.instance.collection('partnerApplications').add({
        'applicantUid': uid,
        'kind': kind.text.trim(),
        'organizationName': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'note': note.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      name.clear();
      note.clear();
      if (mounted) setState(() => message = 'Application sent. An administrator will review it.');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not send application: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text(
          'Care network',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: HulkaLook.ink),
        ),
        const SizedBox(height: 8),
        const Text(
          'Verified hospitals, clinics, laboratories, pharmacies and insurers on Hulka.',
          style: TextStyle(color: HulkaLook.atrium, height: 1.35),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('organizations')
              .where('verified', isEqualTo: true)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) {
              return const Text('No verified organisations yet.');
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                final ambulance = (d['ambulancePhone'] as String?) ?? '';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_hospital_outlined, color: HulkaLook.pulse),
                    title: Text((d['name'] as String?) ?? 'Healthcare organization'),
                    subtitle: Text(
                      [
                        d['type'] ?? '',
                        if ((d['county'] as String?)?.isNotEmpty == true) d['county'],
                        if (ambulance.isNotEmpty) 'Ambulance $ambulance',
                      ].join(', '),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        const Text('Onboarded doctors', style: TextStyle(fontWeight: FontWeight.w600, color: HulkaLook.ink)),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('clinicianDirectory').limit(40).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 16),
                child: Text('No directory doctors yet.'),
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return ListTile(
                  leading: const Icon(Icons.medical_services_outlined),
                  title: Text((d['displayName'] as String?) ?? 'Clinician'),
                  subtitle: Text('${d['specialty'] ?? ''}  ${d['organizationName'] ?? ''}'),
                );
              }).toList(),
            );
          },
        ),
        HulkaBoard(
          title: 'Apply to join the network',
          subtitle: 'Hospitals, clinics, doctors, pharmacies and manufacturers. Admin reviews on the Administration tab.',
          child: Column(
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Organisation or practitioner name')),
              const SizedBox(height: 12),
              TextField(
                controller: kind,
                decoration: const InputDecoration(
                  labelText: 'Kind',
                  hintText: 'hospital, clinic, doctor, pharmacy, manufacturer',
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Licence, county, ambulance line, products…'),
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(message!, style: const TextStyle(color: HulkaLook.atrium)),
              ],
              const SizedBox(height: 12),
              FilledButton(onPressed: sending ? null : apply, child: Text(sending ? 'Sending…' : 'Submit application')),
            ],
          ),
        ),
      ],
    );
  }
}
