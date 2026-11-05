import 'package:flutter/widgets.dart';

import '../api/api_exception.dart';
import 'error_text.dart';

/// Busy and error state for a form that calls the API, like `useFormAction`
/// in web/src/components.tsx. Ignores a second submit while one is running.
mixin SubmitAction<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;

  /// The API error code of the last failure (e.g. `email_not_verified`).
  String? errorCode;

  Future<void> runAction(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      errorCode = null;
    });
    try {
      await action();
    } catch (caught) {
      if (mounted) {
        setState(() {
          error = ErrorText.of(caught);
          errorCode = caught is ApiException ? caught.code : null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
