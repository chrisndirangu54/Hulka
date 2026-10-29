import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/functions_service.dart';
import '../../ui/hulka_board.dart';
import '../../ui/hulka_look.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final api = HulkaFunctions();
  late final TabController tabs;

  final organizationName = TextEditingController();
  final organizationType = TextEditingController(text: 'hospital');
  final countryCode = TextEditingController(text: 'KE');
  final facilityCode = TextEditingController();
  final county = TextEditingController();
  final phone = TextEditingController();
  final ambulancePhone = TextEditingController();
  final ambulanceNotes = TextEditingController();

  final providerUid = TextEditingController();
  final providerRole = TextEditingController(text: 'clinician');
  final providerOrganizationId = TextEditingController();

  final doctorName = TextEditingController();
  final doctorSpecialty = TextEditingController();
  final doctorLicense = TextEditingController();
  final doctorPhone = TextEditingController();
  final doctorUid = TextEditingController();
  final doctorOrgId = TextEditingController();
  final doctorOrgName = TextEditingController();

  final pharmacyName = TextEditingController();
  final pharmacyCode = TextEditingController();
  final pharmacyPhone = TextEditingController();
  final pharmacyCounty = TextEditingController();

  final productGeneric = TextEditingController();
  final productBrand = TextEditingController();
  final productCode = TextEditingController();
  final productStrength = TextEditingController();
  final productForm = TextEditingController(text: 'tablet');
  final productMaker = TextEditingController();

  final unitHospitalId = TextEditingController();
  final unitHospitalName = TextEditingController();
  final unitCallSign = TextEditingController();
  final unitPhone = TextEditingController();
  final unitCounty = TextEditingController();

  // Partner / self-application onboarding
  final partnerOrgName = TextEditingController();
  final partnerEmail = TextEditingController();
  final partnerPhone = TextEditingController();
  final partnerServices = TextEditingController();
  final partnerLicense = TextEditingController();
  final partnerEmergencyProtocol = TextEditingController();
  String _partnerKind = 'hospital';

  // Pharmaceutical product catalog
  final catalogProductName = TextEditingController();
  final catalogGenericName = TextEditingController();
  final catalogManufacturer = TextEditingController();
  final catalogMedicationCode = TextEditingController();
  final catalogApprovalStatus = TextEditingController(text: 'approved');
  String _catalogCategory = 'antibiotic';

  bool busy = false;
  String? message;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    tabs.dispose();
    organizationName.dispose();
    organizationType.dispose();
    countryCode.dispose();
    facilityCode.dispose();
    county.dispose();
    phone.dispose();
    ambulancePhone.dispose();
    ambulanceNotes.dispose();
    providerUid.dispose();
    providerRole.dispose();
    providerOrganizationId.dispose();
    doctorName.dispose();
    doctorSpecialty.dispose();
    doctorLicense.dispose();
    doctorPhone.dispose();
    doctorUid.dispose();
    doctorOrgId.dispose();
    doctorOrgName.dispose();
    pharmacyName.dispose();
    pharmacyCode.dispose();
    pharmacyPhone.dispose();
    pharmacyCounty.dispose();
    productGeneric.dispose();
    productBrand.dispose();
    productCode.dispose();
    productStrength.dispose();
    productForm.dispose();
    productMaker.dispose();
    unitHospitalId.dispose();
    unitHospitalName.dispose();
    unitCallSign.dispose();
    unitPhone.dispose();
    unitCounty.dispose();
    partnerOrgName.dispose();
    partnerEmail.dispose();
    partnerPhone.dispose();
    partnerServices.dispose();
    partnerLicense.dispose();
    partnerEmergencyProtocol.dispose();
    catalogProductName.dispose();
    catalogGenericName.dispose();
    catalogManufacturer.dispose();
    catalogMedicationCode.dispose();
    catalogApprovalStatus.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String> _upsertOrganization({
    required String name,
    required String type,
    String? extraPhone,
    String? extraCounty,
    bool ambulance = false,
  }) async {
    final payload = {
      'name': name,
      'type': type,
      'countryCode': countryCode.text.trim().isEmpty
          ? 'KE'
          : countryCode.text.trim(),
      'facilityCode': facilityCode.text.trim().isEmpty
          ? null
          : facilityCode.text.trim(),
      'verified': true,
    };
    try {
      return await api.upsertHealthcareOrganization(payload);
    } catch (_) {
      final ref = FirebaseFirestore.instance.collection('organizations').doc();
      await ref.set({
        ...payload,
        'phone': extraPhone,
        'county': extraCounty ?? county.text.trim(),
        'ambulancePhone': ambulance ? ambulancePhone.text.trim() : extraPhone,
        'ambulanceAvailable':
            ambulance || ambulancePhone.text.trim().isNotEmpty,
        'ambulanceNotes': ambulanceNotes.text.trim().isEmpty
            ? null
            : ambulanceNotes.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    }
  }

  Future<void> createOrganization() async {
    await _run(() async {
      final id = await _upsertOrganization(
        name: organizationName.text.trim(),
        type: organizationType.text.trim(),
        extraPhone: phone.text.trim(),
        extraCounty: county.text.trim(),
        ambulance: ambulancePhone.text.trim().isNotEmpty,
      );
      if (ambulancePhone.text.trim().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(id)
            .set({
              'phone': phone.text.trim(),
              'county': county.text.trim(),
              'ambulancePhone': ambulancePhone.text.trim(),
              'ambulanceAvailable': true,
              'ambulanceNotes': ambulanceNotes.text.trim().isEmpty
                  ? null
                  : ambulanceNotes.text.trim(),
            }, SetOptions(merge: true));
      }
      providerOrganizationId.text = id;
      doctorOrgId.text = id;
      unitHospitalId.text = id;
      if (mounted) setState(() => message = 'Organization saved: $id');
    });
  }

  Future<void> verifyProvider() async {
    await _run(() async {
      try {
        await api.verifyProviderAccount({
          'providerUid': providerUid.text.trim(),
          'role': providerRole.text.trim(),
          'organizationId': providerOrganizationId.text.trim(),
        });
      } catch (_) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(providerUid.text.trim())
            .set({
              'role': providerRole.text.trim(),
              'organizationId': providerOrganizationId.text.trim(),
              'verified': true,
              'providerVerifiedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
      if (mounted) setState(() => message = 'Provider account verified.');
    });
  }

  Future<void> onboardDoctor() async {
    await _run(() async {
      if (doctorName.text.trim().isEmpty ||
          doctorSpecialty.text.trim().isEmpty) {
        throw StateError('Doctor name and specialty are required.');
      }
      final ref = FirebaseFirestore.instance
          .collection('clinicianDirectory')
          .doc();
      await ref.set({
        'displayName': doctorName.text.trim(),
        'specialty': doctorSpecialty.text.trim(),
        'licenseNumber': doctorLicense.text.trim(),
        'phone': doctorPhone.text.trim(),
        'uid': doctorUid.text.trim().isEmpty ? null : doctorUid.text.trim(),
        'organizationId': doctorOrgId.text.trim(),
        'organizationName': doctorOrgName.text.trim(),
        'verified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (doctorUid.text.trim().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(doctorUid.text.trim())
            .set({
              'role': 'clinician',
              'verified': true,
              'organizationId': doctorOrgId.text.trim(),
              'displayName': doctorName.text.trim(),
            }, SetOptions(merge: true));
      }
      if (mounted) setState(() => message = 'Doctor onboarded: ${ref.id}');
    });
  }

  Future<void> onboardPharmacy() async {
    await _run(() async {
      if (pharmacyName.text.trim().isEmpty) {
        throw StateError('Pharmacy name is required.');
      }
      final id = await _upsertOrganization(
        name: pharmacyName.text.trim(),
        type: 'pharmacy',
        extraPhone: pharmacyPhone.text.trim(),
        extraCounty: pharmacyCounty.text.trim(),
      );
      await FirebaseFirestore.instance.collection('organizations').doc(id).set({
        'facilityCode': pharmacyCode.text.trim().isEmpty
            ? null
            : pharmacyCode.text.trim(),
        'phone': pharmacyPhone.text.trim(),
        'county': pharmacyCounty.text.trim(),
        'type': 'pharmacy',
        'verified': true,
      }, SetOptions(merge: true));
      if (mounted) setState(() => message = 'Pharmacy onboarded: $id');
    });
  }

  Future<void> onboardProduct() async {
    await _run(() async {
      if (productGeneric.text.trim().isEmpty ||
          productStrength.text.trim().isEmpty ||
          productForm.text.trim().isEmpty) {
        throw StateError('Generic name, strength and dose form are required.');
      }
      final ref = FirebaseFirestore.instance
          .collection('pharmaceuticalProducts')
          .doc();
      await ref.set({
        'genericName': productGeneric.text.trim(),
        'brandName': productBrand.text.trim().isEmpty
            ? null
            : productBrand.text.trim(),
        'medicationCode': productCode.text.trim().isEmpty
            ? productGeneric.text.trim().toLowerCase().replaceAll(' ', '_')
            : productCode.text.trim(),
        'strength': productStrength.text.trim(),
        'doseForm': productForm.text.trim(),
        'manufacturer': productMaker.text.trim().isEmpty
            ? null
            : productMaker.text.trim(),
        'verified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => message = 'Pharmaceutical product listed: ${ref.id}');
      }
    });
  }

  Future<void> onboardAmbulanceUnit() async {
    await _run(() async {
      if (unitHospitalName.text.trim().isEmpty ||
          unitPhone.text.trim().isEmpty) {
        throw StateError('Hospital name and dispatch phone are required.');
      }
      final ref = FirebaseFirestore.instance.collection('ambulanceUnits').doc();
      await ref.set({
        'organizationId': unitHospitalId.text.trim(),
        'hospitalName': unitHospitalName.text.trim(),
        'callSign': unitCallSign.text.trim(),
        'phone': unitPhone.text.trim(),
        'county': unitCounty.text.trim(),
        'status': 'available',
        'verified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (unitHospitalId.text.trim().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(unitHospitalId.text.trim())
            .set({
              'ambulancePhone': unitPhone.text.trim(),
              'ambulanceAvailable': true,
              'name': unitHospitalName.text.trim(),
              'type': 'hospital',
              'verified': true,
              'county': unitCounty.text.trim(),
              'countryCode': 'KE',
            }, SetOptions(merge: true));
      }
      if (mounted) setState(() => message = 'Ambulance unit listed: ${ref.id}');
    });
  }

  Future<void> setApplicationStatus(String id, String status) async {
    await FirebaseFirestore.instance
        .collection('partnerApplications')
        .doc(id)
        .update({'status': status, 'reviewedAt': FieldValue.serverTimestamp()});
  }

  Future<void> setAmbulanceRequestStatus(String id, String status) async {
    await FirebaseFirestore.instance
        .collection('ambulanceRequests')
        .doc(id)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: HulkaLook.paper,
          child: TabBar(
            controller: tabs,
            isScrollable: true,
            labelColor: HulkaLook.atrium,
            indicatorColor: HulkaLook.pulse,
            tabs: const [
              Tab(text: 'Network'),
              Tab(text: 'Onboard'),
              Tab(text: 'Ambulance'),
              Tab(text: 'Applications'),
              Tab(text: 'Onboarding'),
            ],
          ),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              message!,
              style: const TextStyle(color: HulkaLook.atrium),
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: tabs,
            children: [
              _networkTab(),
              _onboardTab(),
              _ambulanceTab(),
              _applicationsTab(),
              _partnerOnboardingTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _networkTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Trusted administration',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: HulkaLook.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Verification controls organisations and provider roles. Admin status does not open patient records.',
          style: TextStyle(color: HulkaLook.atrium, height: 1.35),
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Healthcare organization',
          child: Column(
            children: [
              TextField(
                controller: organizationName,
                decoration: const InputDecoration(
                  labelText: 'Organization name',
                ),
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
                      decoration: const InputDecoration(labelText: 'Country'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: facilityCode,
                      decoration: const InputDecoration(
                        labelText: 'Facility code',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: county,
                      decoration: const InputDecoration(labelText: 'County'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: phone,
                      decoration: const InputDecoration(
                        labelText: 'Switchboard',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ambulancePhone,
                decoration: const InputDecoration(
                  labelText: 'Ambulance dispatch phone',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ambulanceNotes,
                decoration: const InputDecoration(labelText: 'Ambulance notes'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : createOrganization,
                child: const Text('Create / verify organization'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Verify provider',
          child: Column(
            children: [
              TextField(
                controller: providerUid,
                decoration: const InputDecoration(
                  labelText: 'Provider Firebase UID',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: providerRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  hintText:
                      'clinician, pharmacist, laboratory, hospitalAdmin, researcher',
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _onboardTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Partner onboarding',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: HulkaLook.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Hospitals, doctors, pharmacies and pharmaceutical products join the same verified network.',
          style: TextStyle(color: HulkaLook.atrium, height: 1.35),
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Doctor',
          subtitle:
              'Listed on the care network. Optional UID verifies an existing Hulka login as a clinician.',
          child: Column(
            children: [
              TextField(
                controller: doctorName,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doctorSpecialty,
                decoration: const InputDecoration(labelText: 'Specialty'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doctorLicense,
                decoration: const InputDecoration(
                  labelText: 'Licence / council number',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doctorPhone,
                decoration: const InputDecoration(labelText: 'Clinic phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doctorUid,
                decoration: const InputDecoration(
                  labelText: 'Firebase UID (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doctorOrgId,
                decoration: const InputDecoration(
                  labelText: 'Hospital / clinic ID',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doctorOrgName,
                decoration: const InputDecoration(
                  labelText: 'Hospital / clinic name',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : onboardDoctor,
                child: const Text('Onboard doctor'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Pharmacy',
          child: Column(
            children: [
              TextField(
                controller: pharmacyName,
                decoration: const InputDecoration(labelText: 'Pharmacy name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pharmacyCode,
                decoration: const InputDecoration(
                  labelText: 'PPB / facility code',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pharmacyPhone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pharmacyCounty,
                decoration: const InputDecoration(labelText: 'County'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : onboardPharmacy,
                child: const Text('Onboard pharmacy'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Pharmaceutical product',
          subtitle:
              'Catalog used when matching uploaded prescriptions to stock.',
          child: Column(
            children: [
              TextField(
                controller: productGeneric,
                decoration: const InputDecoration(labelText: 'Generic name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: productBrand,
                decoration: const InputDecoration(labelText: 'Brand name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: productCode,
                decoration: const InputDecoration(labelText: 'Medication code'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: productStrength,
                      decoration: const InputDecoration(labelText: 'Strength'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: productForm,
                      decoration: const InputDecoration(labelText: 'Dose form'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: productMaker,
                decoration: const InputDecoration(labelText: 'Manufacturer'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : onboardProduct,
                child: const Text('List product'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Recently onboarded doctors',
          style: TextStyle(fontWeight: FontWeight.w600, color: HulkaLook.ink),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('clinicianDirectory')
              .limit(20)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            if (snap.data!.docs.isEmpty) {
              return const Text('No doctors listed yet.');
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return ListTile(
                  leading: const Icon(Icons.medical_services_outlined),
                  title: Text((d['displayName'] as String?) ?? 'Clinician'),
                  subtitle: Text(
                    '${d['specialty'] ?? ''}  ${d['organizationName'] ?? ''}',
                  ),
                );
              }).toList(),
            );
          },
        ),
        const Text(
          'Pharmaceutical catalog',
          style: TextStyle(fontWeight: FontWeight.w600, color: HulkaLook.ink),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('pharmaceuticalProducts')
              .limit(20)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Text('No products listed yet.');
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return ListTile(
                  leading: const Icon(Icons.medication_outlined),
                  title: Text(
                    '${d['genericName'] ?? ''} ${d['strength'] ?? ''}',
                  ),
                  subtitle: Text(
                    '${d['brandName'] ?? d['doseForm'] ?? ''}  ${d['manufacturer'] ?? ''}',
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _ambulanceTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Ambulance fleet',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: HulkaLook.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Dispatch lines appear on the patient Emergency tab once the hospital is verified.',
          style: TextStyle(color: HulkaLook.atrium, height: 1.35),
        ),
        const SizedBox(height: 16),
        HulkaBoard(
          title: 'Add a unit',
          child: Column(
            children: [
              TextField(
                controller: unitHospitalId,
                decoration: const InputDecoration(
                  labelText: 'Hospital organization ID',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitHospitalName,
                decoration: const InputDecoration(labelText: 'Hospital name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCallSign,
                decoration: const InputDecoration(
                  labelText: 'Vehicle / call sign',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitPhone,
                decoration: const InputDecoration(labelText: 'Dispatch phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCounty,
                decoration: const InputDecoration(labelText: 'County'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : onboardAmbulanceUnit,
                child: const Text('Publish ambulance unit'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('ambulanceUnits')
              .limit(50)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return const Text('No ambulance units yet.');
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return ListTile(
                  leading: const Icon(Icons.airport_shuttle_outlined),
                  title: Text((d['hospitalName'] as String?) ?? 'Unit'),
                  subtitle: Text(
                    '${d['callSign'] ?? ''}  ${d['phone'] ?? ''}  ${d['status'] ?? ''}',
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Live requests',
          style: TextStyle(fontWeight: FontWeight.w600, color: HulkaLook.ink),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('ambulanceRequests')
              .limit(40)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            if (snap.data!.docs.isEmpty) {
              return const Text('No ambulance requests.');
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    title: Text((d['hospitalName'] as String?) ?? 'Request'),
                    subtitle: Text(
                      '${d['status'] ?? ''}  ${d['locationNote'] ?? ''}\nPatient ${d['patientId'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) =>
                          setAmbulanceRequestStatus(doc.id, value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'dispatched',
                          child: Text('Dispatched'),
                        ),
                        PopupMenuItem(
                          value: 'enroute',
                          child: Text('En route'),
                        ),
                        PopupMenuItem(value: 'arrived', child: Text('Arrived')),
                        PopupMenuItem(
                          value: 'cancelled',
                          child: Text('Cancel'),
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
    );
  }

  Widget _applicationsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Partner applications',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: HulkaLook.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Hospitals, clinics, doctors and pharmacies can request to join. Approve here, then complete onboarding.',
          style: TextStyle(color: HulkaLook.atrium, height: 1.35),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('partnerApplications')
              .limit(80)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return const HulkaBoard(
                title: 'No applications yet',
                child: Text(
                  'When a partner submits from the care network, the request appears here.',
                ),
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_ind_outlined),
                    title: Text(
                      (d['organizationName'] as String?) ??
                          (d['displayName'] as String?) ??
                          'Applicant',
                    ),
                    subtitle: Text(
                      '${d['kind'] ?? ''}  ${d['status'] ?? 'pending'}\n${d['email'] ?? ''}  ${d['phone'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) =>
                          setApplicationStatus(doc.id, value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'approved',
                          child: Text('Approve'),
                        ),
                        PopupMenuItem(
                          value: 'waitlisted',
                          child: Text('Waitlist'),
                        ),
                        PopupMenuItem(value: 'rejected', child: Text('Reject')),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Business logic: partner self-application & pharmaceutical catalog
  // ---------------------------------------------------------------------------

  Future<void> submitPartnerApplication() async {
    await _run(() async {
      if (partnerOrgName.text.trim().isEmpty) {
        throw StateError('Organization name is required.');
      }
      if (partnerEmail.text.trim().isEmpty) {
        throw StateError('Email is required.');
      }
      await FirebaseFirestore.instance.collection('partnerApplications').add({
        'applicantUid': FirebaseAuth.instance.currentUser!.uid,
        'note': partnerServices.text.trim(),
        'organizationName': partnerOrgName.text.trim(),
        'kind': _partnerKind,
        'email': partnerEmail.text.trim(),
        'phone': partnerPhone.text.trim().isEmpty
            ? null
            : partnerPhone.text.trim(),
        'servicesOffered': partnerServices.text.trim().isEmpty
            ? null
            : partnerServices.text.trim(),
        'accreditationNumber': partnerLicense.text.trim().isEmpty
            ? null
            : partnerLicense.text.trim(),
        'emergencyResponseProtocol':
            (_partnerKind == 'hospital' || _partnerKind == 'clinic') &&
                partnerEmergencyProtocol.text.trim().isNotEmpty
            ? partnerEmergencyProtocol.text.trim()
            : null,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => message = 'Application submitted — status: pending');
      }
      partnerOrgName.clear();
      partnerEmail.clear();
      partnerPhone.clear();
      partnerServices.clear();
      partnerLicense.clear();
      partnerEmergencyProtocol.clear();
    });
  }

  Future<void> addCatalogProduct() async {
    await _run(() async {
      if (catalogProductName.text.trim().isEmpty ||
          catalogGenericName.text.trim().isEmpty) {
        throw StateError('Product name and generic name are required.');
      }
      await FirebaseFirestore.instance.collection('pharmaceuticalProducts').add(
        {
          'productName': catalogProductName.text.trim(),
          'genericName': catalogGenericName.text.trim(),
          'manufacturer': catalogManufacturer.text.trim().isEmpty
              ? null
              : catalogManufacturer.text.trim(),
          'medicationCode': catalogMedicationCode.text.trim().isEmpty
              ? catalogGenericName.text.trim().toLowerCase().replaceAll(
                  ' ',
                  '_',
                )
              : catalogMedicationCode.text.trim(),
          'category': _catalogCategory,
          'regulatoryApprovalStatus': catalogApprovalStatus.text.trim().isEmpty
              ? 'approved'
              : catalogApprovalStatus.text.trim(),
          'verified': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      if (mounted) setState(() => message = 'Product added to catalog.');
      catalogProductName.clear();
      catalogGenericName.clear();
      catalogManufacturer.clear();
      catalogMedicationCode.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Onboarding tab UI
  // ---------------------------------------------------------------------------

  Widget _partnerOnboardingTab() {
    return StatefulBuilder(
      builder: (context, setLocal) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Partner & product onboarding',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: HulkaLook.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'External partners can self-apply. Pharmaceutical companies can list new products for the catalog.',
              style: TextStyle(color: HulkaLook.atrium, height: 1.35),
            ),
            const SizedBox(height: 16),

            // ----------------------------------------------------------------
            // 1. Partner application form
            // ----------------------------------------------------------------
            HulkaBoard(
              title: 'Partner application',
              subtitle:
                  'Hospitals, clinics, doctors, pharmacies and pharmaceutical companies can apply here.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: partnerOrgName,
                    decoration: const InputDecoration(
                      labelText: 'Organization name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _partnerKind,
                    decoration: const InputDecoration(labelText: 'Kind'),
                    items: const [
                      DropdownMenuItem(
                        value: 'hospital',
                        child: Text('Hospital'),
                      ),
                      DropdownMenuItem(value: 'clinic', child: Text('Clinic')),
                      DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                      DropdownMenuItem(
                        value: 'pharmacy',
                        child: Text('Pharmacy'),
                      ),
                      DropdownMenuItem(
                        value: 'pharmaceutical',
                        child: Text('Pharmaceutical company'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setLocal(() => _partnerKind = v);
                        setState(() => _partnerKind = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: partnerEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: partnerPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: partnerServices,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Services offered',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: partnerLicense,
                    decoration: const InputDecoration(
                      labelText: 'Accreditation / licence number',
                    ),
                  ),
                  // Emergency protocol — only for hospital/clinic
                  if (_partnerKind == 'hospital' ||
                      _partnerKind == 'clinic') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: partnerEmergencyProtocol,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Emergency response protocol',
                        hintText:
                            'Describe your emergency and triage procedures',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : submitPartnerApplication,
                    child: const Text('Submit application'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ----------------------------------------------------------------
            // 2. Pharmaceutical products catalog — add new product
            // ----------------------------------------------------------------
            HulkaBoard(
              title: 'Pharmaceutical products catalog',
              subtitle:
                  'List new medicines for catalog matching. Distinct from pharmacy inventory.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: catalogProductName,
                    decoration: const InputDecoration(
                      labelText: 'Product name (brand)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: catalogGenericName,
                    decoration: const InputDecoration(
                      labelText: 'Generic name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: catalogManufacturer,
                    decoration: const InputDecoration(
                      labelText: 'Manufacturer',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: catalogMedicationCode,
                    decoration: const InputDecoration(
                      labelText: 'Medication code (e.g., KEPHIS code)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _catalogCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(
                        value: 'antibiotic',
                        child: Text('Antibiotic'),
                      ),
                      DropdownMenuItem(
                        value: 'antihypertensive',
                        child: Text('Antihypertensive'),
                      ),
                      DropdownMenuItem(
                        value: 'analgesic',
                        child: Text('Analgesic'),
                      ),
                      DropdownMenuItem(
                        value: 'antidiabetic',
                        child: Text('Antidiabetic'),
                      ),
                      DropdownMenuItem(
                        value: 'antiparasitic',
                        child: Text('Antiparasitic'),
                      ),
                      DropdownMenuItem(
                        value: 'vitamin_supplement',
                        child: Text('Vitamin / Supplement'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setLocal(() => _catalogCategory = v);
                        setState(() => _catalogCategory = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: catalogApprovalStatus,
                    decoration: const InputDecoration(
                      labelText: 'Regulatory approval status',
                      hintText: 'approved, pending, conditional',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : addCatalogProduct,
                    child: const Text('Add product'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ----------------------------------------------------------------
            // 3. Stream: existing pharmaceutical catalog
            // ----------------------------------------------------------------
            const Text(
              'Existing product catalog',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: HulkaLook.ink,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('pharmaceuticalProducts')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.data!.docs.isEmpty) {
                  return const HulkaBoard(
                    title: 'No products yet',
                    child: Text('Products added above appear here for review.'),
                  );
                }
                return Column(
                  children: snap.data!.docs.map((doc) {
                    final d = doc.data();
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.medication_outlined,
                          color: HulkaLook.pulse,
                        ),
                        title: Text(
                          '${d['productName'] ?? d['genericName'] ?? 'Product'}',
                        ),
                        subtitle: Text(
                          '${d['genericName'] ?? ''}  •  ${d['category'] ?? ''}  •  ${d['regulatoryApprovalStatus'] ?? ''}'
                          '\n${d['manufacturer'] ?? ''}  ${d['medicationCode'] != null ? '(${d['medicationCode']})' : ''}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
