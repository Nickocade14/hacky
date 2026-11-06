import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/teams.dart';
import '../auth/submit_action.dart';
import 'auth_widgets.dart';

/// The bottom sheet behind "Create team" on Home: a team name, then
/// `POST /api/events/{slug}/teams`. Closes with the new team.
class CreateTeamSheet extends StatefulWidget {
  const CreateTeamSheet({super.key, required this.api, required this.eventSlug});

  final ApiClient api;
  final String eventSlug;

  /// Opens the sheet; the result is the created team, or null if closed.
  static Future<TeamDetail?> show(
    BuildContext context, {
    required ApiClient api,
    required String eventSlug,
  }) => showModalBottomSheet<TeamDetail>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CreateTeamSheet(api: api, eventSlug: eventSlug),
  );

  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Give your team a name.';
    if (name.length > 80) return 'Use at most 80 characters.';
    return null;
  }

  @override
  State<CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends State<CreateTeamSheet>
    with SubmitAction<CreateTeamSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await runAction(() async {
      final team = await widget.api.createTeam(
        widget.eventSlug,
        CreateTeamBody(name: _name.text.trim()),
      );
      if (mounted) Navigator.of(context).pop(team);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 19,
          children: [
            const PageHeading(
              eyebrow: 'MY TEAM',
              title: 'Create a team',
              body: TextSpan(
                text: 'You lead it. Invite people from their profiles.',
              ),
            ),
            AuthField(
              id: 'team-name',
              label: 'Team name',
              placeholder: 'Byte Me',
              controller: _name,
              maxLength: 80,
              validator: CreateTeamSheet.validateName,
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
            ),
            if (error != null) Notice(error!, error: true),
            SubmitButton(label: 'Create team', busy: busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
