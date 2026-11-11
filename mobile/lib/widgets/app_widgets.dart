// Building blocks of the signed-in screens, in the original Hacky look
// (seeko-codes/hacky react/public/app/hacky-primitives.css): white cards with
// a thin line border, muted uppercase section labels, round avatars and the
// knit mascot. Colors and fonts come from lib/theme.dart.

import 'package:flutter/material.dart';

import '../api/api_config.dart';
import '../api/models/auth.dart';
import '../api/models/people.dart';
import '../people/person_labels.dart';
import '../profile/hacky_style.dart';
import '../shell/shell_scope.dart';
import '../theme.dart';
import 'auth_widgets.dart';

const _bold = FontWeight.w700;

/// The page of a signed-in screen: its title, the buttons that go with it,
/// and a scrollable [body] on the paper background.
///
/// Inside the shell the header is already there, so the title is a heading
/// at the top of the page, like the web's pages. Pushed screens (07, 09, 11)
/// get a title bar with a back arrow.
class SignedInPage extends StatelessWidget {
  const SignedInPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.headingInShell = true,
  });

  final String title;
  final Widget body;

  /// Buttons on the right of the title.
  final List<Widget> actions;

  /// False for Hacky: the shell's header already says it.
  final bool headingInShell;

  @override
  Widget build(BuildContext context) {
    if (ShellScope.maybeOf(context) != null) {
      return ColoredBox(
        color: AppColors.paper,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (headingInShell) PageTitle(title: title, actions: actions),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: _bold,
            letterSpacing: -0.4,
          ),
        ),
        centerTitle: false,
        actions: actions,
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

/// The title at the top of a page inside the shell, with its buttons on the
/// right ("My profile" · Save).
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, minHeight: 44),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 24,
                      fontWeight: _bold,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// The content column of a signed-in page: 16px side padding, 16px between
/// blocks, at most 560px wide on tablets and the web. Inside the shell it
/// leaves room at the bottom for the Ask Hacky button.
class PageColumn extends StatelessWidget {
  const PageColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final clearance = ShellScope.maybeOf(context)?.bottomClearance ?? 0;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + clearance),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A muted uppercase label over a block ("YOUR EVENT", "MY TEAM").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: _bold,
          letterSpacing: 1.7,
        ),
      ),
    );
  }
}

/// A white card with a thin border. Tappable when [onTap] is set.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.color = AppColors.white,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.borderRadius,
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A person's avatar: their photo (unless they chose to show their Hacky),
/// else a knit Hacky in their color. Same rule and art as the web
/// (web/src/workspace/KnitAvatar.tsx). Decorative: the name is always shown
/// beside it.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.userId,
    this.hackyStyle = const {},
    this.photoUrl,
    this.size = 40,
  });

  /// The avatar of a person from a list, card, request or chat.
  PersonAvatar.of(PersonSummary person, {Key? key, double size = 40})
    : this(
        key: key,
        name: person.name,
        userId: person.userId,
        hackyStyle: person.hackyStyle,
        photoUrl: person.photoUrl,
        size: size,
      );

  /// The avatar of a full profile (mine, or a person's page).
  PersonAvatar.ofProfile(PublicProfile profile, {Key? key, double size = 40})
    : this(
        key: key,
        name: profile.name,
        userId: profile.userId,
        hackyStyle: profile.hackyStyle,
        photoUrl: profile.photoUrl,
        size: size,
      );

  final String name;

  /// Picks the knit color when the person hasn't chosen one.
  final String? userId;
  final Map<String, dynamic> hackyStyle;

  /// Absolute, or relative to the site (`/assets/people/aya.webp`).
  final String? photoUrl;
  final double size;

  static String initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => String.fromCharCode(word.runes.first).toUpperCase())
      .join();

  /// The photo's address, or null when the person shows their Hacky.
  String? get _photo {
    final url = photoUrl;
    if (url == null || url.isEmpty || hackyStyle['avatar'] == 'hacky') {
      return null;
    }
    return Uri.parse(ApiConfig.productionBaseUrl).resolve(url).toString();
  }

  @override
  Widget build(BuildContext context) {
    final knit = Image.asset(
      KnitAvatarArt.asset(hackyStyle: hackyStyle, seed: userId ?? name),
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
    final photo = _photo;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: photo == null
            ? knit
            : ClipOval(
                child: ColoredBox(
                  color: AppColors.wash,
                  child: Image.network(
                    photo,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => knit,
                  ),
                ),
              ),
      ),
    );
  }
}

/// The knit Hacky mascot.
class KnitHacky extends StatelessWidget {
  const KnitHacky({super.key, this.height = 64});

  static const image = 'assets/mascots/hacky-knit.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(image, height: height, fit: BoxFit.contain),
    );
  }
}

/// A small rounded label: a skill, a track or a role.
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.strong = false});

  final String label;

  /// Blue text on a light blue wash instead of ink on grey.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? AppColors.hover : AppColors.wash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: strong ? AppColors.action : AppColors.ink,
          fontSize: 12,
          fontWeight: _bold,
        ),
      ),
    );
  }
}

/// A person's role as a small label, colored like the web's (.hk-role):
/// blue for hackers, green for mentors, sand for sponsors and organizers.
class RoleChip extends StatelessWidget {
  const RoleChip(this.role, {super.key});

  final MemberRole role;

  @override
  Widget build(BuildContext context) {
    final (ink, wash) = switch (role) {
      MemberRole.hacker => (AppColors.hackerInk, AppColors.hackerWash),
      MemberRole.mentor => (AppColors.mentorInk, AppColors.mentorWash),
      MemberRole.sponsor ||
      MemberRole.organizer => (AppColors.sponsorInk, AppColors.sponsorWash),
    };
    return QuietTag(PersonLabels.role(role), ink: ink, wash: wash, bold: true);
  }
}

/// A small squared label beside a name: a team, "Pending", a help request.
class QuietTag extends StatelessWidget {
  const QuietTag(
    this.label, {
    super.key,
    this.ink = AppColors.muted,
    this.wash = AppColors.wash,
    this.bold = false,
  });

  final String label;
  final Color ink;
  final Color wash;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: ink,
          fontSize: 12.5,
          height: 1.45,
          fontWeight: bold ? _bold : FontWeight.w400,
        ),
      ),
    );
  }
}

/// A blue pill with a count or short text ("2 new").
class CountBadge extends StatelessWidget {
  const CountBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.action,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.onAction,
          fontSize: 11,
          fontWeight: _bold,
        ),
      ),
    );
  }
}

/// A person in a list: avatar, name, a muted line and a chevron.
/// Used for search results, suggestions, requests and Hacky's cards.
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.person,
    required this.subtitle,
    this.onTap,
  });

  final PersonSummary person;

  /// e.g. "@maya · Design, React".
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        spacing: 14,
        children: [
          PersonAvatar.of(person, size: 44),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  person.name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: _bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
        ],
      ),
    );
  }
}

/// A spinner with a short muted line, centered in the page.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Loading…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          const SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// A load that failed: the error message and "Try again".
class ProblemView extends StatelessWidget {
  const ProblemView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 20,
            children: [
              Notice(message, error: true),
              SecondaryButton(label: 'Try again', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

/// The knit Hacky with a title and a muted line, for empty states and
/// screens that aren't built yet. [action] goes under the text.
class MascotMessage extends StatelessWidget {
  const MascotMessage({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        spacing: 10,
        children: [
          const KnitHacky(height: 110),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 19,
              fontWeight: _bold,
            ),
          ),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: action),
        ],
      ),
    );
  }
}

/// The body of a screen that isn't built yet: its wireframe number, what it
/// will show, and any [children] that already work (e.g. Sign out).
class ScreenPlaceholder extends StatelessWidget {
  const ScreenPlaceholder({
    super.key,
    required this.number,
    required this.summary,
    this.children = const [],
  });

  /// The wireframe number, e.g. "06" (mobile/design/README.md).
  final String number;

  /// One sentence on what the finished screen shows.
  final String summary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PageColumn(
      children: [
        MascotMessage(title: 'Screen $number is on its way', body: summary),
        ...children,
      ],
    );
  }
}

/// Shown on event tabs before the user joins an event.
class NoEventView extends StatelessWidget {
  const NoEventView({super.key, required this.onOpenHome});

  /// Switches to Home, which lists the events to join.
  final VoidCallback onOpenHome;

  @override
  Widget build(BuildContext context) {
    return PageColumn(
      children: [
        MascotMessage(
          title: 'Join an event first',
          body: 'People, chats and Hacky live inside a hackathon. '
              'Pick yours on Home.',
          action: SecondaryButton(label: 'Go to Home', onPressed: onOpenHome),
        ),
      ],
    );
  }
}
