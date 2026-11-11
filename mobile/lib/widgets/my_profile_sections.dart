// The blocks of 08 My profile (mobile/design/profile-wireframes.svg), top to
// bottom: my Hacky and name, the public profile, then this event's intake.

import 'package:flutter/material.dart';

import '../api/models/auth.dart';
import '../api/models/events.dart';
import '../profile/hacky_style.dart';
import '../profile/profile_draft.dart';
import '../profile/profile_editors.dart';
import '../profile/profile_rules.dart';
import '../theme.dart';
import '../theme_choice.dart';
import 'app_widgets.dart';
import 'hacky_style_sheet.dart';
import 'profile_fields.dart';

const _bold = FontWeight.w700;

/// Gives each field a key so the screen can scroll to the first error.
typedef FieldKeys = GlobalKey Function(ProfileField field);

String _capitalize(String word) =>
    word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';

/// My Hacky in the style being edited, my saved name and handle, and
/// "Change Hacky style".
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.profile,
    required this.look,
    required this.onChangeStyle,
    this.enabled = true,
  });

  /// The saved profile (the name updates after Save).
  final PublicProfile profile;
  final HackyLook look;
  final VoidCallback onChangeStyle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            spacing: 14,
            children: [
              StyledHacky(look: look, height: 72),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: profile.name,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 19,
                          fontWeight: _bold,
                        ),
                      ),
                      TextSpan(
                        text: '\n@${profile.handle}',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: enabled ? onChangeStyle : null,
            icon: const Icon(Icons.palette_outlined, size: 18),
            label: const Text('Change Hacky style'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: AppColors.ink,
              side: BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: _bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Name, bio and links: `PATCH /api/me/profile`.
class PublicProfileFields extends StatelessWidget {
  const PublicProfileFields({
    super.key,
    required this.editor,
    required this.errors,
    required this.keyFor,
    this.enabled = true,
  });

  final ProfileEditor editor;
  final Map<ProfileField, String> errors;
  final FieldKeys keyFor;
  final bool enabled;

  Widget _field(
    ProfileField field, {
    required String id,
    required String label,
    required TextEditingController controller,
    required int maxLength,
    String? placeholder,
    String? hint,
    int lines = 1,
    bool showCounter = false,
    TextInputType? keyboardType,
  }) => KeyedSubtree(
    key: keyFor(field),
    child: ProfileTextField(
      id: id,
      label: label,
      controller: controller,
      maxLength: maxLength,
      placeholder: placeholder,
      hint: hint,
      error: errors[field],
      lines: lines,
      showCounter: showCounter,
      keyboardType: keyboardType,
      enabled: enabled,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              _field(
                ProfileField.name,
                id: 'profile-name',
                label: 'Name',
                controller: editor.name,
                maxLength: ProfileRules.nameMax,
                placeholder: 'Your name',
                keyboardType: TextInputType.name,
              ),
              _field(
                ProfileField.bio,
                id: 'profile-bio',
                label: 'Bio',
                controller: editor.bio,
                maxLength: ProfileRules.bioMax,
                placeholder: 'Tell people what you’re into',
                hint: 'A little about you and what you enjoy building.',
                lines: 3,
                showCounter: true,
              ),
            ],
          ),
        ),
        const SectionLabel('Links'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              _field(
                ProfileField.github,
                id: 'profile-github',
                label: 'GitHub',
                controller: editor.github,
                maxLength: ProfileRules.linkMax,
                placeholder: 'github.com/…',
                keyboardType: TextInputType.url,
              ),
              _field(
                ProfileField.linkedin,
                id: 'profile-linkedin',
                label: 'LinkedIn',
                controller: editor.linkedin,
                maxLength: ProfileRules.linkMax,
                placeholder: 'linkedin.com/in/…',
                keyboardType: TextInputType.url,
              ),
              _field(
                ProfileField.website,
                id: 'profile-website',
                label: 'Website',
                controller: editor.website,
                maxLength: ProfileRules.linkMax,
                placeholder: 'https://your-site.dev',
                hint: ProfileRules.linkHint,
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What Hacky knows about me in this event: `PATCH /api/events/{slug}/me`.
class EventIntakeFields extends StatelessWidget {
  const EventIntakeFields({
    super.key,
    required this.editor,
    required this.event,
    required this.role,
    required this.errors,
    required this.keyFor,
    this.enabled = true,
  });

  final IntakeEditor editor;
  final EventInfo event;
  final MemberRole role;
  final Map<ProfileField, String> errors;
  final FieldKeys keyFor;
  final bool enabled;

  static const experienceOptions = [
    (Experience.beginner, 'Beginner'),
    (Experience.intermediate, 'Intermediate'),
    (Experience.advanced, 'Advanced'),
  ];

  static const goalOptions = [
    (HackGoal.win, 'Win a prize'),
    (HackGoal.learn, 'Learn something'),
    (HackGoal.ship, 'Ship a project'),
  ];

  /// The event's tracks, plus my saved one if the event no longer lists it.
  List<(String, String)> get _trackOptions => [
    for (final track in event.tracks) (track, track),
    if (editor.track case final mine? when !event.tracks.contains(mine))
      (mine, mine),
  ];

  Widget _tags(
    ProfileField field, {
    required String id,
    required String label,
    required List<String> tags,
    required ValueChanged<List<String>> onChanged,
    required String placeholder,
  }) => KeyedSubtree(
    key: keyFor(field),
    child: TagListEditor(
      id: id,
      label: label,
      tags: tags,
      onChanged: onChanged,
      placeholder: placeholder,
      error: errors[field],
      enabled: enabled,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tracks = _trackOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Row(
          children: [
            Expanded(child: SectionLabel(event.name)),
            TagChip(_capitalize(role.name), strong: true),
          ],
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              _tags(
                ProfileField.skills,
                id: 'profile-skills',
                label: 'Skills',
                tags: editor.skills,
                onChanged: (tags) => editor.skills = tags,
                placeholder: 'e.g. React',
              ),
              _tags(
                ProfileField.skillsWanted,
                id: 'profile-skills-wanted',
                label: 'Skills you want to learn',
                tags: editor.skillsWanted,
                onChanged: (tags) => editor.skillsWanted = tags,
                placeholder: 'e.g. Flutter',
              ),
              _tags(
                ProfileField.interests,
                id: 'profile-interests',
                label: 'Interests',
                tags: editor.interests,
                onChanged: (tags) => editor.interests = tags,
                placeholder: 'e.g. Climate',
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              KeyedSubtree(
                key: keyFor(ProfileField.experience),
                child: ChoicePicker<Experience>(
                  label: 'Experience',
                  options: experienceOptions,
                  value: editor.experience,
                  onChanged: (value) => editor.experience = value,
                  error: errors[ProfileField.experience],
                  enabled: enabled,
                ),
              ),
              KeyedSubtree(
                key: keyFor(ProfileField.goal),
                child: ChoicePicker<HackGoal>(
                  label: 'Goal',
                  options: goalOptions,
                  value: editor.goal,
                  onChanged: (value) => editor.goal = value,
                  error: errors[ProfileField.goal],
                  enabled: enabled,
                ),
              ),
              if (tracks.isNotEmpty)
                KeyedSubtree(
                  key: keyFor(ProfileField.track),
                  child: ChoicePicker<String>(
                    label: 'Track',
                    options: tracks,
                    value: editor.track,
                    onChanged: (value) => editor.track = value,
                    error: errors[ProfileField.track],
                    enabled: enabled,
                  ),
                ),
              const FieldNote('Tap a chosen option again to clear it.'),
            ],
          ),
        ),
        AppCard(
          child: KeyedSubtree(
            key: keyFor(ProfileField.idea),
            child: ProfileTextField(
              id: 'profile-idea',
              label: 'Idea',
              controller: editor.idea,
              maxLength: ProfileRules.ideaMax,
              placeholder: 'What are you building, learning, or hoping to find?',
              hint: 'Hacky uses it to suggest teammates.',
              error: errors[ProfileField.idea],
              lines: 3,
              showCounter: true,
              enabled: enabled,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Looking for a team',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: _bold,
                    ),
                  ),
                ),
                Switch(
                  key: const Key('profile-looking'),
                  value: editor.looking,
                  onChanged: enabled ? (value) => editor.looking = value : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Dark mode": switches the app between light and dark right away and
/// remembers it on this phone ([ThemeChoice]).
class DarkModeCard extends StatelessWidget {
  const DarkModeCard({super.key});

  static const switchKey = Key('profile-dark-mode');

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: MergeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Dark mode',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: _bold,
                ),
              ),
            ),
            Switch(
              key: switchKey,
              value: AppColors.isDark,
              onChanged: (dark) => ThemeChoice.instance.choose(dark: dark),
            ),
          ],
        ),
      ),
    );
  }
}
