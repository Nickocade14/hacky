// The knit Hacky's look, saved in `PublicProfile.hackyStyle` (docs/openapi.yaml
// HackyStyle). Options and names come from the original Hacky
// (seeko-codes/hacky react/src/mascot-data.js).

import 'package:flutter/painting.dart';

/// One choice in the Hacky style sheet: the id that's saved and its label.
class HackyStyleOption {
  const HackyStyleOption(this.id, this.label);

  final String id;
  final String label;
}

/// A color option, with the swatch the knit body is tinted to.
class HackyColorOption extends HackyStyleOption {
  const HackyColorOption(super.id, super.label, this.swatch);

  final Color swatch;
}

/// The color, flair and move of the knit Hacky. Unknown or missing values
/// fall back to the defaults, like the original app.
class HackyLook {
  const HackyLook({
    this.color = defaultColor,
    this.flair = defaultFlair,
    this.move = defaultMove,
  });

  static const defaultColor = 'original';
  static const defaultFlair = 'none';
  static const defaultMove = 'idle';

  // These are the mascot's own colors (part of the saved style), not app
  // colors, so they live here and not in theme.dart.
  static const colors = [
    HackyColorOption('original', 'Original', Color(0xFF30445F)),
    HackyColorOption('berry', 'Berry', Color(0xFFB35CD0)),
    HackyColorOption('mint', 'Mint', Color(0xFF58BC94)),
    HackyColorOption('sunset', 'Sunset', Color(0xFFEC886A)),
    HackyColorOption('rose', 'Rose', Color(0xFFE77BB6)),
    HackyColorOption('ice', 'Ice', Color(0xFF85CFE4)),
  ];

  static const flairs = [
    HackyStyleOption('none', 'Just Hacky'),
    HackyStyleOption('stars', 'Star power'),
    HackyStyleOption('hearts', 'Love bug'),
  ];

  static const moves = [
    HackyStyleOption('idle', 'Chill'),
    HackyStyleOption('bounce', 'Happy bounce'),
    HackyStyleOption('dance', 'Happy dance'),
    HackyStyleOption('hype', 'Victory hop'),
  ];

  final String color;
  final String flair;
  final String move;

  /// Reads a saved `hackyStyle`. "sparks" is the old name for "stars".
  factory HackyLook.of(Map<String, dynamic> style) {
    String pick(String key, List<HackyStyleOption> options, String fallback) {
      var value = style[key];
      if (key == 'flair' && value == 'sparks') value = 'stars';
      return options.any((o) => o.id == value) ? value as String : fallback;
    }

    return HackyLook(
      color: pick('color', colors, defaultColor),
      flair: pick('flair', flairs, defaultFlair),
      move: pick('move', moves, defaultMove),
    );
  }

  HackyLook copyWith({String? color, String? flair, String? move}) =>
      HackyLook(
        color: color ?? this.color,
        flair: flair ?? this.flair,
        move: move ?? this.move,
      );

  /// [style] with this look on top. Other keys (`avatar`, unknown ones) stay;
  /// Hacky is always knit.
  Map<String, dynamic> applyTo(Map<String, dynamic> style) => {
    ...style,
    'look': 'knit',
    'color': color,
    'flair': flair,
    'move': move,
  };

  HackyColorOption get colorOption => colors.firstWhere((c) => c.id == color);

  /// The tint for the knit mascot, or null for the original colors. Each
  /// pixel becomes the swatch times its brightness relative to the cream body
  /// (about 0.87), so the knit shading stays, like the original app's filter.
  ColorFilter? get filter {
    if (color == defaultColor) return null;
    const bodyLuma = 0.87;
    final swatch = colorOption.swatch;
    final channels = [swatch.r, swatch.g, swatch.b];
    return ColorFilter.matrix([
      for (final v in channels) ...[
        0.299 * v / bodyLuma,
        0.587 * v / bodyLuma,
        0.114 * v / bodyLuma,
        0,
        0,
      ],
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  bool operator ==(Object other) =>
      other is HackyLook &&
      other.color == color &&
      other.flair == flair &&
      other.move == move;

  @override
  int get hashCode => Object.hash(color, flair, move);
}
