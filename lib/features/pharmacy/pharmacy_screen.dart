import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../models/pharmacy.dart';
import 'prescription_screen.dart';
import 'dosage_reminders_screen.dart';
import '../../services/dosage_schedule.dart';
import '../../services/functions_service.dart';
import '../../services/pharmacy_matching_service.dart';
import '../../ui/hulka_board.dart';
import '../../ui/hulka_look.dart';

class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  final query = TextEditingController();
  final api = HulkaFunctions();
  final matcher = const PharmacyMatchingService();

  final rxGeneric = TextEditingController();
  final rxBrand = TextEditingController();
  final rxCode = TextEditingController();
  final rxStrength = TextEditingController();
  final rxForm = TextEditingController(text: 'tablet');
  final rxQuantity = TextEditingController(text: '1');
  final rxInstructions = TextEditingController();

  final doseMedicine = TextEditingController();
  final doseStrength = TextEditingController();
  final doseForm = TextEditingController(text: 'tablet');
  final doseInstructions = TextEditingController();
  final List<String> doseTimes = ['08:00', '20:00'];

  PlatformFile? pickedFile;
  bool busy = false;
  bool uploading = false;
  String? message;
  List<PharmacyMatch> uploadMatches = const [];

  @override
  void dispose() {
    query.dispose();
    rxGeneric.dispose();
    rxBrand.dispose();
    rxCode.dispose();
    rxStrength.dispose();
    rxForm.dispose();
    rxQuantity.dispose();
    rxInstructions.dispose();
    doseMedicine.dispose();
    doseStrength.dispose();
    doseForm.dispose();
    doseInstructions.dispose();
    super.dispose();
  }

  bool matchesPrescription(
    Map<String, dynamic> prescription,
    Map<String, dynamic> inventory,
  ) {
    String norm(Object? value) => value?.toString().trim().toLowerCase() ?? '';
    return norm(prescription['genericName']) ==
            norm(inventory['genericName']) &&
        norm(prescription['strength']) == norm(inventory['strength']) &&
        norm(prescription['form'] ?? prescription['doseForm']) ==
            norm(inventory['doseForm']);
  }

  PharmacyOffer offerFrom(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return PharmacyOffer(
      pharmacyId: (d['pharmacyId'] as String?) ?? doc.id,
      pharmacyName: (d['pharmacyName'] as String?) ?? 'Participating pharmacy',
      medicationCode: (d['medicationCode'] as String?) ?? '',
      genericName: (d['genericName'] as String?) ?? '',
      brandName: d['brandName'] as String?,
      strength: (d['strength'] as String?) ?? '',
      doseForm: (d['doseForm'] as String?) ?? '',
      availableQuantity: ((d['availableQuantity'] as num?) ?? 0).toInt(),
      price: (d['price'] as num?) ?? 0,
      currency: (d['currency'] as String?) ?? 'KES',
      updatedAt: DateTime.now(),
    );
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
      try {
        final orderId = await api.createPharmacyOrder({
          'prescriptionId': prescriptionId,
          'inventoryId': inventoryId,
          'quantity': quantity,
        });
        if (mounted) {
          setState(
            () => message =
                'Medicine reserved. Order $orderId remains subject to pharmacist review where substitution is involved.',
          );
        }
      } catch (_) {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final order = await FirebaseFirestore.instance
            .collection('pharmacyOrders')
            .add({
              'patientId': uid,
              'prescriptionId': prescriptionId,
              'inventoryId': inventoryId,
              'quantity': quantity,
              'status': 'reserved',
              'source': 'hulka',
              'createdAt': FieldValue.serverTimestamp(),
            });
        if (mounted) {
          setState(
            () => message =
                'Medicine reserved. Order ${order.id} is waiting for pharmacist review.',
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Could not reserve medicine: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickPrescription() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
    );
    if (result.isEmpty) return;
    setState(() {
      pickedFile = result.first;
      message =
          'Selected ${result.first.name}. Fill the medicine fields from the prescription, then match.';
    });
  }

  Future<void> uploadAndMatch() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final generic = rxGeneric.text.trim();
    if (generic.isEmpty || rxStrength.text.trim().isEmpty) {
      setState(
        () => message =
            'Enter at least the generic name and strength from the prescription.',
      );
      return;
    }
    setState(() {
      uploading = true;
      message = null;
    });
    try {
      String? storagePath;
      if (pickedFile != null) {
        try {
          final ext = (pickedFile!.extension ?? 'bin').toLowerCase();
          final ref = FirebaseStorage.instance.ref(
            'prescriptionUploads/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext',
          );
          await ref.putData(
            await pickedFile!.xFile.readAsBytes(),
            SettableMetadata(
              contentType: ext == 'pdf' ? 'application/pdf' : 'image/$ext',
            ),
          );
          storagePath = await ref.getDownloadURL();
        } catch (e) {
          debugPrint('prescription storage: $e');
        }
      }

      final item = PrescriptionItem(
        medicationCode: rxCode.text.trim().isEmpty
            ? generic.toLowerCase()
            : rxCode.text.trim(),
        genericName: generic,
        brandName: rxBrand.text.trim().isEmpty ? null : rxBrand.text.trim(),
        strength: rxStrength.text.trim(),
        doseForm: rxForm.text.trim(),
        quantity: int.tryParse(rxQuantity.text.trim()) ?? 1,
        instructions: rxInstructions.text.trim(),
      );

      final stock = await FirebaseFirestore.instance
          .collection('pharmacyInventory')
          .limit(200)
          .get();
      final catalog = await FirebaseFirestore.instance
          .collection('pharmaceuticalProducts')
          .limit(200)
          .get();
      final offers = stock.docs.map(offerFrom).toList();
      if (offers.isEmpty) {
        for (final doc in catalog.docs) {
          final d = doc.data();
          offers.add(
            PharmacyOffer(
              pharmacyId: 'catalog',
              pharmacyName: 'Hulka product catalog (no live stock yet)',
              medicationCode: (d['medicationCode'] as String?) ?? '',
              genericName: (d['genericName'] as String?) ?? '',
              brandName: d['brandName'] as String?,
              strength: (d['strength'] as String?) ?? '',
              doseForm: (d['doseForm'] as String?) ?? '',
              availableQuantity: 0,
              price: 0,
              currency: 'KES',
              updatedAt: DateTime.now(),
            ),
          );
        }
      }

      var matches = matcher.match(item, offers);
      if (matches.isEmpty) {
        final needle = generic.toLowerCase();
        matches = offers
            .where(
              (o) =>
                  o.genericName.toLowerCase().contains(needle) ||
                  (o.brandName?.toLowerCase().contains(needle) ?? false),
            )
            .map(
              (o) => PharmacyMatch(
                offer: o,
                isExact: false,
                reason:
                    'Name contains the prescribed medicine. Pharmacist must confirm strength and form.',
              ),
            )
            .toList();
      }

      final upload = await FirebaseFirestore.instance
          .collection('prescriptionUploads')
          .add({
            'patientId': uid,
            'fileName': pickedFile?.name,
            'fileUrl': storagePath,
            'genericName': item.genericName,
            'brandName': item.brandName,
            'medicationCode': item.medicationCode,
            'strength': item.strength,
            'form': item.doseForm,
            'quantity': item.quantity,
            'instructions': item.instructions,
            'status': matches.isEmpty ? 'unmatched' : 'matched',
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        setState(() {
          uploadMatches = matches;
          message = matches.isEmpty
              ? 'Prescription saved (${upload.id}). No shelf match yet.'
              : 'Prescription saved. ${matches.length} medicine match(es).';
        });
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Could not match prescription: $e');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> saveReminder() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (doseMedicine.text.trim().isEmpty || doseTimes.isEmpty) {
      setState(
        () => message = 'Add a medicine name and at least one clock time.',
      );
      return;
    }
    await FirebaseFirestore.instance
        .collection('patients')
        .doc(uid)
        .collection('dosageReminders')
        .add({
          'patientId': uid,
          'medicine': doseMedicine.text.trim(),
          'strength': doseStrength.text.trim(),
          'doseForm': doseForm.text.trim(),
          'instructions': doseInstructions.text.trim(),
          'times': List<String>.from(doseTimes),
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
    doseMedicine.clear();
    doseStrength.clear();
    doseInstructions.clear();
    if (mounted) setState(() => message = 'Dosage reminder saved.');
  }

  Future<void> markTaken(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('patients')
        .doc(uid)
        .collection('dosageReminders')
        .doc(id)
        .update({'lastTakenAt': FieldValue.serverTimestamp()});
  }

  Future<void> pickDoseTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    final label =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (!doseTimes.contains(label)) {
      setState(() {
        doseTimes.add(label);
        doseTimes.sort();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Authentication required.'));
    }

    final prescriptions = FirebaseFirestore.instance
        .collection('prescriptions')
        .where('patientId', isEqualTo: uid)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Wrap(
          spacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrescriptionScreen(),
                ),
              ),
              icon: const Icon(Icons.upload_file),
              label: const Text('Prescriptions'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DosageRemindersScreen(),
                ),
              ),
              icon: const Icon(Icons.alarm),
              label: const Text('Dosage reminders'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Pharmacy',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: HulkaLook.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Upload a prescription, match it to partner stock, and keep dosage times on this record. '
          'Brand substitution still needs pharmacist review.',
          style: TextStyle(color: HulkaLook.atrium, height: 1.35),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(
            message!,
            style: const TextStyle(color: HulkaLook.atrium, height: 1.35),
          ),
        ],
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Dosage reminders',
          subtitle:
              'Times are kept on your Hulka record. Mark a dose when you take it.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('patients')
                    .doc(uid)
                    .collection('dosageReminders')
                    .snapshots(),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? const [];
                  if (docs.isEmpty) {
                    return const Text(
                      'No reminders yet. Add the medicines you take each day.',
                    );
                  }
                  final now = DateTime.now();
                  return Column(
                    children: docs.map((doc) {
                      final d = doc.data();
                      final times = ((d['times'] as List?) ?? const [])
                          .map((e) => e.toString())
                          .toList();
                      final last = d['lastTakenAt'];
                      DateTime? lastAt;
                      if (last is Timestamp) lastAt = last.toDate();
                      final next = DosageSchedule.nextDose(times, now);
                      final taken = DosageSchedule.takenToday(lastAt, now);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          taken ? Icons.check_circle : Icons.alarm,
                          color: taken ? HulkaLook.pulse : HulkaLook.copper,
                        ),
                        title: Text(
                          '${d['medicine'] ?? ''} ${d['strength'] ?? ''}',
                        ),
                        subtitle: Text(
                          [
                            if (times.isNotEmpty) 'At ${times.join(', ')}',
                            if (next != null)
                              'Next ${DosageSchedule.formatClock(next)}',
                            if (d['instructions'] != null) d['instructions'],
                          ].join('. '),
                        ),
                        trailing: TextButton(
                          onPressed: () => markTaken(doc.id),
                          child: Text(taken ? 'Taken' : 'Mark taken'),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: doseMedicine,
                decoration: const InputDecoration(labelText: 'Medicine'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: doseStrength,
                      decoration: const InputDecoration(labelText: 'Strength'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: doseForm,
                      decoration: const InputDecoration(labelText: 'Form'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doseInstructions,
                decoration: const InputDecoration(labelText: 'Instructions'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in doseTimes)
                    InputChip(
                      label: Text(t),
                      onDeleted: () => setState(() => doseTimes.remove(t)),
                    ),
                  ActionChip(
                    label: const Text('Add time'),
                    onPressed: pickDoseTime,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: saveReminder,
                icon: const Icon(Icons.alarm_add),
                label: const Text('Save reminder'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Upload a prescription',
          subtitle:
              'Photo or PDF, then the medicine line as written. Hulka matches generic, strength and form.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: pickPrescription,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                  pickedFile == null ? 'Choose photo or PDF' : pickedFile!.name,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rxGeneric,
                decoration: const InputDecoration(labelText: 'Generic name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rxBrand,
                decoration: const InputDecoration(
                  labelText: 'Brand (if written)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rxStrength,
                      decoration: const InputDecoration(labelText: 'Strength'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: rxForm,
                      decoration: const InputDecoration(labelText: 'Form'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rxCode,
                      decoration: const InputDecoration(
                        labelText: 'Code (optional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: rxQuantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rxInstructions,
                decoration: const InputDecoration(labelText: 'Directions'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: uploading ? null : uploadAndMatch,
                icon: const Icon(Icons.medication_outlined),
                label: Text(uploading ? 'Matching…' : 'Match medicine'),
              ),
              if (uploadMatches.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final match in uploadMatches.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      match.isExact
                          ? Icons.check_circle_outline
                          : Icons.science_outlined,
                      color: match.isExact ? HulkaLook.pulse : HulkaLook.copper,
                    ),
                    title: Text(
                      '${match.offer.genericName} ${match.offer.strength}',
                    ),
                    subtitle: Text(
                      '${match.offer.pharmacyName}. ${match.reason}'
                      '${match.offer.availableQuantity > 0 ? ' Stock ${match.offer.availableQuantity}.' : ''}',
                    ),
                    trailing: match.offer.availableQuantity > 0
                        ? Text('${match.offer.currency} ${match.offer.price}')
                        : const Text('Catalog'),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
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
              return const HulkaBoard(
                title: 'Clinician prescriptions',
                child: Text(
                  'A verified clinician can also issue a prescription. Uploaded photos above are matched against stock in the meantime.',
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

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: HulkaBoard(
                        title:
                            '${prescription['genericName'] ?? 'Medicine'} ${prescription['strength'] ?? ''}',
                        subtitle:
                            'Form: ${prescription['form'] ?? ''}  Quantity: ${prescription['quantity'] ?? ''}',
                        child: Column(
                          children: [
                            if (matches.isEmpty)
                              const Text(
                                'No matching pharmacy stock currently reported.',
                              )
                            else
                              ...matches.map((stockDoc) {
                                final stock = stockDoc.data();
                                final quantity =
                                    ((prescription['quantity'] as num?) ?? 1)
                                        .toInt();
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.local_pharmacy_outlined,
                                  ),
                                  title: Text(
                                    (stock['pharmacyName'] as String?) ??
                                        'Participating pharmacy',
                                  ),
                                  subtitle: Text(
                                    '${stock['brandName'] ?? stock['genericName'] ?? ''}  '
                                    'Stock: ${stock['availableQuantity'] ?? 0}',
                                  ),
                                  trailing: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
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
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Browse inventory',
          child: Column(
            children: [
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
                        '${x['genericName'] ?? ''} ${x['brandName'] ?? ''}'
                            .toLowerCase();
                    return needle.isEmpty || hay.contains(needle);
                  }).toList();

                  if (docs.isEmpty) {
                    return const Text('No matching stock reported.');
                  }

                  return Column(
                    children: docs.map((doc) {
                      final d = doc.data();
                      return ListTile(
                        leading: const Icon(Icons.medication_outlined),
                        title: Text(
                          (d['genericName'] as String?) ?? 'Medicine',
                        ),
                        subtitle: Text(
                          '${d['strength'] ?? ''}  ${d['doseForm'] ?? ''}  ${d['pharmacyName'] ?? 'Pharmacy'}',
                        ),
                        trailing: Text(
                          '${d['currency'] ?? ''} ${d['price'] ?? ''}',
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
