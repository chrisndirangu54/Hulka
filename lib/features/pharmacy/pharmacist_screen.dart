import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class PharmacistScreen extends StatefulWidget {
  const PharmacistScreen({super.key});

  @override
  State<PharmacistScreen> createState() => _PharmacistScreenState();
}

class _PharmacistScreenState extends State<PharmacistScreen> {
  final api = HulkaFunctions();
  final medicationCode = TextEditingController();
  final genericName = TextEditingController();
  final brandName = TextEditingController();
  final strength = TextEditingController();
  final form = TextEditingController(text: 'tablet');
  final quantity = TextEditingController();
  final price = TextEditingController();
  final currency = TextEditingController(text: 'KES');
  final pharmacyId = TextEditingController();
  final pharmacyName = TextEditingController();

  bool busy = false;
  String? message;

  Future<void> saveStock() async {
    final qty = int.tryParse(quantity.text.trim());
    final amount = num.tryParse(price.text.trim());
    if (medicationCode.text.trim().isEmpty ||
        genericName.text.trim().isEmpty ||
        strength.text.trim().isEmpty ||
        form.text.trim().isEmpty ||
        qty == null ||
        amount == null) {
      setState(() => message = 'Complete medicine, formulation, quantity and price.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final id = await api.upsertPharmacyInventory({
        'pharmacyId': pharmacyId.text.trim().isEmpty ? null : pharmacyId.text.trim(),
        'pharmacyName': pharmacyName.text.trim().isEmpty
            ? null
            : pharmacyName.text.trim(),
        'medicationCode': medicationCode.text.trim(),
        'genericName': genericName.text.trim(),
        'brandName': brandName.text.trim().isEmpty ? null : brandName.text.trim(),
        'strength': strength.text.trim(),
        'doseForm': form.text.trim(),
        'availableQuantity': qty,
        'price': amount,
        'currency': currency.text.trim(),
      });
      if (mounted) setState(() => message = 'Inventory saved: $id');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not update inventory: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> setOrderStatus(String id, String status) async {
    setState(() => busy = true);
    try {
      await api.updatePharmacyOrderStatus(id, status);
      if (mounted) setState(() => message = 'Order updated to $status.');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not update order: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Pharmacist Workspace',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Verified pharmacists can publish stock and process reservations. '
          'Generic or brand substitutions remain reviewable clinical-pharmacy actions.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: pharmacyId,
          decoration: const InputDecoration(
            labelText: 'Pharmacy organization ID',
            helperText: 'May be omitted when the verified account already has an organization.',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: pharmacyName,
          decoration: const InputDecoration(labelText: 'Pharmacy display name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: medicationCode,
          decoration: const InputDecoration(labelText: 'Medication code'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: genericName,
          decoration: const InputDecoration(labelText: 'Generic name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: brandName,
          decoration: const InputDecoration(labelText: 'Brand name (optional)'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: strength,
                decoration: const InputDecoration(labelText: 'Strength'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: form,
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
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Available quantity'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Unit price'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: TextField(
                controller: currency,
                decoration: const InputDecoration(labelText: 'Currency'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : saveStock,
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Publish inventory'),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!),
        ],
        const SizedBox(height: 28),
        Text('Pharmacy orders', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('pharmacyOrders')
              .limit(100)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) return const Text('No pharmacy orders.');
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                final status = (d['status'] as String?) ?? 'reserved';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(
                      '${d['genericName'] ?? 'Medicine'} ${d['strength'] ?? ''}',
                    ),
                    subtitle: Text(
                      'Qty: ${d['quantity'] ?? ''} • Status: $status'
                      '${d['requiresPharmacistReview'] == true ? ' • Review required' : ''}',
                    ),
                    trailing: PopupMenuButton<String>(
                      enabled: !busy,
                      onSelected: (value) => setOrderStatus(doc.id, value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'confirmed', child: Text('Confirm')),
                        PopupMenuItem(value: 'ready', child: Text('Ready')),
                        PopupMenuItem(value: 'dispensed', child: Text('Dispensed')),
                        PopupMenuItem(value: 'cancelled', child: Text('Cancel')),
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
}
