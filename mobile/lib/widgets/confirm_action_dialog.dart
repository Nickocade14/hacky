import 'package:flutter/material.dart';

import '../auth/submit_action.dart';
import '../theme.dart';
import 'auth_widgets.dart';

/// "Are you sure?" for an action that can't be undone (Block on 07 and 11,
/// Unsend on 11). The confirm button runs [action] and shows [busyLabel]
/// while it does; a failure stays in the dialog with its error, so the user
/// can try again or cancel. Closes with true once [action] succeeds.
class ConfirmActionDialog extends StatefulWidget {
  const ConfirmActionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.busyLabel,
    required this.action,
  });

  static const confirmKey = Key('confirm-action');
  static const cancelKey = Key('confirm-cancel');

  final String title;
  final String message;
  final String confirmLabel;
  final String busyLabel;
  final Future<void> Function() action;

  /// Shows the dialog; true when the action ran and succeeded.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required String busyLabel,
    required Future<void> Function() action,
  }) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmActionDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        busyLabel: busyLabel,
        action: action,
      ),
    );
    return done ?? false;
  }

  @override
  State<ConfirmActionDialog> createState() => _ConfirmActionDialogState();
}

class _ConfirmActionDialogState extends State<ConfirmActionDialog>
    with SubmitAction<ConfirmActionDialog> {
  Future<void> _confirm() => runAction(() async {
    await widget.action();
    if (mounted) Navigator.of(context).pop(true);
  });

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return PopScope(
      // Waits for the request instead of leaving it running unseen.
      canPop: !busy,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Text(
              widget.message,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            if (error != null) Notice(error, error: true),
          ],
        ),
        actions: [
          TextButton(
            key: ConfirmActionDialog.cancelKey,
            onPressed: busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: ConfirmActionDialog.confirmKey,
            onPressed: busy ? null : _confirm,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(busy ? widget.busyLabel : widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}
