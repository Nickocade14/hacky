import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_widgets.dart';

/// The floating way back to Hacky from every other page, like the web's
/// (web/src/workspace/workspace-shell.css .hk-ask-fab): a blue pill with the
/// knit Hacky and "Ask Hacky". [compact] is the round one for Chats, where
/// the list is busy enough.
class AskHackyButton extends StatelessWidget {
  const AskHackyButton({
    super.key,
    required this.onPressed,
    this.compact = false,
  });

  final VoidCallback onPressed;
  final bool compact;

  static const label = 'Ask Hacky';

  @override
  Widget build(BuildContext context) {
    final face = Container(
      width: compact ? 50 : 44,
      height: compact ? 50 : 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
      ),
      child: const KnitHacky(height: 44),
    );
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: AppColors.action,
        shape: const StadiumBorder(),
        elevation: 6,
        shadowColor: AppColors.action,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: compact
                ? const EdgeInsets.all(6)
                : const EdgeInsets.fromLTRB(7, 7, 20, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                face,
                if (!compact)
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.onAction,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
