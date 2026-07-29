/// Small, dependency-free date helpers shared by the scheduler and stats.
extension DateUtilsX on DateTime {
  DateTime get startOfDay => DateTime(year, month, day);

  /// `yyyy-MM-dd` local day key used across SQLite day-bucketed tables.
  String get dayKey {
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$year-$m-$d';
  }

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

/// Minutes since local midnight — the unit quiet-hours windows are stored in.
int minutesOfDay(DateTime t) => t.hour * 60 + t.minute;

/// A time-of-day window such as "21:30 → 06:00" (may wrap past midnight).
class TimeWindow {
  const TimeWindow(this.startMinutes, this.endMinutes);

  final int startMinutes;
  final int endMinutes;

  bool contains(DateTime t) {
    final m = minutesOfDay(t);
    if (startMinutes <= endMinutes) {
      return m >= startMinutes && m < endMinutes;
    }
    // Wraps midnight, e.g. 22:00 → 06:30.
    return m >= startMinutes || m < endMinutes;
  }

  /// Next moment *outside* the window at or after [t] (used to defer a
  /// notification that would land inside quiet hours). A window always ends
  /// at [endMinutes] — on the following day when it wraps past midnight.
  DateTime nextExit(DateTime t) {
    if (!contains(t)) return t;
    var exit = DateTime(t.year, t.month, t.day)
        .add(Duration(minutes: endMinutes));
    while (!exit.isAfter(t)) {
      exit = exit.add(const Duration(days: 1));
    }
    return exit;
  }
}
