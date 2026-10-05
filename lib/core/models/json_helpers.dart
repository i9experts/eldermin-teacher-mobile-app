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
