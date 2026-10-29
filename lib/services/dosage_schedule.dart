class DosageReminder {
  const DosageReminder({
    required this.id,
    required this.medicine,
    required this.strength,
    required this.doseForm,
    required this.instructions,
    required this.times,
    this.active = true,
    this.lastTakenAt,
    this.prescriptionId,
  });

  final String id;
  final String medicine;
  final String strength;
  final String doseForm;
  final String instructions;
  final List<String> times;
  final bool active;
  final DateTime? lastTakenAt;
  final String? prescriptionId;

  factory DosageReminder.fromMap(String id, Map<String, dynamic> data) {
    return DosageReminder(
      id: id,
      medicine: (data['medicine'] as String?) ?? 'Medicine',
      strength: (data['strength'] as String?) ?? '',
      doseForm: (data['doseForm'] as String?) ?? '',
      instructions: (data['instructions'] as String?) ?? '',
      times: ((data['times'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      active: data['active'] != false,
      lastTakenAt: data['lastTakenAt'] is DateTime
          ? data['lastTakenAt'] as DateTime
          : null,
      prescriptionId: data['prescriptionId'] as String?,
    );
  }
}

abstract final class DosageSchedule {
  /// Parses `HH:mm` clock times. Invalid entries are skipped.
  static List<DateTime> dosesOn(DateTime day, List<String> times) {
    final start = DateTime(day.year, day.month, day.day);
    final out = <DateTime>[];
    for (final raw in times) {
      final parts = raw.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
        continue;
      }
      out.add(DateTime(start.year, start.month, start.day, h, m));
    }
    out.sort();
    return out;
  }

  static DateTime? nextDose(List<String> times, DateTime now) {
    if (times.isEmpty) return null;
    for (final dose in dosesOn(now, times)) {
      if (!dose.isBefore(now)) return dose;
    }
    final tomorrow = now.add(const Duration(days: 1));
    final nextDay = dosesOn(tomorrow, times);
    return nextDay.isEmpty ? null : nextDay.first;
  }

  static bool takenForCurrentDose(
    DateTime? lastTakenAt,
    List<String> times,
    DateTime now,
  ) {
    if (lastTakenAt == null || lastTakenAt.isAfter(now)) return false;
    final doses = [
      ...dosesOn(DateTime(now.year, now.month, now.day - 1), times),
      ...dosesOn(now, times),
    ].where((dose) => !dose.isAfter(now)).toList();
    return doses.isNotEmpty && !lastTakenAt.isBefore(doses.last);
  }

  static bool takenToday(DateTime? lastTakenAt, DateTime now) {
    if (lastTakenAt == null) return false;
    return lastTakenAt.year == now.year &&
        lastTakenAt.month == now.month &&
        lastTakenAt.day == now.day;
  }

  static String formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
