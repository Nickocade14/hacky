// Typed reads from decoded JSON. A missing or wrong-typed field throws a
// FormatException naming the field, which ApiClient reports as `invalid_response`.

String readString(Map<String, dynamic> json, String key) =>
    _read<String>(json, key, 'a string');

String? readNullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('"$key" must be a string or null');
}

bool readBool(Map<String, dynamic> json, String key) =>
    _read<bool>(json, key, 'a boolean');

Map<String, dynamic> readObject(Map<String, dynamic> json, String key) =>
    _read<Map<String, dynamic>>(json, key, 'an object');

DateTime readDateTime(Map<String, dynamic> json, String key) {
  final value = readString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('"$key" must be an ISO 8601 date');
  return parsed;
}

List<T> readList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) fromJson,
) {
  final list = _read<List<dynamic>>(json, key, 'an array');
  return [
    for (final item in list)
      if (item is Map<String, dynamic>)
        fromJson(item)
      else
        throw FormatException('"$key" must only contain objects'),
  ];
}

T readEnum<T extends Enum>(
  Map<String, dynamic> json,
  String key,
  List<T> values,
) {
  final name = readString(json, key);
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('"$key" has an unknown value "$name"');
}

T _read<T>(Map<String, dynamic> json, String key, String expected) {
  final value = json[key];
  if (value is T) return value;
  throw FormatException('"$key" must be $expected');
}
