// The pieces of 12 Hacky chat (mobile/design/hacky-chat-wireframes.svg), in
// the original Hacky look (react/src/hacky/hacky-chat.css): Hacky's turns
// start with the knit Hacky, mine are blue bubbles on the right, and the
// composer sits under the thread. Colors and fonts come from lib/theme.dart.

import 'package:flutter/material.dart';

import '../hacky/hacky_text.dart';
import '../theme.dart';
import 'app_widgets.dart';

const _bold = FontWeight.w700;
const _bubbleRadius = Radius.circular(16);

/// The top of the chat: the knit Hacky, its name, and what it's doing.
class HackyChatHeader extends StatelessWidget {
  const HackyChatHeader({super.key, required this.thinking});

  final bool thinking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        spacing: 12,
        children: [
          const HackyAvatar(size: 44),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              const Text(
                'Hacky',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: _bold,
                ),
              ),
              Text(
                thinking ? 'Thinking…' : 'Your hackathon helper',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The knit Hacky in a round frame, beside each of Hacky's turns.
class HackyAvatar extends StatelessWidget {
  const HackyAvatar({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: const BoxDecoration(
        color: AppColors.stage,
        shape: BoxShape.circle,
      ),
      child: KnitHacky(height: size),
    );
  }
}

/// One of Hacky's turns: the knit avatar, then its bubbles and cards.
class HackyTurn extends StatelessWidget {
  const HackyTurn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hacky',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          const HackyAvatar(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// A white bubble with Hacky's words.
class HackyBubble extends StatelessWidget {
  const HackyBubble({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: const BorderRadius.only(
          topRight: _bubbleRadius,
          bottomLeft: _bubbleRadius,
          bottomRight: _bubbleRadius,
          topLeft: Radius.circular(4),
        ),
      ),
      child: child,
    );
  }
}

/// Hacky's text with **bold** runs and tappable @handle mentions (→ 07).
class HackyRichText extends StatelessWidget {
  const HackyRichText(this.text, {super.key, required this.onOpenHandle});

  final String text;
  final void Function(String handle) onOpenHandle;

  static const style = TextStyle(
    color: AppColors.ink,
    fontSize: 15,
    height: 1.45,
  );

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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Opacity(
          opacity: failed ? 0.6 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.action,
              borderRadius: BorderRadius.only(
                topLeft: _bubbleRadius,
                bottomLeft: _bubbleRadius,
                bottomRight: _bubbleRadius,
                topRight: Radius.circular(4),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.onAction,
                fontSize: 15,
                height: 1.45,
              ),
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

/// While Hacky works on its answer: three dots and "Hacky is thinking…".
/// The dots stay still when the system asks for less motion.
class ThinkingRow extends StatelessWidget {
  const ThinkingRow({super.key});

  static const label = 'Hacky is thinking…';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: const ExcludeSemantics(
        child: HackyTurn(
          children: [
            HackyBubble(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
                children: [
                  _ThinkingDots(),
                  Text(
                    label,
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                ],
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

/// The first-time view: the knit Hacky says hi by name and offers
/// starting points.
class HackyWelcome extends StatelessWidget {
  const HackyWelcome({
    super.key,
    required this.firstName,
    required this.prompts,
    required this.onPick,
  });

  final String firstName;
  final List<String> prompts;
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    return PageColumn(
      children: [
        const SizedBox(height: 8),
        const Center(child: KnitHacky(height: 120)),
        Text(
          'Hi $firstName!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 22,
            fontWeight: _bold,
            letterSpacing: -0.4,
          ),
        ),
        const Text(
          'What are you building, and who do you need? I can find you '
          'teammates, mentors and open teams.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.55),
        ),
        const SectionLabel('Try asking'),
        SuggestionChips(prompts: prompts, onPick: onPick),
      ],
    );
  }
}

/// Where I type to Hacky. Send waits while Hacky is answering.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  static const fieldKey = Key('hacky-composer');
  static const sendKey = Key('hacky-send');

  final TextEditingController controller;
  final bool busy;
  final ValueChanged<String> onSend;

  void _send() {
    if (!busy && controller.text.trim().isNotEmpty) onSend(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 8,
        children: [
          Expanded(
            child: TextField(
              key: fieldKey,
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Message Hacky…',
                counterText: '',
                isDense: true,
                fillColor: AppColors.paper,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final ready = !busy && controller.text.trim().isNotEmpty;
              return IconButton.filled(
                key: sendKey,
                tooltip: busy ? 'Hacky is thinking…' : 'Send',
                onPressed: ready ? _send : null,
                icon: const Icon(Icons.arrow_upward),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.action,
                  foregroundColor: AppColors.onAction,
                  disabledBackgroundColor: AppColors.disabled,
                  disabledForegroundColor: AppColors.disabledInk,
                  minimumSize: const Size(46, 46),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
