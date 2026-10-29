import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/dosage_schedule.dart';
import '../../services/notification_service.dart';
import '../../ui/hulka_board.dart';
import '../../ui/hulka_look.dart';

/// Full-screen list of dosage reminders for the signed-in patient.
///
/// Streams `patients/{uid}/dosageReminders` from Firestore and presents each
/// reminder as a card with a countdown to the next dose and a "Mark taken"
/// action. A FAB opens the "Add reminder" bottom sheet.
class DosageRemindersScreen extends StatefulWidget {
  const DosageRemindersScreen({super.key, this.prescription});

  final Map<String, dynamic>? prescription;

  @override
  State<DosageRemindersScreen> createState() => _DosageRemindersScreenState();
}

class _DosageRemindersScreenState extends State<DosageRemindersScreen> {
  final _notifications = NotificationService();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    if (widget.prescription != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAddSheet();
      });
    }
  }

  // ── Add-reminder bottom sheet controllers ──────────────────────────────────
  final _medicine = TextEditingController();
  final _strength = TextEditingController();
  final _doseForm = TextEditingController(text: 'tablet');
  final _instructions = TextEditingController();
  final _times = <String>['08:00'];
  bool _saving = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _medicine.dispose();
    _strength.dispose();
    _doseForm.dispose();
    _instructions.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _uid() => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> _remindersRef() => FirebaseFirestore
      .instance
      .collection('patients')
      .doc(_uid())
      .collection('dosageReminders');

  Future<void> _markTaken(String docId) async {
    await _remindersRef().doc(docId).update({
      'lastTakenAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _cancelReminder(String docId) async {
    await _notifications.cancelDosageReminder(docId);
  }

  Future<void> _saveReminder(BuildContext sheetContext) async {
    if (_saving) return;
    final medicine = _medicine.text.trim();
    if (medicine.isEmpty || _times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a medicine name and at least one time.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final reminder = DosageReminder(
        id: '',
        prescriptionId: widget.prescription?['id'] as String?,
        medicine: medicine,
        strength: _strength.text.trim(),
        doseForm: _doseForm.text.trim(),
        instructions: _instructions.text.trim(),
        times: List<String>.from(_times),
      );
      await _notifications.scheduleDosageReminders([reminder]);
      if (mounted) {
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        _medicine.clear();
        _strength.clear();
        _instructions.clear();
        setState(() {
          _times
            ..clear()
            ..add('08:00');
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save reminder: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(StateSetter sheetSetState) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    final label =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (!_times.contains(label)) {
      sheetSetState(() {
        _times.add(label);
        _times.sort();
      });
    }
  }

  void _openAddSheet() {
    _medicine.text = widget.prescription?['genericName'] as String? ?? '';
    _strength.text = widget.prescription?['strength'] as String? ?? '';
    _doseForm.text = widget.prescription?['doseForm'] as String? ?? 'tablet';
    _instructions.text = widget.prescription?['instructions'] as String? ?? '';
    _times
      ..clear()
      ..add('08:00');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HulkaLook.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, sheetSetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add dosage reminder',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: HulkaLook.ink,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _medicine,
                  decoration: const InputDecoration(labelText: 'Medicine name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _strength,
                        decoration: const InputDecoration(
                          labelText: 'Strength',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _doseForm,
                        decoration: const InputDecoration(
                          labelText: 'Dose form',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _instructions,
                  decoration: const InputDecoration(labelText: 'Instructions'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in _times)
                      InputChip(
                        label: Text(t),
                        onDeleted: () => sheetSetState(() => _times.remove(t)),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Add time'),
                      onPressed: () => _pickTime(sheetSetState),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final save = _saveReminder(ctx);
                          sheetSetState(() {});
                          await save;
                          if (ctx.mounted) sheetSetState(() {});
                        },
                  icon: const Icon(Icons.alarm_add),
                  label: Text(_saving ? 'Saving…' : 'Save reminder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
        title: const Text('Dosage reminders'),
        backgroundColor: HulkaLook.paper,
        foregroundColor: HulkaLook.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: HulkaLook.pulse,
        foregroundColor: HulkaLook.ink,
        icon: const Icon(Icons.alarm_add),
        label: const Text('Add reminder'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _remindersRef()
            .orderBy('scheduledAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(
              child: Text('Unable to load reminders. Please retry.'),
            );
          }
          final docs = snap.data?.docs ?? const [];
          final active = docs
              .where((d) => d.data()['active'] != false)
              .toList();

          if (active.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.alarm_outlined,
                      size: 56,
                      color: HulkaLook.copper.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No dosage reminders yet.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: HulkaLook.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap "Add reminder" to track medicines you take each day.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HulkaLook.atrium, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: active.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ReminderCard(
              doc: active[i],
              onMarkTaken: () => _markTaken(active[i].id),
              onCancel: () => _cancelReminder(active[i].id),
            ),
          );
        },
      ),
    );
  }
}

// ── Reminder card ────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.doc,
    required this.onMarkTaken,
    required this.onCancel,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onMarkTaken;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final now = DateTime.now();
    final times = ((d['times'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();

    DateTime? lastAt;
    final raw = d['lastTakenAt'];
    if (raw is Timestamp) lastAt = raw.toDate();

    final taken = DosageSchedule.takenForCurrentDose(lastAt, times, now);
    final next = DosageSchedule.nextDose(times, now);

    final medicine = (d['medicine'] as String?) ?? 'Medicine';
    final strength = (d['strength'] as String?) ?? '';
    final doseForm = (d['doseForm'] as String?) ?? '';
    final instructions = (d['instructions'] as String?) ?? '';

    return HulkaBoard(
      title: '$medicine${strength.isNotEmpty ? '  $strength' : ''}',
      subtitle: [
        if (doseForm.isNotEmpty) doseForm,
        if (instructions.isNotEmpty) instructions,
      ].join(' · '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Times list
          if (times.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: times
                  .map(
                    (t) => Chip(
                      label: Text(t),
                      backgroundColor: HulkaLook.linen,
                      labelStyle: const TextStyle(
                        color: HulkaLook.ink,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: HulkaLook.copper.withValues(alpha: 0.3),
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 10),
          // Status chip + next dose
          Row(
            children: [
              Flexible(
                child: _StatusChip(taken: taken, next: next, now: now),
              ),
              const Spacer(),
              if (!taken)
                FilledButton.tonal(
                  onPressed: onMarkTaken,
                  style: FilledButton.styleFrom(
                    backgroundColor: HulkaLook.pulse.withValues(alpha: 0.12),
                    foregroundColor: HulkaLook.pulse,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Mark taken'),
                ),
            ],
          ),
          if (taken && next != null)
            Text(
              'Next dose in ${next.difference(now).inHours}h ${next.difference(now).inMinutes % 60}m',
            ),
          const SizedBox(height: 4),
          // Cancel link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: HulkaLook.ember,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Cancel reminder'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.taken,
    required this.next,
    required this.now,
  });

  final bool taken;
  final DateTime? next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (taken) {
      return Chip(
        avatar: const Icon(Icons.check_circle, color: Colors.white, size: 16),
        label: const Text(
          'Dose recorded',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );
    }
    if (next != null) {
      final minutes = next!.difference(now).inMinutes;
      final label = 'Next in ${minutes ~/ 60}h ${minutes % 60}m';
      return Chip(
        avatar: const Icon(Icons.alarm, color: Colors.white, size: 16),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: const Color(0xFFE65100),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );
    }
    return const SizedBox.shrink();
  }
}
