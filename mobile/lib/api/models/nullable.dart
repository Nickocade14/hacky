/// A value for a nullable field in a partial update (PATCH) body.
///
/// The field itself being null means "leave it as it is" (not sent);
/// `Nullable(null)` sends `null`, which clears it.
class Nullable<T> {
  const Nullable(this.value);

  final T? value;
}

/// Adds [key] to [json] when [field] is set. Enums are sent by name.
void putNullable<T>(Map<String, dynamic> json, String key, Nullable<T>? field) {
  if (field == null) return;
  final value = field.value;
  json[key] = value is Enum ? value.name : value;
}
