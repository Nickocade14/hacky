// "Change Hacky style" on 08 My profile: pick the knit Hacky's color, flair
// and move, like the original Customizer (seeko-codes/hacky
// react/src/Customizer.jsx). The pick becomes part of the unsaved profile;
// Save sends it with the rest.

import 'package:flutter/material.dart';

import '../profile/hacky_style.dart';
import '../theme.dart';
import 'app_widgets.dart';
import 'auth_widgets.dart';
import 'profile_fields.dart';

/// The knit Hacky in [look]'s color, with its flair (stars or hearts) around.
class StyledHacky extends StatelessWidget {
  const StyledHacky({super.key, required this.look, this.height = 72});

  final HackyLook look;
  final double height;

  @override
  Widget build(BuildContext context) {
    final filter = look.filter;
    final mascot = KnitHacky(height: height);
    final icon = switch (look.flair) {
      'stars' => Icons.star,
      'hearts' => Icons.favorite,
      _ => null,
    };
    return Semantics(
      label: 'Your Hacky: ${look.colorOption.label}',
      child: SizedBox(
        width: height * 1.1,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (filter == null)
              mascot
            else
              ColorFiltered(colorFilter: filter, child: mascot),
            if (icon != null)
              for (final (x, y, size) in const [
                (-0.95, -0.85, 0.2),
                (0.95, -0.55, 0.16),
                (-0.85, 0.6, 0.14),
              ])
                Align(
                  alignment: Alignment(x, y),
                  child: ExcludeSemantics(
                    child: Icon(
                      icon,
                      size: height * size,
                      color: look.colorOption.swatch,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// The bottom sheet: a preview on top, then Color, Flair and Moves.
/// Closes with the picked look, or null when dismissed.
class HackyStyleSheet extends StatefulWidget {
  const HackyStyleSheet({super.key, required this.initial});

  final HackyLook initial;

  static const doneKey = Key('hacky-style-done');

  static Future<HackyLook?> show(BuildContext context, HackyLook initial) =>
      showModalBottomSheet<HackyLook>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => HackyStyleSheet(initial: initial),
      );

  @override
  State<HackyStyleSheet> createState() => _HackyStyleSheetState();
}

class _HackyStyleSheetState extends State<HackyStyleSheet> {
  late HackyLook _look = widget.initial;

  List<(String, String)> _options(List<HackyStyleOption> options) => [
    for (final option in options) (option.id, option.label),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 18,
          children: [
            const PageHeading(
              eyebrow: 'HACKY STYLE',
              title: 'Make Hacky yours',
              body: TextSpan(
                text: 'People see your Hacky next to your name. '
                    'Save your profile to keep it.',
              ),
            ),
            Center(child: StyledHacky(look: _look, height: 120)),
            _ColorPicker(
              value: _look.color,
              onChanged: (color) =>
                  setState(() => _look = _look.copyWith(color: color)),
            ),
            ChoicePicker<String>(
              label: 'Flair',
              options: _options(HackyLook.flairs),
              value: _look.flair,
              onChanged: (flair) => setState(
                () => _look = _look.copyWith(
                  flair: flair ?? HackyLook.defaultFlair,
                ),
              ),
            ),
            ChoicePicker<String>(
              label: 'Moves',
              options: _options(HackyLook.moves),
              value: _look.move,
              onChanged: (move) => setState(
                () => _look = _look.copyWith(
                  move: move ?? HackyLook.defaultMove,
                ),
              ),
            ),
            FilledButton(
              key: HackyStyleSheet.doneKey,
              onPressed: () => Navigator.of(context).pop(_look),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(49),
              ),
              child: const Text('Use this style'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round swatches with their names.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        const FieldLabel('Color'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in HackyLook.colors)
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: option.swatch),
                label: Text(option.label),
                selected: option.id == value,
                showCheckmark: false,
                onSelected: (_) => onChanged(option.id),
                selectedColor: AppColors.hover,
                backgroundColor: AppColors.white,
                side: BorderSide(
                  color: option.id == value ? AppColors.action : AppColors.line,
                ),
                labelStyle: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                shape: const StadiumBorder(),
              ),
          ],
        ),
      ],
    );
  }
}
