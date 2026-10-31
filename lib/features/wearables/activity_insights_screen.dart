import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Individual, non-diagnostic activity dashboard. Step counts are not exercise minutes.
class ActivityInsightsScreen extends StatefulWidget {
  const ActivityInsightsScreen({super.key});
  @override
  State<ActivityInsightsScreen> createState() => _ActivityInsightsScreenState();
}

class _ActivityInsightsScreenState extends State<ActivityInsightsScreen> {
  int days = 7;
  String metric = 'STEPS';
  static const metrics = <String, String>{
    'STEPS': 'Steps',
    'HEART_RATE': 'Heart rate',
    'RESTING_HEART_RATE': 'Resting heart rate',
    'ACTIVE_ENERGY_BURNED': 'Active energy',
  };

  double? numeric(dynamic data) {
    if (data is num && data.isFinite) return data.toDouble();
    if (data is String) return double.tryParse(data);
    return null;
  }

  DateTime? date(dynamic data) {
    if (data is Timestamp) return data.toDate();
    if (data is String) return DateTime.tryParse(data);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Sign in to view activity.'));
    final now = DateTime.now();
    final beginning = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Activity & wearable insights', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Your device-derived trends and age-relevant public health guidance. Activity trackers may miss exercise, double-count steps, or contain inaccurate readings.'),
      const SizedBox(height: 16),
      StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
        stream: FirebaseFirestore.instance.collection('patients').doc(uid).snapshots(),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data?.data() ?? {};
          final dob = DateTime.tryParse((profile['dateOfBirth'] ?? '').toString());
          int? age;
          if (dob != null) {
            age = now.year - dob.year - ((now.month < dob.month || (now.month == dob.month && now.day < dob.day)) ? 1 : 0);
          }
          final medicalHistory = (profile['conditions'] is List && (profile['conditions'] as List).isNotEmpty);
          final guidance = age == null ? 'Add your date of birth for age-relevant guidance.' :
            age < 5 ? 'Young children: activity guidance depends on exact age and developmental needs; discuss appropriate play with a qualified care professional.' :
            age < 18 ? 'WHO: ages 5–17 should average 60 minutes of moderate-to-vigorous activity daily, with muscle and bone strengthening at least 3 days per week.' :
            age < 65 ? 'WHO: adults should aim for 150–300 minutes of moderate activity, or 75–150 minutes vigorous activity weekly, plus muscle strengthening on 2 or more days.' :
            'WHO: older adults should aim for 150–300 moderate minutes weekly, or an equivalent vigorous amount, with strength work on 2+ days and balance-focused activity on 3+ days.';
          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Evidence-based activity guidance', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8), Text(guidance),
              if (medicalHistory) const Padding(padding: EdgeInsets.only(top: 10),
                child: Text('Your record lists existing conditions. Ask your care team to adapt intensity and exercise choices before changing your routine.')),
              const SizedBox(height: 8),
              TextButton.icon(onPressed: () => launchUrl(Uri.parse('https://www.who.int/europe/news-room/fact-sheets/item/physical-activity'),
                mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new), label: const Text('WHO physical activity guidance')),
              TextButton.icon(onPressed: () => launchUrl(Uri.parse('https://www.cdc.gov/physical-activity-basics/guidelines/index.html'),
                mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new), label: const Text('CDC activity guidance (US)')),
            ],
          )));
        },
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 8, children: [
        DropdownButton<int>(value: days, items: const [7, 14, 30].map((x) =>
          DropdownMenuItem(value: x, child: Text('Last $x days'))).toList(),
          onChanged: (v) => setState(() => days = v ?? 7)),
        DropdownButton<String>(value: metric, items: metrics.entries.map((e) =>
          DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => setState(() => metric = v ?? 'STEPS')),
      ]),
      const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: FirebaseFirestore.instance.collection('patients').doc(uid)
          .collection('deviceRaw').orderBy('dateFrom', descending: true).limit(1000).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const Text('Unable to load wearable readings.');
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final series = List<double?>.filled(days, null);
          final samples = List<int>.filled(days, 0);
          final sums = List<double>.filled(days, 0);
          final sourceNames = <String>{};
          for (final item in snap.data!.docs) {
            final raw = item.data();
            if (raw['healthType']?.toString() != metric || raw['synthetic'] != false) continue;
            final when = date(raw['dateFrom']);
            final number = numeric(raw['numericValue']);
            if (when == null || number == null || number < 0) continue;
            final day = DateTime(when.toLocal().year, when.toLocal().month, when.toLocal().day);
            final index = day.difference(beginning).inDays;
            if (index < 0 || index >= days) continue;
            sums[index] += number;
            samples[index]++;
            sourceNames.add((raw['sourceName'] ?? 'Unknown device').toString());
          }
          for (int i = 0; i < days; i++) {
            if (samples[i] > 0) {
              series[i] = metric == 'STEPS' || metric == 'ACTIVE_ENERGY_BURNED'
                  ? sums[i] : sums[i] / samples[i];
            }
          }
          final observed = series.whereType<double>().toList();
          final peak = observed.isEmpty ? 1.0 : observed.reduce((a,b) => a > b ? a : b).clamp(1.0, double.infinity).toDouble();
          final total = observed.fold<double>(0, (a,b) => a + b);
          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metrics[metric]!, style: Theme.of(context).textTheme.titleLarge),
              Text(observed.isEmpty ? 'No readable data for this period.' :
                'Observed on ${observed.length}/$days days · ${metric == 'STEPS' ? 'Sum' : 'Mean'}: ${(metric == 'STEPS' ? total : total / observed.length).toStringAsFixed(0)}'),
              const SizedBox(height: 20),
              SizedBox(height: 170, child: Row(crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(days, (i) {
                  final v = series[i];
                  return Expanded(child: Tooltip(message: v == null ? 'No measurement' : v.toStringAsFixed(0),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(height: v == null ? 3 : 8 + 145 * v / peak,
                        decoration: BoxDecoration(color: v == null ? Colors.grey.shade300 :
                          Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(4))))));
                }))),
              const SizedBox(height: 12),
              Text('Sources: ${sourceNames.isEmpty ? 'None linked in selected period' : sourceNames.join(', ')}'),
              const Text('Steps are not minutes of moderate or vigorous exercise. Multiple devices may overlap; missing observations are not zero. Energy and heart rate are consumer estimates.'),
            ],
          )));
        },
      ),
    ]);
  }
}
