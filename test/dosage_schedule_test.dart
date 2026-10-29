import 'package:flutter_test/flutter_test.dart';
import 'package:hulka/services/dosage_schedule.dart';

void main() {
  test('next dose rolls over midnight and ignores malformed times', () {
    expect(
      DosageSchedule.nextDose([
        '08:00',
        'bad',
        '25:00',
      ], DateTime(2026, 10, 29, 23)),
      DateTime(2026, 10, 30, 8),
    );
  });
  test('recording morning dose does not mark evening dose taken', () {
    final morning = DateTime(2026, 10, 29, 8, 5);
    expect(
      DosageSchedule.takenForCurrentDose(morning, [
        '08:00',
        '20:00',
      ], DateTime(2026, 10, 29, 9)),
      isTrue,
    );
    expect(
      DosageSchedule.takenForCurrentDose(morning, [
        '08:00',
        '20:00',
      ], DateTime(2026, 10, 29, 20)),
      isFalse,
    );
  });
}
