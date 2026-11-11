import 'package:flutter/widgets.dart';

/// Tells a page it's inside the signed-in shell: the shell already shows the
/// header, and the Ask Hacky button floats over the bottom of the page.
/// Pushed screens (07, 09, 11) aren't under it and keep their own title bar.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.bottomClearance,
    required super.child,
  });

  /// Space to leave under the last item so the Ask Hacky button doesn't
  /// cover it. 0 on Hacky, where the button isn't shown.
  final double bottomClearance;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      oldWidget.bottomClearance != bottomClearance;
}
