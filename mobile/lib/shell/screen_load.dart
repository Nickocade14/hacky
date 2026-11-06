import 'package:flutter/widgets.dart';

import '../api/api_exception.dart';
import '../auth/error_text.dart';
import '../routes.dart';

/// Loading and error state for a signed-in screen that loads data when it
/// opens, like [SubmitAction] for forms. Call [runLoad] from `initState` and
/// again from "Try again".
///
/// A 401 means the session expired (the API client already forgot the token),
/// so it goes back to log in.
mixin ScreenLoad<T extends StatefulWidget> on State<T> {
  /// True until the first load finishes, and during each retry.
  bool loading = true;

  /// What went wrong in the last load, for [ProblemView].
  String? problem;

  Future<void> runLoad(Future<void> Function() load) async {
    // From initState the fields already say "loading"; setState is for retries.
    if (!loading || problem != null) {
      setState(() {
        loading = true;
        problem = null;
      });
    }
    try {
      await load();
      if (mounted) setState(() => loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        toLogin(context);
      } else {
        setState(() {
          loading = false;
          problem = ErrorText.of(e);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          problem = ErrorText.of(e);
        });
      }
    }
  }

  /// Clears the navigation stack and opens log in.
  static void toLogin(BuildContext context) =>
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (_) => false);
}
