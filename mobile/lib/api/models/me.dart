// `UpdateProfileBody` from docs/openapi.yaml. `Me` and `PublicProfile` live in
// auth.dart because the login response returns them.

import 'auth.dart';
import 'nullable.dart';

/// `UpdateProfileBody`: `PATCH /api/me/profile`. Send only the fields to
/// change; the contract requires at least one.
class UpdateProfileBody {
  const UpdateProfileBody({this.name, this.bio, this.hackyStyle, this.links});

  final String? name;

  /// `Nullable(null)` clears the bio.
  final Nullable<String>? bio;

  /// `HackyStyle`: avatar options. Unknown keys pass through.
  final Map<String, dynamic>? hackyStyle;
  final ProfileLinks? links;

  bool get isEmpty =>
      name == null && bio == null && hackyStyle == null && links == null;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': ?name,
      'hackyStyle': ?hackyStyle,
      if (links != null) 'links': links!.toJson(),
    };
    putNullable(json, 'bio', bio);
    return json;
  }
}
