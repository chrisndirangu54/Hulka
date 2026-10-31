import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../ui/health_workspace.dart';

/// Patient-owned document intake. External hospital links are requests only:
/// patient IDs are never treated as credentials or sufficient authorization.
class PatientRecordsScreen extends StatefulWidget {
  const PatientRecordsScreen({super.key});
  @override
  State<PatientRecordsScreen> createState() => _PatientRecordsScreenState();
}

class _PatientRecordsScreenState extends State<PatientRecordsScreen> {
  final hospital = TextEditingController();
  final externalId = TextEditingController();
  bool consent = false;
  bool busy = false;
  String? status;
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    hospital.dispose();
    externalId.dispose();
    super.dispose();
  }

  Future<void> upload() async {
    final id = uid;
    if (id == null) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (picked.isEmpty) return;
    final file = picked.single;
    final fileSize = file.lengthSync() ?? await file.length();
    if (fileSize == null || fileSize <= 0 || fileSize > 10 * 1024 * 1024) {
      if (mounted) setState(() => status = 'Select a readable document smaller than 10 MB.');
      return;
    }
    if (!mounted) return;
    setState(() { busy = true; status = null; });
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('Invalid file size.');
      }
      final ref = FirebaseStorage.instance.ref('patients/$id/consultations/${const Uuid().v4()}/document');
      await ref.putData(bytes, SettableMetadata(
        contentType: file.extension?.toLowerCase() == 'pdf'
          ? 'application/pdf'
          : file.extension?.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg',
        customMetadata: {'patientId': id, 'originalFilename': file.name},
      ));
      await FirebaseFirestore.instance.collection('patients').doc(id).collection('timeline').add({
        'title': 'Consultation document uploaded',
        'summary': file.name,
        'type': 'patientDocument',
        'storagePath': ref.fullPath,
        'provenance': 'patientUpload',
        'reviewStatus': 'unverified',
        'occurredAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => status = 'Uploaded. A clinician must verify the document before relying on it.');
    } catch (_) {
      if (mounted) setState(() => status = 'Upload failed. Check your connection and permissions.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestImport() async {
    final id = uid;
    if (id == null || hospital.text.trim().isEmpty || externalId.text.trim().isEmpty || !consent) return;
    setState(() { busy = true; status = null; });
    try {
      await FirebaseFirestore.instance.collection('patients').doc(id).collection('importRequests').add({
        'sourceSystem': 'TeknTandao Workspace',
        'hospitalName': hospital.text.trim(),
        'externalPatientId': externalId.text.trim(),
        'patientId': id,
        'consentAcknowledged': true,
        'status': 'pendingVerification',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => status = 'Import request recorded; no hospital data was accessed. Hospital identity matching and authorized integration are required.');
    } catch (_) {
      if (mounted) setState(() => status = 'Unable to save import request.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }


  Future<void> importExportFile() async {
    final id = uid;
    if (id == null || !consent) {
      setState(() => status = 'Confirm authorization before importing.');
      return;
    }
    final picked = await FilePicker.pickFiles(
      type: FileType.custom, allowedExtensions: ['json']);
    if (picked == null || picked.isEmpty) return;
    final file = picked.single;
    final fileSize = file.lengthSync() ?? await file.length();
    if (fileSize == null || fileSize <= 0 || fileSize > 1024 * 1024) {
      if (mounted) setState(() => status = 'Select a readable hospital JSON export smaller than 1 MB.');
      return;
    }
    if (!mounted) return;
    setState(() { busy = true; status = null; });
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 1024 * 1024) {
        throw const FormatException('Invalid export size.');
      }
      final payload = jsonDecode(utf8.decode(bytes));
      if (payload is! Map<String, dynamic> ||
          payload['schema'] != 'hulka.hospital-history.v1' ||
          payload['source'] != 'TeknTandao Workspace' ||
          payload['records'] is! List) {
        throw const FormatException('Unsupported hospital export.');
      }
      final entries = payload['records'] as List;
      if (entries.length > 100) throw const FormatException('Export exceeds 100 records.');
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('patients').doc(id).collection('timeline');
      final receipt = const Uuid().v4();
      const allowedKinds = {'appointment', 'encounter', 'prescription', 'labReport', 'labTest', 'diagnosis', 'observation', 'procedure'};
      for (final raw in entries) {
        if (raw is! Map<String, dynamic>) throw const FormatException('Invalid clinical record.');
        final title = raw['title'];
        final kind = raw['kind'];
        if (title is! String || title.isEmpty || title.length > 200 || kind is! String || !allowedKinds.contains(kind)) {
          throw const FormatException('Malformed clinical record.');
        }
        batch.set(collection.doc(), {
          'title': title, 'summary': kind, 'type': 'importedHospitalHistory',
          'sourceSystem': 'TeknTandao Workspace',
          'sourceOrganizationId': (payload['organizationId'] ?? '').toString(),
          'importReceipt': receipt,
          'sourceEventId': (raw['id'] ?? '').toString().substring(0, (raw['id'] ?? '').toString().length.clamp(0, 128)),
          'provenance': 'patientSuppliedExport',
          'reviewStatus': 'unverified',
          'occurredAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (mounted) setState(() => status = 'Imported ${entries.length} summary records as unverified patient-provided history. A clinician must reconcile them.');
    } catch (_) {
      if (mounted) setState(() => status = 'Invalid export, or import failed. No records were confirmed.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) return const Center(child: Text('Sign in to access records.'));
    return Scaffold(
      appBar: AppBar(title: const Text('My medical records')),
      body: HealthPageBody(children: [
        Text('Carry your medical history forward', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text('Upload consultation documents to your private health timeline. Uploaded documents are patient-supplied and remain unverified until reviewed by a clinician.'),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: busy ? null : upload, icon: const Icon(Icons.upload_file), label: const Text('Upload consultation PDF or image')),
        const SizedBox(height: 28),
        Text('Request hospital history import', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('For hospitals using TeknTandao Workspace. This records a request only; hospital verification, patient matching, explicit scoped consent, and secure server-to-server exchange must be configured before any transfer.'),
        const SizedBox(height: 12),
        TextField(controller: hospital, decoration: const InputDecoration(labelText: 'Hospital / facility name')),
        const SizedBox(height: 10),
        TextField(controller: externalId, decoration: const InputDecoration(labelText: 'Hospital patient ID')),
        const SizedBox(height: 10),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: consent,
          onChanged: busy ? null : (value) => setState(() => consent = value ?? false),
          title: const Text('I authorize Hulka to request verification of my identity and an appropriately scoped medical-record transfer from this hospital.'),
        ),
        FilledButton(onPressed: busy || !consent ? null : requestImport, child: const Text('Request authorized import')),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: busy || !consent ? null : importExportFile, icon: const Icon(Icons.file_download_outlined), label: const Text('Import hospital JSON export')),
        const Text('Manual import is available; this is not an automatic hospital connection. Imported summaries require clinical verification.'),
        if (status != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(status!)),
        const SizedBox(height: 24),
        StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
          stream: FirebaseFirestore.instance.collection('patients').doc(uid).collection('importRequests').orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snap) => Column(children: [
            for (final d in snap.data?.docs ?? <QueryDocumentSnapshot<Map<String,dynamic>>>[])
              ListTile(leading: const Icon(Icons.history), title: Text(d.data()['hospitalName']?.toString() ?? 'Hospital'),
                subtitle: Text('Import: ${d.data()['status'] ?? 'pending'}')),
          ]),
        ),
      ]),
    );
  }
}
