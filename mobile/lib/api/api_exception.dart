/// An API error, parsed from the contract's `{ "error": { "code", "message", "details"? } }`.
///
/// When the request never got a contract-shaped answer, the client uses its
/// own codes instead (they are not in docs/openapi.yaml):
/// - `network_error`: no connection or the request failed to send
/// - `timeout`: no response in time
/// - `invalid_response`: a success response that doesn't match the contract
/// - `http_<status>`: an error status without the JSON error body (e.g. an Nginx 502 page)
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details = const [],
  });

  /// The HTTP status, or null when there was no response.
  final int? statusCode;
  final String code;
  final String message;

  /// Field-level problems, when the input was invalid.
  final List<ApiErrorDetail> details;

  /// Parses an error response body. Falls back to `http_<status>` when the
  /// body isn't the contract's error shape.
  factory ApiException.fromResponse(int statusCode, Object? body) {
    final error = body is Map<String, dynamic> ? body['error'] : null;
    if (error is Map<String, dynamic> &&
        error['code'] is String &&
        error['message'] is String) {
      final details = error['details'];
      return ApiException(
        statusCode: statusCode,
        code: error['code'] as String,
        message: error['message'] as String,
        details: [
          if (details is List)
            for (final item in details)
              if (item is Map<String, dynamic>) ApiErrorDetail.fromJson(item),
        ],
      );
    }
    return ApiException(
      statusCode: statusCode,
      code: 'http_$statusCode',
      message: 'Request failed with status $statusCode',
    );
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// One entry of `error.details`.
class ApiErrorDetail {
  const ApiErrorDetail({this.path, this.message});

  /// Where the problem is, as the server sent it (any JSON value).
  final Object? path;
  final String? message;

  factory ApiErrorDetail.fromJson(Map<String, dynamic> json) => ApiErrorDetail(
        path: json['path'],
        message: json['message'] is String ? json['message'] as String : null,
      );
}
