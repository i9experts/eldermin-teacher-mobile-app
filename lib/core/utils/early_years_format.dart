import '../models/early_years/ece_models.dart';

/// "3 years 2 months", "11 months", "2 weeks"; null when there is no (or a future) date of birth.
String? ageLabel(DateTime? dob, DateTime now) {
  if (dob == null) return null;
  var months = (now.year - dob.year) * 12 + (now.month - dob.month);
  if (now.day < dob.day) months--;
  if (months < 0) return null;
  if (months < 1) {
    final days = now.difference(dob).inDays;
    if (days < 0) return null;
    final weeks = days ~/ 7;
    return weeks < 1 ? 'Newborn' : '$weeks ${weeks == 1 ? 'week' : 'weeks'}';
  }
  final y = months ~/ 12, m = months % 12;
  String part(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';
  if (y == 0) return part(m, 'month');
  return m == 0 ? part(y, 'year') : '${part(y, 'year')} ${part(m, 'month')}';
}

/// Readable name for an observation type wire value ('learning_story' -> 'Learning story'); unknown values are title-cased.
String observationTypeLabel(String wire) {
  final known = kObservationTypes[wire];
  if (known != null) return known;
  final s = wire.replaceAll('_', ' ').trim();
  return s.isEmpty ? 'Observation' : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// How far along [level] is among [levels] (1-based position / count), or null when the level is not one of them.
double? levelFraction(String level, List<String> levels) {
  if (levels.isEmpty) return null;
  final i = levels.indexWhere((l) => l.trim().toLowerCase() == level.trim().toLowerCase());
  return i < 0 ? null : (i + 1) / levels.length;
}
