// The pieces of 12 Hacky chat, laid out like the web's Hacky pane
// (web/src/HackyPage.tsx, hacky.css): the brief with Hacky's clip and four
// starting points, grey bubbles for Hacky and blue ones for me, the thinking
// clip, and the composer with its note. Colors and fonts come from
// lib/theme.dart.

import 'package:flutter/material.dart';

import '../hacky/hacky_text.dart';
import '../theme.dart';
import 'chat_bubble.dart';
import 'message_box.dart';

const _bold = FontWeight.w700;

/// One of Hacky's clips, or its still frame when the system asks for less
/// motion. Decorative.
class HackyFilm extends StatelessWidget {
  /// Hacky rides a little green dragon and points the way.
  const HackyFilm.brief({super.key, this.height = 200}) : _name = 'hacky-chat';

  /// Hacky thinks it over.
  const HackyFilm.thinking({super.key, this.height = 72})
    : _name = 'hacky-thinking';

  final String _name;
  final double height;

  /// Tests set this: a clip that plays never lets `pumpAndSettle` finish.
  @visibleForTesting
  static bool debugStill = false;

  @override
  Widget build(BuildContext context) {
    final still = debugStill || MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: Image.asset(
        'assets/mascots/video/$_name.${still ? 'png' : 'webp'}',
        height: height,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );
  }
}

/// One of Hacky's turns: its bubbles and cards, on the left.
class HackyTurn extends StatelessWidget {
  const HackyTurn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hacky',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: children,
      ),
    );
  }
}

/// A grey bubble with Hacky's words.
class HackyBubble extends StatelessWidget {
  const HackyBubble({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ChatBubble(child: child);
}

/// Hacky's text with **bold** runs and tappable @handle mentions (→ 07).
class HackyRichText extends StatelessWidget {
  const HackyRichText(this.text, {super.key, required this.onOpenHandle});

  final String text;
  final void Function(String handle) onOpenHandle;

  static final style = ChatBubble.textStyle();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final run in HackyText.parse(text))
            if (run.handle case final handle?)
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: _Mention(
                  text: run.text,
                  bold: run.bold,
                  onTap: () => onOpenHandle(handle),
                ),
              )
            else
              TextSpan(
                text: run.text,
                style: run.bold ? const TextStyle(fontWeight: _bold) : null,
              ),
        ],
      ),
    );
  }
}

class _Mention extends StatelessWidget {
  const _Mention({required this.text, required this.bold, required this.onTap});

  final String text;
  final bool bold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: HackyRichText.style.copyWith(
            color: AppColors.action,
            fontWeight: bold ? _bold : FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.action,
          ),
        ),
      ),
    );
  }
}

/// My message: a blue bubble on the right.
class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.text, this.failed = false});

  final String text;

  /// Not sent: the bubble fades and [SendFailedNote] goes under it.
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.85,
        alignment: Alignment.centerRight,
        child: Align(
          alignment: Alignment.centerRight,
          child: Opacity(
            opacity: failed ? 0.6 : 1,
            child: ChatBubble(
              mine: true,
              child: Text(text, style: ChatBubble.textStyle(mine: true)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Under a message Hacky didn't get: why, and Retry.
class SendFailedNote extends StatelessWidget {
  const SendFailedNote({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;

  /// Null while another message is on its way.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 4,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
          Flexible(
            child: Text(
              'Not sent. $message',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.action,
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: _bold,
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// While Hacky works on its answer: the thinking clip and three dots.
/// Screen readers hear "Hacky is thinking…". The dots stay still when the
/// system asks for less motion.
class ThinkingRow extends StatelessWidget {
  const ThinkingRow({super.key});

  static const label = 'Hacky is thinking…';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: const ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 6,
          children: [
            HackyFilm.thinking(),
            HackyBubble(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: _ThinkingDots(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0.5;
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          for (var i = 0; i < 3; i++) _dot(((_controller.value * 3) - i) % 3),
        ],
      ),
    );
  }

  /// Each dot lights up in turn: [phase] 0..1 is its moment.
  Widget _dot(double phase) {
    final lit = phase >= 0 && phase < 1;
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: lit ? AppColors.action : AppColors.orbit,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Starting points that send a prompt to Hacky.
class SuggestionChips extends StatelessWidget {
  const SuggestionChips({
    super.key,
    required this.prompts,
    required this.onPick,
  });

  final List<String> prompts;

  /// Null while Hacky is answering.
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final prompt in prompts)
          HackyChip(
            label: prompt,
            onPressed: onPick == null ? null : () => onPick!(prompt),
          ),
      ],
    );
  }
}

/// A round white chip with blue text: a suggestion or an answer option.
class HackyChip extends StatelessWidget {
  const HackyChip({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.action,
        disabledForegroundColor: AppColors.muted,
        side: const BorderSide(color: AppColors.line),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, 40),
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 14,
          fontWeight: _bold,
        ),
      ),
      child: Text(label),
    );
  }
}

/// A starting point under the brief: what its card says and what it asks.
class HackyStarter {
  const HackyStarter({
    required this.label,
    required this.prompt,
    required this.art,
    this.face = false,
    this.crown = false,
  });

  final String label;

  /// Sent to Hacky as my message.
  final String prompt;

  /// The picture on the card.
  final String art;

  /// The picture is a person's face: it's shown round.
  final bool face;

  /// The little crown on the last letter ("Find mentor").
  final bool crown;

  /// The same four as the web (web/src/HackyPage.tsx `starters`). Each asks
  /// for something the chat can answer: people, mentors and tracks.
  static const all = [
    HackyStarter(
      label: 'Find hackers',
      prompt: 'Help me find a teammate',
      art: 'assets/people/mika.webp',
      face: true,
    ),
    HackyStarter(
      label: 'Pick a track',
      prompt: 'Help me pick a track',
      art: 'assets/shortcuts/event.png',
    ),
    HackyStarter(
      label: 'Find mentor',
      prompt: 'Find a mentor',
      art: 'assets/people/aya.webp',
      face: true,
      crown: true,
    ),
    HackyStarter(
      label: 'Who’s looking?',
      prompt: 'Who’s looking for a team?',
      art: 'assets/shortcuts/sponsor.png',
    ),
  ];
}

/// The top of the Hacky chat: Hacky's clip, "What can I help you with?" and
/// the four starting points. It opens the chat and stays above the history.
class HackyBrief extends StatelessWidget {
  const HackyBrief({super.key, required this.onPick});

  static const title = 'What can I help you with?';

  /// Sends a starting point's prompt. Null while Hacky is busy.
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    const starters = HackyStarter.all;
    final filmHeight = (MediaQuery.sizeOf(context).height * 0.26).clamp(
      120.0,
      220.0,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: HackyFilm.brief(height: filmHeight.toDouble())),
            const SizedBox(height: 10),
            Semantics(
              header: true,
              child: const Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 30,
                  fontWeight: _bold,
                  letterSpacing: -0.75,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pick a starting point, or tell me what you’re trying to do.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            for (var row = 0; row < starters.length; row += 2) ...[
              if (row > 0) const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    for (final starter in starters.skip(row).take(2))
                      Expanded(
                        child: StarterCard(
                          starter: starter,
                          onPressed: onPick == null
                              ? null
                              : () => onPick!(starter.prompt),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One starting point: its picture and its label in blue, on a white card.
class StarterCard extends StatelessWidget {
  const StarterCard({super.key, required this.starter, required this.onPressed});

  final HackyStarter starter;
  final VoidCallback? onPressed;

  static const _label = TextStyle(
    color: AppColors.link,
    fontFamily: AppTheme.fontFamily,
    fontSize: 15.5,
    fontWeight: _bold,
    height: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    final art = Image.asset(
      starter.art,
      width: 30,
      height: 30,
      fit: BoxFit.cover,
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: starter.label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                spacing: 8,
                children: [
                  starter.face ? ClipOval(child: art) : art,
                  Expanded(
                    child: starter.crown
                        ? _CrownedLabel(starter.label, style: _label)
                        : Text(starter.label, style: _label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A label with a small crown tilted over its last letter.
class _CrownedLabel extends StatelessWidget {
  const _CrownedLabel(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(text, maxLines: 1, style: style),
          Positioned(
            right: -5,
            top: -6,
            child: Transform.rotate(
              angle: 0.24,
              child: const CustomPaint(
                size: Size(14, 10.5),
                painter: _CrownPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The crown from the web's SVG (viewBox 16×12):
/// `M2 9 1 3l4 3 3-5 3 5 4-3-1 6Z` and its base `M3 11h10`.
class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 16, size.height / 12);
    final crown = Path()
      ..moveTo(2, 9)
      ..lineTo(1, 3)
      ..lineTo(5, 6)
      ..lineTo(8, 1)
      ..lineTo(11, 6)
      ..lineTo(15, 3)
      ..lineTo(14, 9)
      ..close();
    final line = Paint()
      ..color = AppColors.crownLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(crown, Paint()..color = AppColors.crown)
      ..drawPath(crown, line)
      ..drawLine(const Offset(3, 11), const Offset(13, 11), line);
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => false;
}

/// "New chat", at the top right of the Hacky chat: clears the messages on
/// screen after asking. Hacky keeps the history.
class NewChatButton extends StatelessWidget {
  const NewChatButton({super.key, required this.onPressed});

  static const label = 'New chat';
  static const buttonKey = Key('hacky-new-chat');

  /// Null when there's nothing to clear, or while Hacky is answering.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextButton.icon(
          key: buttonKey,
          onPressed: onPressed,
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text(label),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.muted,
            disabledForegroundColor: AppColors.muted.withValues(alpha: 0.45),
            minimumSize: const Size(0, 40),
            textStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Where I type to Hacky, like the web's composer: one rounded box with the
/// send button inside and "Hacky drafts. You decide what gets sent." under
/// it. Send waits while Hacky is answering.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  static const fieldKey = Key('hacky-composer');
  static const sendKey = Key('hacky-send');
  static const note = 'Hacky drafts. You decide what gets sent.';

  final TextEditingController controller;
  final bool busy;
  final ValueChanged<String> onSend;

  void _send() {
    if (!busy && controller.text.trim().isNotEmpty) onSend(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              MessageBox(
                field: TextField(
                  key: fieldKey,
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _send(),
                  style: MessageBox.textStyle,
                  decoration: MessageBox.decoration('Ask Hacky…'),
                ),
                send: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final ready = !busy && controller.text.trim().isNotEmpty;
                    return SendButton(
                      buttonKey: sendKey,
                      tooltip: busy ? 'Hacky is thinking…' : 'Send',
                      onPressed: ready ? _send : null,
                    );
                  },
                ),
              ),
              const Text(
                note,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
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
