import 'package:flutter/material.dart';

import '../theme.dart';

/// The rounded white box around a message field and its send button, like
/// the web's composer (web/src/hacky.css .hk-composer). Shared by the Hacky
/// chat and chat threads. Its border turns blue while the field has the
/// focus.
class MessageBox extends StatefulWidget {
  const MessageBox({super.key, required this.field, required this.send});

  /// A [TextField] with [decoration]: this box draws its border.
  final Widget field;
  final Widget send;

  static TextStyle get textStyle => TextStyle(
    color: AppColors.ink,
    fontSize: 16,
    height: 1.4,
  );

  /// A field with no box of its own.
  static InputDecoration decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.muted),
    counterText: '',
    isDense: true,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    contentPadding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
  );

  @override
  State<MessageBox> createState() => _MessageBoxState();
}

class _MessageBoxState extends State<MessageBox> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _focused ? AppColors.focus : AppColors.line,
            width: _focused ? 2 : 1,
          ),
        ),
        child: Padding(
          // The wider border must not move the field.
          padding: EdgeInsets.all(_focused ? 0 : 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: widget.field),
              Padding(padding: const EdgeInsets.all(5), child: widget.send),
            ],
          ),
        ),
      ),
    );
  }
}

/// The square blue send button with an up arrow. Grey while [onPressed] is
/// null; a small spinner while [busy].
class SendButton extends StatelessWidget {
  const SendButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Send',
    this.busy = false,
    this.buttonKey,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final bool busy;

  /// The key of the button itself, for tests.
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: busy
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.disabledInk,
              ),
            )
          : const Icon(Icons.arrow_upward, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.action,
        foregroundColor: AppColors.onAction,
        disabledBackgroundColor: AppColors.disabled,
        disabledForegroundColor: AppColors.disabledInk,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        fixedSize: const Size(44, 44),
      ),
    );
  }
}
