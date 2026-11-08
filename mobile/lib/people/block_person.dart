import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/requests.dart';
import '../widgets/confirm_action_dialog.dart';
import 'person_labels.dart';

/// ••• → Block on 07 Person profile and 11 Chat thread: a confirm step that
/// says what blocking does, then `POST /api/blocks`. Once it worked, the
/// screen closes (it shows someone I just blocked) and a snackbar says so on
/// the screen below.
abstract final class BlockPerson {
  static const menuLabel = 'Block';

  static String title(String name) => 'Block $name?';

  /// What the contract says a block does: it applies in every event and
  /// both ways, and hides profiles, search results and messages.
  static String message(String name) {
    final first = PersonLabels.firstName(name);
    return 'You and $first won’t see each other in search or on Hacky, '
        'can’t open each other’s profile and can’t message each other. '
        'This applies in every event.';
  }

  static String done(String name) => 'You blocked $name.';

  /// Confirms, blocks, then closes the screen with a snackbar. Returns
  /// whether they were blocked (false when cancelled).
  static Future<bool> confirmAndLeave(
    BuildContext context, {
    required ApiClient api,
    required String userId,
    required String name,
  }) async {
    final blocked = await ConfirmActionDialog.show(
      context,
      title: title(name),
      message: message(name),
      confirmLabel: menuLabel,
      busyLabel: 'Blocking…',
      action: () => api.blockUser(BlockBody(userId: userId)),
    );
    if (!blocked || !context.mounted) return blocked;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(done(name))));
    Navigator.of(context).pop();
    return true;
  }
}
