// The live state behind the 08 My profile form. Each editor holds the last
// saved values and what's being edited, and notifies on every change so the
// screen can enable Save only when something changed.

import 'package:flutter/widgets.dart';

import '../api/models/auth.dart';
import '../api/models/events.dart';
import '../api/models/me.dart';
import 'hacky_style.dart';
import 'profile_draft.dart';

/// The public profile being edited: name, bio, links and Hacky style.
class ProfileEditor extends ChangeNotifier {
  ProfileEditor(PublicProfile profile) : _saved = ProfileDraft.of(profile) {
    _fill(_saved);
    for (final controller in _controllers) {
      controller.addListener(notifyListeners);
    }
  }

  final name = TextEditingController();
  final bio = TextEditingController();
  final github = TextEditingController();
  final linkedin = TextEditingController();
  final website = TextEditingController();

  ProfileDraft _saved;
  Map<String, dynamic> _hackyStyle = const {};

  List<TextEditingController> get _controllers => [
    name,
    bio,
    github,
    linkedin,
    website,
  ];

  HackyLook get look => HackyLook.of(_hackyStyle);

  set look(HackyLook look) {
    if (look == this.look) return;
    _hackyStyle = look.applyTo(_hackyStyle);
    notifyListeners();
  }

  ProfileDraft get draft => ProfileDraft(
    name: name.text,
    bio: bio.text,
    github: github.text,
    linkedin: linkedin.text,
    website: website.text,
    hackyStyle: _hackyStyle,
  );

  /// The PATCH body for the unsaved changes, or null when there are none.
  UpdateProfileBody? get changes => draft.changesFrom(_saved);

  bool get dirty => changes != null;

  /// Starts over from [profile] (just saved, or changed elsewhere).
  void reset(PublicProfile profile) {
    _saved = ProfileDraft.of(profile);
    _fill(_saved);
    notifyListeners();
  }

  void _fill(ProfileDraft values) {
    _hackyStyle = values.hackyStyle;
    _set(name, values.name);
    _set(bio, values.bio);
    _set(github, values.github);
    _set(linkedin, values.linkedin);
    _set(website, values.website);
  }

  /// Only touches the field when the text differs, so the cursor stays put.
  static void _set(TextEditingController controller, String text) {
    if (controller.text != text) controller.text = text;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// The event intake being edited, plus "Looking for a team".
class IntakeEditor extends ChangeNotifier {
  IntakeEditor(EventMe eventMe) : _saved = IntakeDraft.of(eventMe) {
    _fill(_saved);
    idea.addListener(notifyListeners);
  }

  final idea = TextEditingController();

  IntakeDraft _saved;
  late List<String> _skills;
  late List<String> _skillsWanted;
  late List<String> _interests;
  Experience? _experience;
  HackGoal? _goal;
  String? _track;
  late bool _looking;

  List<String> get skills => _skills;
  set skills(List<String> value) => _update(() => _skills = value);

  List<String> get skillsWanted => _skillsWanted;
  set skillsWanted(List<String> value) => _update(() => _skillsWanted = value);

  List<String> get interests => _interests;
  set interests(List<String> value) => _update(() => _interests = value);

  Experience? get experience => _experience;
  set experience(Experience? value) => _update(() => _experience = value);

  HackGoal? get goal => _goal;
  set goal(HackGoal? value) => _update(() => _goal = value);

  String? get track => _track;
  set track(String? value) => _update(() => _track = value);

  bool get looking => _looking;
  set looking(bool value) => _update(() => _looking = value);

  IntakeDraft get draft => IntakeDraft(
    skills: _skills,
    skillsWanted: _skillsWanted,
    interests: _interests,
    experience: _experience,
    goal: _goal,
    track: _track,
    idea: idea.text,
    looking: _looking,
  );

  /// The PATCH body for the unsaved changes, or null when there are none.
  UpdateEventMeBody? get changes => draft.changesFrom(_saved);

  bool get dirty => changes != null;

  /// Starts over from [eventMe] (just saved).
  void reset(EventMe eventMe) {
    _saved = IntakeDraft.of(eventMe);
    _fill(_saved);
    notifyListeners();
  }

  void _fill(IntakeDraft values) {
    _skills = values.skills;
    _skillsWanted = values.skillsWanted;
    _interests = values.interests;
    _experience = values.experience;
    _goal = values.goal;
    _track = values.track;
    _looking = values.looking;
    if (idea.text != values.idea) idea.text = values.idea;
  }

  void _update(VoidCallback change) {
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    idea.dispose();
    super.dispose();
  }
}
