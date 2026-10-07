import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  final query = TextEditingController();
  final api = HulkaFunctions();
  bool busy = false;
  String? message;

  bool matchesPrescription(
    Map<String, dynamic> prescription,
    Map<String, dynamic> inventory,
  ) {
    String norm(Object? value) => value?.toString().trim().toLowerCase() ?? '';
    return norm(prescription['genericName']) == norm(inventory['genericName']) &&
        norm(prescription['strength']) == norm(inventory['strength']) &&
        norm(prescription['form']) == norm(inventory['doseForm']);
  }

  Future<void> reserve({
    required String prescriptionId,
    required String inventoryId,
    required int quantity,
  }) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final orderId = await api.createPharmacyOrder({
        'prescriptionId': prescriptionId,
        'inventoryId': inventoryId,
        'quantity': quantity,
      });
      if (mounted) {
        setState(() => message =
            'Medicine reserved. Order $orderId will remain subject to pharmacist review where substitution is involved.');
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Could not reserve medicine: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));

    final prescriptions = FirebaseFirestore.instance
        .collection('prescriptions')
        .where('patientId', isEqualTo: uid)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Prescription & Pharmacy',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Hulka matches active prescriptions to available stock by generic medicine, '
          'strength and dose form. Brand substitution remains subject to the prescription '
          'and pharmacist review.',
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!),
        ],
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: prescriptions,
          builder: (context, prescriptionSnap) {
            if (!prescriptionSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final activePrescriptions = prescriptionSnap.data!.docs
                .where((d) => (d.data()['status'] as String?) == 'active')
                .toList();

            if (activePrescriptions.isEmpty) {
              return const Card(
                child: ListTile(
                  title: Text('No active prescriptions'),
                  subtitle: Text(
                    'A verified clinician must issue a prescription before Hulka can reserve prescription medicine.',
                  ),
                ),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('pharmacyInventory')
                  .snapshots(),
              builder: (context, inventorySnap) {
                if (!inventorySnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final inventory = inventorySnap.data!.docs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: activePrescriptions.map((prescriptionDoc) {
                    final prescription = prescriptionDoc.data();
                    final matches = inventory.where((stockDoc) {
                      final stock = stockDoc.data();
                      return matchesPrescription(prescription, stock) &&
                          ((stock['availableQuantity'] as num?) ?? 0) > 0;
                    }).toList();

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${prescription['genericName'] ?? 'Medicine'} ${prescription['strength'] ?? ''}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Form: ${prescription['form'] ?? ''} • Quantity prescribed: ${prescription['quantity'] ?? ''}',
                            ),
                            const SizedBox(height: 12),
                            if (matches.isEmpty)
                              const Text('No matching pharmacy stock currently reported.')
                            else
                              ...matches.map((stockDoc) {
                                final stock = stockDoc.data();
                                final quantity =
                                    ((prescription['quantity'] as num?) ?? 1).toInt();
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.local_pharmacy_outlined),
                                  title: Text(
                                    (stock['pharmacyName'] as String?) ??
                                        'Participating pharmacy',
                                  ),
                                  subtitle: Text(
                                    '${stock['brandName'] ?? stock['genericName'] ?? ''} • '
                                    'Stock: ${stock['availableQuantity'] ?? 0}',
                                  ),
                                  trailing: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      Text(
                                        '${stock['currency'] ?? ''} ${stock['price'] ?? ''}',
                                      ),
                                      FilledButton(
                                        onPressed: busy
                                            ? null
                                            : () => reserve(
                                                  prescriptionId:
                                                      prescriptionDoc.id,
                                                  inventoryId: stockDoc.id,
                                                  quantity: quantity,
                                                ),
                                        child: const Text('Reserve'),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
        const SizedBox(height: 28),
        Text('Browse inventory', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: query,
          decoration: const InputDecoration(
            labelText: 'Medicine or generic name',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('pharmacyInventory')
              .limit(100)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final needle = query.text.trim().toLowerCase();
            final docs = snap.data!.docs.where((d) {
              final x = d.data();
              final hay =
                  '${x['genericName'] ?? ''} ${x['brandName'] ?? ''}'.toLowerCase();
              return needle.isEmpty || hay.contains(needle);
            }).toList();

            if (docs.isEmpty) return const Text('No matching stock reported.');

            return Column(
              children: docs.map((doc) {
                final d = doc.data();
                return ListTile(
                  leading: const Icon(Icons.medication_outlined),
                  title: Text((d['genericName'] as String?) ?? 'Medicine'),
                  subtitle: Text(
                    '${d['strength'] ?? ''} • ${d['doseForm'] ?? ''} • '
                    '${d['pharmacyName'] ?? 'Pharmacy'}',
                  ),
                  trailing: Text('${d['currency'] ?? ''} ${d['price'] ?? ''}'),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
