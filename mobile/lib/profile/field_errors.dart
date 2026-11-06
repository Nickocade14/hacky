import '../api/api_exception.dart';
import 'profile_draft.dart';

/// Puts the server's `error.details` (docs/openapi.yaml ApiError) under the
/// form fields they're about.
abstract final class FieldErrors {
  /// The field each detail points at. A `path` can be a list
  /// (`["links", "github"]`), a dotted string (`links.github`) or a JSON
  /// pointer (`/links/github`); a path deeper than a field (`["skills", 3]`)
  /// still lands on that field. Details that match no field are left out.
  static Map<ProfileField, String> of(List<ApiErrorDetail> details) {
    final errors = <ProfileField, String>{};
    for (final detail in details) {
      final field = fieldAt(detail.path);
      if (field != null) {
        errors.putIfAbsent(field, () => detail.message ?? 'Check this field.');
      }
    }
    return errors;
  }

  static ProfileField? fieldAt(Object? path) {
    final segments = _segments(path);
    ProfileField? best;
    var bestLength = 0;
    for (final field in ProfileField.values) {
      final fieldSegments = field.path.split('.');
      if (fieldSegments.length > bestLength &&
          _startsWith(segments, fieldSegments)) {
        best = field;
        bestLength = fieldSegments.length;
      }
    }
    return best;
  }

  static List<String> _segments(Object? path) => switch (path) {
    final List<dynamic> list => [for (final part in list) '$part'],
    final String text => [
      for (final part in text.split(RegExp(r'[./]')))
        if (part.isNotEmpty) part,
    ],
    _ => const [],
  };

  static bool _startsWith(List<String> list, List<String> prefix) {
    if (list.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (list[i] != prefix[i]) return false;
    }
    return true;
  }
}
