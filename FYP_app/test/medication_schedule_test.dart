import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_app/services/medication/medication_service.dart';

void main() {
  MedicationReminder dose({int hour = 8, int minute = 30, int? snoozedUntilMs}) {
    return MedicationReminder(
      id: 'med_morning',
      title: '早上藥物／血壓藥',
      note: '飯後 1 粒 · 溫水送服',
      hour: hour,
      minute: minute,
      snoozedUntilMs: snoozedUntilMs,
    );
  }

  test('a dose is due at its minute and not one minute earlier', () {
    final item = dose();
    expect(item.isPastScheduledTime(DateTime(2026, 11, 15, 8, 29)), isFalse);
    expect(item.isPastScheduledTime(DateTime(2026, 11, 15, 8, 30)), isTrue);
    expect(item.isPastScheduledTime(DateTime(2026, 11, 15, 15, 0)), isTrue);
  });

  test('snooze stays active until the stored time', () {
    final until = DateTime(2026, 11, 15, 8, 40).millisecondsSinceEpoch;
    final item = dose(snoozedUntilMs: until);
    expect(item.isSnoozed(DateTime(2026, 11, 15, 8, 39)), isTrue);
    expect(item.isSnoozed(DateTime(2026, 11, 15, 8, 40)), isFalse);
    expect(dose().isSnoozed(DateTime(2026, 11, 15, 8, 30)), isFalse);
  });
}
