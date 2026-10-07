import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/device_health_service.dart';

class WearablesScreen extends StatefulWidget {
  const WearablesScreen({super.key});

  @override
  State<WearablesScreen> createState() => _WearablesScreenState();
}

class _WearablesScreenState extends State<WearablesScreen> {
  final health = DeviceHealthService();
  bool syncing = false;
  String? message;

  Future<void> sync() async {
    setState(() {
      syncing = true;
      message = null;
    });
    try {
      final count = await health.syncLast24Hours();
      if (mounted) {
        setState(() => message =
            count == 0
                ? 'No new authorized measurements were imported.'
                : 'Imported $count authorized measurement(s) from the last 24 hours.');
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Device sync failed: $e');
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Authentication required.'));

    final stream = FirebaseFirestore.instance
        .collection('patients')
        .doc(uid)
        .collection('deviceRaw')
        .orderBy('dateFrom', descending: true)
        .limit(50)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Wearables & Devices', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'HealthKit and Android Health Connect measurements retain their source, '
          'time interval and recording method. Consumer wearable readings are not '
          'silently treated as clinical-grade measurements.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            Chip(label: Text('Apple HealthKit')),
            Chip(label: Text('Health Connect')),
            Chip(label: Text('Heart rate')),
            Chip(label: Text('Blood pressure')),
            Chip(label: Text('Blood glucose')),
            Chip(label: Text('Sleep')),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: syncing ? null : sync,
          icon: const Icon(Icons.sync),
          label: Text(syncing ? 'Syncing…' : 'Sync last 24 hours'),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!),
        ],
        const SizedBox(height: 24),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) {
              return const Card(
                child: ListTile(
                  title: Text('No device observations synchronized yet.'),
                ),
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.monitor_heart_outlined),
                    title: Text((d['healthType'] as String?) ?? 'Observation'),
                    subtitle: Text(
                      'Source: ${d['sourceName'] ?? d['sourceId'] ?? 'device'}\n'
                      'Method: ${d['recordingMethod'] ?? 'unknown'}',
                    ),
                    isThreeLine: true,
                    trailing: Text('${d['value'] ?? ''} ${d['unit'] ?? ''}'),
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
