import 'dart:math';

// FSRS-4.5 implementation.
// Reference: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm

enum FsrsRating { again, hard, good, easy }

// Default FSRS-4.5 weights (trained on large dataset).
const List<double> _w = [
  0.4072, 1.1829, 3.1262, 4.6,    // w0–w3: initial stability per rating
  7.2102, 0.5316, 1.0651, 0.0589, // w4–w7
  1.5330, 0.14,   1.0,   1.9395,  // w8–w11
  0.11,   0.29,   2.29,  0.042,   // w12–w15
  0.295,  2.2,                    // w16–w17
];

const double _decay = -0.5;
const double _factor = 19.0 / 81.0;
const double _requestRetention = 0.9;

class FsrsSchedule {
  const FsrsSchedule({
    required this.stability,
    required this.difficulty,
    required this.scheduledDays,
    required this.lapses,
  });

  final double stability;
  final double difficulty;
  final int scheduledDays;
  final int lapses;
}

class FSRS {
  /// Schedule a card.
  ///
  /// [stability] and [difficulty] are the card's current values.
  /// Pass 0.0 / 0.0 for a brand-new card (first review).
  /// [elapsedDays] is how many days since the last review (0 for new cards).
  /// [lapses] is the current lapse count (incremented here on Again).
  static FsrsSchedule schedule({
    required FsrsRating rating,
    required double stability,
    required double difficulty,
    required int elapsedDays,
    required int lapses,
    required int reps,
  }) {
    final r = rating.index + 1; // 1–4

    double newS;
    double newD;
    int newLapses = lapses;

    if (reps == 0) {
      // ── First review ──────────────────────────────────────────────────────
      newS = _w[rating.index]; // w0–w3
      newD = (_w[4] - exp(_w[5] * (r - 1)) + 1).clamp(1.0, 10.0);
    } else {
      // ── Subsequent review ─────────────────────────────────────────────────
      final d = difficulty;
      final s = stability;
      final retrievability = _forgettingCurve(elapsedDays.toDouble(), s);

      // Update difficulty (with mean-reversion toward initial difficulty).
      final dPrime = d - _w[6] * (r - 3);
      newD = (_w[7] * _w[4] + (1 - _w[7]) * dPrime).clamp(1.0, 10.0);

      if (rating == FsrsRating.again) {
        // Forgotten — relearning stability.
        newLapses = lapses + 1;
        newS = _nextStabilityForgetting(d, s, retrievability);
      } else {
        // Recalled — update stability.
        newS = _nextStabilityRecall(d, s, retrievability, r);
      }
    }

    newS = max(newS, 0.1); // guard against degenerate values
    final interval = _nextInterval(newS);

    return FsrsSchedule(
      stability: newS,
      difficulty: newD,
      scheduledDays: interval,
      lapses: newLapses,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static double _forgettingCurve(double t, double s) =>
      pow(1 + _factor * t / s, _decay).toDouble();

  static double _nextStabilityRecall(double d, double s, double r, int rating) {
    final hardPenalty = rating == 2 ? _w[15] : 1.0;
    final easyBonus = rating == 4 ? _w[16] : 1.0;
    return s *
        (exp(_w[8]) *
                (11 - d) *
                pow(s, -_w[9]) *
                (exp(_w[10] * (1 - r)) - 1) *
                hardPenalty *
                easyBonus +
            1);
  }

  static double _nextStabilityForgetting(double d, double s, double r) =>
      _w[11] *
      pow(d, -_w[12]) *
      (pow(s + 1, _w[13]) - 1) *
      exp(_w[14] * (1 - r));

  static int _nextInterval(double s) {
    final interval = s / _factor * (pow(_requestRetention, 1.0 / _decay) - 1);
    return interval.round().clamp(1, 36500);
  }
}
