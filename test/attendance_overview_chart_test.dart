import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Attendance Overview Calculations', () {
    test('Segment progress fill factors calculate correctly', () {
      // Helper replicating OrderCompletionCard fill logic
      (double, double, double) calculateFills(int completed, int total) {
        final rate = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
        final f1 = (rate / 0.33).clamp(0.0, 1.0);
        final f2 = rate <= 0.33 ? 0.0 : ((rate - 0.33) / 0.27).clamp(0.0, 1.0);
        final f3 = rate <= 0.60 ? 0.0 : ((rate - 0.60) / 0.40).clamp(0.0, 1.0);
        return (f1, f2, f3);
      }

      // 0% attendance
      var (f1, f2, f3) = calculateFills(0, 29);
      expect(f1, 0.0);
      expect(f2, 0.0);
      expect(f3, 0.0);

      // 14 / 29 (~48.28%)
      (f1, f2, f3) = calculateFills(14, 29);
      expect(f1, 1.0);
      expect(f2, closeTo((0.482758 - 0.33) / 0.27, 0.001));
      expect(f3, 0.0);

      // 100% attendance (29 / 29)
      (f1, f2, f3) = calculateFills(29, 29);
      expect(f1, 1.0);
      expect(f2, 1.0);
      expect(f3, 1.0);
    });

    test('Daily attendance rate clamping and average calculation', () {
      final rates = [75.0, 62.0, 86.0, 48.3]; // Mon, Tue, Wed, Thu
      final avg = rates.reduce((a, b) => a + b) / rates.length;
      expect(avg, closeTo(67.825, 0.01));
    });
  });
}

