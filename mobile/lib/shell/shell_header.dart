import 'package:flutter/material.dart';

import '../api/models/auth.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';
import 'app_tab.dart';

/// The header of every signed-in page, like the web's on a phone
/// (web/src/SignedInShell.tsx): Chats on the left with a dot when something
/// waits, "Hacky" and the event in the middle, then People, Home and my
/// avatar (Me). The page that's open is highlighted.
class ShellHeader extends StatelessWidget implements PreferredSizeWidget {
  const ShellHeader({
    super.key,
    required this.me,
    required this.eventName,
    required this.current,
    required this.waiting,
    required this.onOpen,
  });

  final Me me;

  /// Null before the user joins an event.
  final String? eventName;
  final AppTab current;

  /// Requests to answer plus unread messages; the Chats button shows a dot.
  final int waiting;
  final ValueChanged<AppTab> onOpen;

  /// Tests find a button with `find.byKey(ShellHeader.keyOf(tab))`. The key
  /// of [AppTab.hacky] is on the Ask Hacky button.
  static Key keyOf(AppTab tab) => Key('tab-${tab.name}');

  static const height = 60.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  /// The three buttons on the right, with the header's side padding.
  static const _sideWidth = 148.0;

  /// What "Hacky" over an event's name needs to sit in the middle.
  static const _titleRoom = 170.0;

  @override
  Widget build(BuildContext context) {
    // The title sits in the middle when both sides leave it room; on a
    // phone it moves next to Chats so the event's name still fits.
    final room = MediaQuery.sizeOf(context).width - 2 * _sideWidth;
    final centered = room >= _titleRoom;
    final title = _Title(
      eventName: eventName,
      centered: centered,
      onTap: () => onOpen(AppTab.hacky),
    );
    return Material(
      color: AppColors.paper,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (centered)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: room),
                    child: title,
                  ),
                Row(
                  children: [
                    _HeaderButton(
                      tab: AppTab.chats,
                      current: current,
                      onOpen: onOpen,
                      tooltip: waiting > 0 ? 'Chats, $waiting waiting' : 'Chats',
                      dot: waiting > 0,
                    ),
                    if (centered)
                      const Spacer()
                    else
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: title,
                        ),
                      ),
                    _HeaderButton(
                      tab: AppTab.people,
                      current: current,
                      onOpen: onOpen,
                    ),
                    _HeaderButton(
                      tab: AppTab.home,
                      current: current,
                      onOpen: onOpen,
                    ),
                    _MeButton(
                      me: me,
                      selected: current == AppTab.me,
                      onTap: () => onOpen(AppTab.me),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Hacky" over the event's name. Tapping it opens Hacky.
class _Title extends StatelessWidget {
  const _Title({
    required this.eventName,
    required this.centered,
    required this.onTap,
  });

  final String? eventName;
  final bool centered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hacky, ${eventName ?? 'no hackathon yet'}',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centered
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                'Hacky',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  height: 1.15,
                ),
              ),
              Text(
                eventName ?? 'No hackathon yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One page's icon. Blue on a light wash while that page is open.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tab,
    required this.current,
    required this.onOpen,
    this.tooltip,
    this.dot = false,
  });

  final AppTab tab;
  final AppTab current;
  final ValueChanged<AppTab> onOpen;
  final String? tooltip;

  /// The small blue dot: something is waiting there.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final selected = tab == current;
    return IconButton(
      key: ShellHeader.keyOf(tab),
      tooltip: tooltip ?? tab.label,
      isSelected: selected,
      onPressed: () => onOpen(tab),
      style: IconButton.styleFrom(
        foregroundColor: selected ? AppColors.action : AppColors.muted,
        backgroundColor: selected ? AppColors.hover : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        fixedSize: const Size(44, 44),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(tab.icon, size: 24),
          if (dot)
            Positioned(
              top: -2,
              right: -3,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.action,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.paper, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// My avatar, which opens Me. A blue ring while Me is open.
class _MeButton extends StatelessWidget {
  const _MeButton({
    required this.me,
    required this.selected,
    required this.onTap,
  });

  final Me me;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'My profile',
      child: InkWell(
        key: ShellHeader.keyOf(AppTab.me),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.hover : null,
            border: Border.all(
              color: selected ? AppColors.action : AppColors.paper,
              width: 2,
            ),
          ),
          child: PersonAvatar.ofProfile(me.profile, size: 34),
        ),
      ),
    );
  }
}
