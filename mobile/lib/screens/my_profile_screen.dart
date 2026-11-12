import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/models/auth.dart';
import '../api/models/events.dart';
import '../auth/submit_action.dart';
import '../profile/field_errors.dart';
import '../profile/profile_draft.dart';
import '../profile/profile_editors.dart';
import '../shell/screen_load.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/hacky_style_sheet.dart';
import '../widgets/my_profile_sections.dart';
import '../widgets/profile_fields.dart';

/// 08 My profile (Me tab, mobile/design/profile-wireframes.svg).
///
/// The top part is the public profile (name, bio, links, Hacky style), saved
/// with `PATCH /api/me/profile`; then [onProfileChanged] tells the shell.
/// When [eventSlug] is set, the event part loads `GET /api/events/{slug}/me`
/// and `GET /api/events/{slug}` (for the tracks) and saves the intake and
/// "Looking for a team" with `PATCH /api/events/{slug}/me`.
///
/// Save stays disabled until something changes and sends only what changed.
/// Field errors (the form's checks, and the server's `error.details`) show
/// under each field. Sign out is at the bottom (→ 01).
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({
    super.key,
    required this.api,
    required this.me,
    required this.eventSlug,
    required this.onProfileChanged,
  });

  final ApiClient api;

  /// The signed-in user, to fill the form.
  final Me me;

  /// The current event, or null before the user joins one (then only the
  /// public profile part is shown).
  final String? eventSlug;

  /// Tell the shell about a saved profile, so the other tabs show it.
  final ValueChanged<PublicProfile> onProfileChanged;

  static const saveKey = Key('profile-save');

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with ScreenLoad<MyProfileScreen>, SubmitAction<MyProfileScreen> {
  late final _profile = ProfileEditor(widget.me.profile)..addListener(_edited);
  IntakeEditor? _intake;
  EventInfo? _event;
  MemberRole? _role;

  /// From the form's own checks; shown once Save was tapped, then kept up to
  /// date as the user types.
  Map<ProfileField, String> _formErrors = const {};
  bool _checked = false;

  /// From the server's last answer; cleared by the next edit.
  Map<ProfileField, String> _serverErrors = const {};

  /// The public profile saved but the event part failed.
  bool _savedProfileOnly = false;

  final _fieldKeys = <ProfileField, GlobalKey>{};
  final _noticeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  @override
  void didUpdateWidget(MyProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eventSlug != oldWidget.eventSlug) {
      _intake?.dispose();
      _intake = null;
      _event = null;
      _loadEvent();
    }
    // The shell got a newer profile (e.g. our own save): take it unless the
    // user is in the middle of editing.
    if (!identical(widget.me.profile, oldWidget.me.profile) &&
        !_profile.dirty) {
      _profile.reset(widget.me.profile);
    }
  }

  @override
  void dispose() {
    _profile.dispose();
    _intake?.dispose();
    super.dispose();
  }

  void _loadEvent() {
    final slug = widget.eventSlug;
    if (slug == null) {
      loading = false;
      problem = null;
      return;
    }
    runLoad(() => _fetchEvent(slug));
  }

  Future<void> _fetchEvent(String slug) async {
    final results = await Future.wait<Object>([
      widget.api.getEventMe(slug),
      widget.api.getEvent(slug),
    ]);
    if (!mounted || slug != widget.eventSlug) return;
    final eventMe = results[0] as EventMe;
    setState(() {
      _event = results[1] as EventInfo;
      _role = eventMe.role;
      _intake?.dispose();
      _intake = IntakeEditor(eventMe)..addListener(_edited);
    });
  }

  void _edited() {
    if (!mounted) return;
    setState(() {
      _serverErrors = const {};
      if (_checked) _formErrors = _check();
    });
  }

  Map<ProfileField, String> _check() => {
    ..._profile.draft.validate(),
    ...?_intake?.draft.validate(),
  };

  bool get _dirty => _profile.dirty || (_intake?.dirty ?? false);

  GlobalKey _keyFor(ProfileField field) =>
      _fieldKeys.putIfAbsent(field, GlobalKey.new);

  /// Scrolls to the first field with an error, or to the error message.
  void _reveal(Map<ProfileField, String> errors) {
    final key = errors.isEmpty ? _noticeKey : _keyFor(errors.keys.first);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.1,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  Future<void> _changeStyle() async {
    final look = await HackyStyleSheet.show(context, _profile.look);
    if (look != null) _profile.look = look;
  }

  Future<void> _save() async {
    final problems = _check();
    setState(() {
      _checked = true;
      _formErrors = problems;
      _serverErrors = const {};
      _savedProfileOnly = false;
    });
    if (problems.isNotEmpty) {
      _reveal(problems);
      return;
    }
    final profileChanges = _profile.changes;
    final intake = _intake;
    final intakeChanges = intake?.changes;
    final slug = widget.eventSlug;
    var savedProfile = false;

    await runAction(() async {
      try {
        if (profileChanges != null) {
          final saved = await widget.api.updateProfile(profileChanges);
          if (!mounted) return;
          _profile.reset(saved);
          widget.onProfileChanged(saved);
          savedProfile = true;
        }
        if (intake != null && intakeChanges != null && slug != null) {
          final saved = await widget.api.updateEventMe(slug, intakeChanges);
          if (!mounted) return;
          intake.reset(saved);
          setState(() => _role = saved.role);
        }
      } on ApiException catch (e) {
        if (mounted) _saveFailed(e, savedProfile: savedProfile);
        rethrow;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    });
    if (mounted && error != null && _serverErrors.isEmpty) _reveal(const {});
  }

  /// Puts the server's field errors under their fields. A 401 means the
  /// session expired, so it goes back to log in.
  void _saveFailed(ApiException e, {required bool savedProfile}) {
    if (e.statusCode == 401) {
      ScreenLoad.toLogin(context);
      return;
    }
    final fields = FieldErrors.of(e.details);
    setState(() {
      _serverErrors = fields;
      _savedProfileOnly = savedProfile;
    });
    _reveal(fields);
  }

  Future<void> _signOut() async {
    if (_dirty && !await _confirmDiscard()) return;
    await widget.api.logout();
    if (mounted) ScreenLoad.toLogin(context);
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard your changes?'),
        content: const Text('You have changes that aren’t saved yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final errors = {..._formErrors, ..._serverErrors};
    return SignedInPage(
      title: 'My profile',
      actions: [_SaveButton(enabled: _dirty, busy: busy, onPressed: _save)],
      body: PageColumn(
        children: [
          if (error != null)
            KeyedSubtree(
              key: _noticeKey,
              child: Notice(
                _savedProfileOnly
                    ? 'Your profile was saved, but your event details '
                          'weren’t. $error'
                    : error!,
                error: true,
              ),
            ),
          ProfileHeaderCard(
            profile: widget.me.profile,
            look: _profile.look,
            onChangeStyle: _changeStyle,
            enabled: !busy,
          ),
          PublicProfileFields(
            editor: _profile,
            errors: errors,
            keyFor: _keyFor,
            enabled: !busy,
          ),
          _eventPart(errors),
          const DarkModeCard(),
          SecondaryButton(label: 'Sign out', onPressed: busy ? null : _signOut),
        ],
      ),
    );
  }

  Widget _eventPart(Map<ProfileField, String> errors) {
    if (widget.eventSlug == null) {
      return const FieldNote(
        'Join an event on Home to tell Hacky your skills and what you want '
        'to build there.',
      );
    }
    final message = problem;
    if (message != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Notice(message, error: true),
          SecondaryButton(label: 'Try again', onPressed: _loadEvent),
        ],
      );
    }
    final intake = _intake;
    final event = _event;
    final role = _role;
    if (loading || intake == null || event == null || role == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: LoadingView(label: 'Loading your event details…'),
      );
    }
    return EventIntakeFields(
      editor: intake,
      event: event,
      role: role,
      errors: errors,
      keyFor: _keyFor,
      enabled: !busy,
    );
  }
}

/// "Save" in the title bar: disabled until something changes, a spinner
/// while saving.
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: FilledButton(
        key: MyProfileScreen.saveKey,
        onPressed: enabled && !busy ? onPressed : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: busy
            ? Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.disabledInk,
                    ),
                  ),
                  const Text('Saving…'),
                ],
              )
            : const Text('Save'),
      ),
    );
  }
}
