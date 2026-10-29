import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../models/pharmacy.dart';
import '../../services/functions_service.dart';
import '../../services/pharmacy_matching_service.dart';
import '../../ui/hulka_board.dart';
import '../../ui/hulka_look.dart';
import 'dosage_reminders_screen.dart';

/// Two-tab screen: "Upload" (pick prescription photo + manually enter medicine)
/// and "Matches" (stream saved prescription items and show pharmacy matches).
class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Authentication required.')),
      );
    }

    return Scaffold(
      backgroundColor: HulkaLook.linen,
      appBar: AppBar(
        title: const Text('Prescriptions'),
        backgroundColor: HulkaLook.paper,
        foregroundColor: HulkaLook.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: HulkaLook.pulse,
          unselectedLabelColor: HulkaLook.atrium,
          indicatorColor: HulkaLook.pulse,
          tabs: const [
            Tab(text: 'Upload'),
            Tab(text: 'Matches'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _UploadTab(uid: _uid, onSaved: () => _tabs.animateTo(1)),
          _MatchesTab(uid: _uid),
        ],
      ),
    );
  }
}

// ── Upload tab ───────────────────────────────────────────────────────────────

class _UploadTab extends StatefulWidget {
  const _UploadTab({required this.uid, required this.onSaved});

  final String uid;
  final VoidCallback onSaved;

  @override
  State<_UploadTab> createState() => _UploadTabState();
}

class _UploadTabState extends State<_UploadTab> {
  // Manual entry controllers
  final _rxCode = TextEditingController();
  final _rxGeneric = TextEditingController();
  final _rxBrand = TextEditingController();
  final _rxStrength = TextEditingController();
  final _rxForm = TextEditingController(text: 'tablet');
  final _rxQuantity = TextEditingController(text: '1');
  final _rxInstructions = TextEditingController();
  bool _substitutionAllowed = true;

  PlatformFile? _pickedFile;
  bool _uploading = false;
  String? _message;

  @override
  void dispose() {
    _rxCode.dispose();
    _rxGeneric.dispose();
    _rxBrand.dispose();
    _rxStrength.dispose();
    _rxForm.dispose();
    _rxQuantity.dispose();
    _rxInstructions.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> _uploadsRef() => FirebaseFirestore
      .instance
      .collection('prescriptionUploads')
      .doc(widget.uid)
      .collection('uploads');

  CollectionReference<Map<String, dynamic>> _itemsRef() => FirebaseFirestore
      .instance
      .collection('prescriptionUploads')
      .doc(widget.uid)
      .collection('items');

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
    );
    if (result.isEmpty) return;
    setState(() {
      _pickedFile = result.first;
      _message = 'Selected ${_pickedFile!.name}. Fill the fields and tap Save.';
    });
  }

  Future<void> _save() async {
    final generic = _rxGeneric.text.trim();
    if (generic.isEmpty || _rxStrength.text.trim().isEmpty) {
      setState(
        () => _message = 'Enter at least the generic name and strength.',
      );
      return;
    }
    final quantity = int.tryParse(_rxQuantity.text.trim());
    if (quantity == null ||
        quantity <= 0 ||
        (_pickedFile != null &&
            (await _pickedFile!.xFile.length() > 10 * 1024 * 1024))) {
      setState(
        () => _message =
            'Enter a positive quantity and choose a file smaller than 10 MB.',
      );
      return;
    }
    setState(() {
      _uploading = true;
      _message = null;
    });
    try {
      // 1. Upload image/PDF to Firebase Storage
      String? storageUrl;
      if (_pickedFile != null) {
        try {
          final ext = (_pickedFile!.extension ?? 'bin').toLowerCase();
          final ref = FirebaseStorage.instance.ref(
            'prescriptionUploads/${widget.uid}/${DateTime.now().millisecondsSinceEpoch}.$ext',
          );
          await ref.putData(
            await _pickedFile!.xFile.readAsBytes(),
            SettableMetadata(
              contentType: ext == 'pdf'
                  ? 'application/pdf'
                  : ext == 'jpg'
                  ? 'image/jpeg'
                  : 'image/$ext',
            ),
          );
          storageUrl = await ref.getDownloadURL();
        } catch (e) {
          throw StateError('Upload failed. Please retry: $e');
        }
      }

      // 2. Save upload metadata
      final uploadRef = await _uploadsRef().add({
        'storageUrl': storageUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'extractedItems': <String>[],
        if (_pickedFile != null) 'fileName': _pickedFile!.name,
      });

      // 3. Save prescription item and trigger matching
      final code = _rxCode.text.trim().isEmpty
          ? generic.toLowerCase()
          : _rxCode.text.trim();

      await _itemsRef().add({
        'medicationCode': code,
        'genericName': generic,
        'brandName': _rxBrand.text.trim().isEmpty ? null : _rxBrand.text.trim(),
        'strength': _rxStrength.text.trim(),
        'doseForm': _rxForm.text.trim(),
        'quantity': quantity,
        'patientId': widget.uid,
        'instructions': _rxInstructions.text.trim(),
        'substitutionAllowed': _substitutionAllowed,
        'uploadId': uploadRef.id,
        'storageUrl': storageUrl,
        'savedAt': FieldValue.serverTimestamp(),
      });

      // 4. Mark upload as processed
      await uploadRef.update({'status': 'saved'});

      if (mounted) {
        setState(() {
          _message =
              'Prescription saved. Switch to the Matches tab to see pharmacy stock.';
          _pickedFile = null;
        });
        _rxCode.clear();
        _rxGeneric.clear();
        _rxBrand.clear();
        _rxStrength.clear();
        _rxForm.text = 'tablet';
        _rxQuantity.text = '1';
        _rxInstructions.clear();
        setState(() => _substitutionAllowed = true);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not save prescription: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Existing uploads
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _uploadsRef()
              .orderBy('uploadedAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) return const SizedBox.shrink();
            return HulkaBoard(
              title: 'Previous uploads',
              child: Column(
                children: docs.map((d) {
                  final data = d.data();
                  final status = (data['status'] as String?) ?? 'pending';
                  final ts = data['uploadedAt'];
                  String dateStr = '';
                  if (ts is Timestamp) {
                    final dt = ts.toDate();
                    dateStr =
                        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                  }
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      status == 'saved'
                          ? Icons.check_circle_outline
                          : Icons.hourglass_empty,
                      color: status == 'saved'
                          ? HulkaLook.pulse
                          : HulkaLook.copper,
                    ),
                    title: Text(
                      (data['fileName'] as String?) ?? 'Prescription',
                    ),
                    subtitle: Text('$dateStr · $status'),
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Upload section
        HulkaBoard(
          title: 'Upload prescription photo',
          subtitle: 'Optional — pick a photo or PDF of your prescription.',
          child: OutlinedButton.icon(
            onPressed: _uploading ? null : _pickFile,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              _pickedFile == null ? 'Choose photo or PDF' : _pickedFile!.name,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Manual entry
        HulkaBoard(
          title: 'Parse manually',
          subtitle: 'Enter the medicine details from your prescription.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _rxGeneric,
                decoration: const InputDecoration(labelText: 'Generic name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rxBrand,
                decoration: const InputDecoration(
                  labelText: 'Brand name (if written)',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rxStrength,
                      decoration: const InputDecoration(
                        labelText: 'Strength *',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _rxForm,
                      decoration: const InputDecoration(labelText: 'Dose form'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rxCode,
                      decoration: const InputDecoration(
                        labelText: 'Medication code (optional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _rxQuantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rxInstructions,
                decoration: const InputDecoration(labelText: 'Instructions'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _substitutionAllowed,
                onChanged: (v) =>
                    setState(() => _substitutionAllowed = v ?? true),
                title: const Text('Substitution allowed'),
                subtitle: const Text(
                  'Pharmacist may dispense a generic equivalent if ticked.',
                ),
                contentPadding: EdgeInsets.zero,
                activeColor: HulkaLook.pulse,
              ),
              const SizedBox(height: 12),
              if (_message != null) ...[
                Text(
                  _message!,
                  style: const TextStyle(color: HulkaLook.atrium, height: 1.35),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: _uploading ? null : _save,
                icon: const Icon(Icons.medication_outlined),
                label: Text(_uploading ? 'Saving…' : 'Save & match'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Matches tab ──────────────────────────────────────────────────────────────

class _MatchesTab extends StatelessWidget {
  _MatchesTab({required this.uid});

  final String uid;

  final Map<PharmacyOffer, String> offerIds = {};

  static const _matcher = PharmacyMatchingService();
  static final _functions = HulkaFunctions();

  CollectionReference<Map<String, dynamic>> get _itemsRef => FirebaseFirestore
      .instance
      .collection('prescriptionUploads')
      .doc(uid)
      .collection('items');

  PharmacyOffer _offerFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final offer = PharmacyOffer(
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
      requiresPharmacistReview:
          (d['requiresPharmacistReview'] as bool?) ?? false,
    );
    offerIds[offer] = doc.id;
    return offer;
  }

  Future<void> _order(
    BuildContext context,
    String prescriptionItemId,
    PharmacyOffer offer,
    int quantity,
  ) async {
    try {
      final orderId = await _functions.createPharmacyOrder({
        'uploadItemId': prescriptionItemId,
        'inventoryId': offerIds[offer],
        'pharmacyId': offer.pharmacyId,
        'medicationCode': offer.medicationCode,
        'quantity': quantity,
        'currency': offer.currency,
        'price': offer.price,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Order placed. ID: $orderId')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not place order: $e')));
      }
    }
  }

  void _openAddReminderSheet(
    BuildContext context,
    Map<String, dynamic> itemData,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DosageRemindersScreen(prescription: itemData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _itemsRef.orderBy('savedAt', descending: true).snapshots(),
      builder: (context, itemSnap) {
        if (itemSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (itemSnap.hasError) {
          return const Center(
            child: Text('Unable to load prescriptions. Please retry.'),
          );
        }
        final items = itemSnap.data?.docs ?? const [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_pharmacy_outlined,
                    size: 56,
                    color: HulkaLook.copper.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No prescriptions saved yet.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HulkaLook.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Go to the Upload tab to enter your prescription details.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: HulkaLook.atrium, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('pharmacyInventory')
              .limit(300)
              .snapshots(),
          builder: (context, invSnap) {
            if (invSnap.hasError) {
              return const Center(
                child: Text('Unable to load pharmacy stock. Please retry.'),
              );
            }
            final inventoryDocs = invSnap.data?.docs ?? const [];
            offerIds.clear();
            final offers = inventoryDocs.map(_offerFromDoc).toList();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final itemDoc = items[i];
                final itemData = itemDoc.data();
                final prescribed = PrescriptionItem(
                  medicationCode: (itemData['medicationCode'] as String?) ?? '',
                  genericName: (itemData['genericName'] as String?) ?? '',
                  brandName: itemData['brandName'] as String?,
                  strength: (itemData['strength'] as String?) ?? '',
                  doseForm: (itemData['doseForm'] as String?) ?? '',
                  quantity: ((itemData['quantity'] as num?) ?? 1).toInt(),
                  instructions: (itemData['instructions'] as String?) ?? '',
                  substitutionAllowed:
                      (itemData['substitutionAllowed'] as bool?) ?? true,
                );

                List<PharmacyMatch> matches;
                if (invSnap.connectionState == ConnectionState.waiting) {
                  matches = const [];
                } else {
                  matches = _matcher.match(prescribed, offers);
                }

                return _PrescriptionItemCard(
                  itemDoc: itemDoc,
                  prescribed: prescribed,
                  matches: matches,
                  loadingInventory:
                      invSnap.connectionState == ConnectionState.waiting,
                  onOrder: (offer) =>
                      _order(context, itemDoc.id, offer, prescribed.quantity),
                  onAddReminder: () => _openAddReminderSheet(context, {
                    ...itemData,
                    'id': itemDoc.id,
                  }),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Prescription item card ───────────────────────────────────────────────────

class _PrescriptionItemCard extends StatelessWidget {
  const _PrescriptionItemCard({
    required this.itemDoc,
    required this.prescribed,
    required this.matches,
    required this.loadingInventory,
    required this.onOrder,
    required this.onAddReminder,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> itemDoc;
  final PrescriptionItem prescribed;
  final List<PharmacyMatch> matches;
  final bool loadingInventory;
  final ValueChanged<PharmacyOffer> onOrder;
  final VoidCallback onAddReminder;

  @override
  Widget build(BuildContext context) {
    final data = itemDoc.data();
    return HulkaBoard(
      title:
          '${prescribed.genericName}${prescribed.strength.isNotEmpty ? '  ${prescribed.strength}' : ''}',
      subtitle: [
        prescribed.doseForm,
        'Qty ${prescribed.quantity}',
        if ((data['instructions'] as String?)?.isNotEmpty == true)
          data['instructions'] as String,
      ].where((s) => s.isNotEmpty).join(' · '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Add dosage reminder button
          OutlinedButton.icon(
            onPressed: onAddReminder,
            icon: const Icon(Icons.alarm_add, size: 18),
            label: const Text('Add dosage reminder'),
            style: OutlinedButton.styleFrom(
              foregroundColor: HulkaLook.pulse,
              side: BorderSide(color: HulkaLook.pulse.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Match results
          if (loadingInventory) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ] else if (matches.isEmpty) ...[
            const Text(
              'No pharmacy stock matched. Try again later or contact a pharmacist.',
              style: TextStyle(color: HulkaLook.atrium, height: 1.35),
            ),
          ] else ...[
            const Text(
              'Pharmacy matches',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: HulkaLook.ink,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ...matches
                .take(6)
                .map(
                  (m) => _MatchCard(
                    match: m,
                    prescribedQty: prescribed.quantity,
                    onOrder: () => onOrder(m.offer),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.prescribedQty,
    required this.onOrder,
  });

  final PharmacyMatch match;
  final int prescribedQty;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    final offer = match.offer;
    final borderColor = match.isExact
        ? const Color(0xFF2E7D32) // green
        : const Color(0xFFF57C00); // amber

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HulkaLook.linen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                match.isExact ? Icons.check_circle : Icons.science_outlined,
                color: borderColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${offer.genericName} ${offer.strength}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: HulkaLook.ink,
                  ),
                ),
              ),
              Text(
                '${offer.currency} ${offer.price}',
                style: const TextStyle(
                  color: HulkaLook.atrium,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            offer.pharmacyName,
            style: const TextStyle(color: HulkaLook.atrium, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            match.reason,
            style: TextStyle(
              color: HulkaLook.atrium.withValues(alpha: 0.8),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          if (offer.availableQuantity > 0) ...[
            const SizedBox(height: 2),
            Text(
              'In stock: ${offer.availableQuantity}',
              style: const TextStyle(color: HulkaLook.atrium, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: offer.availableQuantity > 0
                ? FilledButton(
                    onPressed: onOrder,
                    style: FilledButton.styleFrom(
                      backgroundColor: HulkaLook.pulse,
                      foregroundColor: HulkaLook.ink,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Order'),
                  )
                : OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Out of stock'),
                  ),
          ),
        ],
      ),
    );
  }
}
