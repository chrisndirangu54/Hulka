import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});
  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  final query = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Prescription & Pharmacy', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Search verified inventory. Prescription substitutions require pharmacist review.'),
        const SizedBox(height: 18),
        TextField(
          controller: query,
          decoration: const InputDecoration(labelText: 'Medicine or generic name', prefixIcon: Icon(Icons.search)),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('pharmacyInventory').limit(50).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final needle = query.text.trim().toLowerCase();
            final docs = snap.data!.docs.where((d) {
              final x = d.data();
              final hay = '${x['genericName'] ?? ''} ${x['brandName'] ?? ''}'.toLowerCase();
              return needle.isEmpty || hay.contains(needle);
            }).toList();
            if (docs.isEmpty) return const Text('No matching stock reported.');
            return Column(
              children: docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_pharmacy_outlined),
                    title: Text((d['genericName'] as String?) ?? 'Medicine'),
                    subtitle: Text('${d['strength'] ?? ''} • ${d['pharmacyName'] ?? 'Pharmacy'}'),
                    trailing: Text('${d['currency'] ?? ''} ${d['price'] ?? ''}'),
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
