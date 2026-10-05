/// Tolerant, typed readers for backend JSON. Keeps `dynamic` out of the
/// rest of the app: models read through these and expose real types.
String? readString(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// Reads an id that the backend may send as a plain string or as an
/// `{ _id: ... }` / `{ id: ... }` object.
String? readId(Object? v) {
  if (v is Map) return readString(v['_id'] ?? v['id']);
  return readString(v);
}

List<String> readStringList(Object? v) =>
    v is List ? v.where((e) => e != null).map((e) => e.toString()).toList() : const <String>[];

Map<String, dynamic> asJsonMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> asJsonMapList(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

int? readInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

bool readBool(Object? v, {bool fallback = false}) => v is bool ? v : fallback;

/// Tolerant date reader for backend JSON: ISO-8601 strings (the normal
/// serialization of a Mongo Date), `{ "$date": ... }` extended JSON, or an
/// epoch-milliseconds number. Returns null when it cannot be understood.
DateTime? readDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Map) return readDate(v[r'$date']);
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

/// `String` that is never null ('' when missing) - for display fields.
String readText(Object? v) => readString(v) ?? '';

/// Number reader that accepts ints, doubles and numeric strings (Mongo numbers arrive as JSON numbers).
double? readNum(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '');
}

/// The calendar day (y/m/d) a backend `Date` was WRITTEN for, when the writer sent a plain `YYYY-MM-DD` (the web does and so
/// does this app): Mongo stores UTC midnight, so the UTC components of the stored instant ARE the day, whatever the device
/// timezone. Returned as a local-midnight [DateTime] of that y/m/d (compare with `DateTime(now.year, now.month, now.day)`).
DateTime? storedCalendarDay(DateTime? instant) {
  if (instant == null) return null;
  final u = instant.toUtc();
  return DateTime(u.year, u.month, u.day);
}

/// `YYYY-MM-DD` of a local calendar date: the wire form for date-only fields (valid for `@IsDateString`, stored as UTC midnight).
String wireDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
