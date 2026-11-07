/// Fischer time control. Zero initial minutes uses one increment to give
/// each player time to make their first move.
class TimeControl {
  const TimeControl({
    this.enabled = false,
    this.minutes = 10,
    this.incrementSeconds = 0,
  });

  final bool enabled;
  final int minutes;
  final int incrementSeconds;

  bool get isValid =>
      minutes >= 0 &&
      minutes <= 180 &&
      incrementSeconds >= 0 &&
      incrementSeconds <= 180 &&
      (!enabled || minutes > 0 || incrementSeconds > 0);

  int get initialTimeMs => minutes * 60000;

  int get startingTimeMs =>
      minutes > 0 ? initialTimeMs : incrementSeconds * 1000;

  TimeControl copyWith({bool? enabled, int? minutes, int? incrementSeconds}) =>
      TimeControl(
        enabled: enabled ?? this.enabled,
        minutes: minutes ?? this.minutes,
        incrementSeconds: incrementSeconds ?? this.incrementSeconds,
      );

  void validate() {
    if (!isValid) throw ArgumentError('Choose initial time or an increment.');
  }
}
