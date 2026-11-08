import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../api/models/requests.dart';
import '../auth/submit_action.dart';
import '../people/intro_rules.dart';
import '../people/person_labels.dart';
import '../theme.dart';
import 'auth_widgets.dart';

/// The bottom sheet behind Connect on 07: a required intro, then
/// `POST /api/events/{slug}/requests` with `source: profile`. Closes with
/// the result (already `accepted` when they had asked me first).
class ConnectSheet extends StatefulWidget {
  const ConnectSheet({
    super.key,
    required this.api,
    required this.eventSlug,
    required this.person,
  });

  static const introKey = Key('connect-intro');

  final ApiClient api;
  final String eventSlug;
  final PublicProfile person;

  /// Opens the sheet; the result is the sent request, or null if closed.
  static Future<RequestResult?> show(
    BuildContext context, {
    required ApiClient api,
    required String eventSlug,
    required PublicProfile person,
  }) => showModalBottomSheet<RequestResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        ConnectSheet(api: api, eventSlug: eventSlug, person: person),
  );

  @override
  State<ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<ConnectSheet>
    with SubmitAction<ConnectSheet> {
  final _form = GlobalKey<FormState>();
  final _intro = TextEditingController();

  String get _first => PersonLabels.firstName(widget.person.name);

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await runAction(() async {
      final result = await widget.api.sendRequest(
        widget.eventSlug,
        SendRequestBody(
          toUserId: widget.person.userId,
          intro: _intro.text.trim(),
          source: ConnectionSource.profile,
        ),
      );
      if (mounted) Navigator.of(context).pop(result);
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 19,
            children: [
              PageHeading(
                eyebrow: 'CONNECT',
                title: 'Say hi to $_first',
                body: TextSpan(
                  text:
                      'Tell $_first why you’d like to connect. They see it '
                      'with your request.',
                ),
              ),
              Semantics(
                label: 'Your intro',
                child: TextFormField(
                  key: ConnectSheet.introKey,
                  controller: _intro,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: IntroRules.maxLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  textCapitalization: TextCapitalization.sentences,
                  validator: IntroRules.validate,
                  style: const TextStyle(color: AppColors.ink, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Hi $_first! I’m building…',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              if (error != null) Notice(error!, error: true),
              SubmitButton(
                label: 'Send request',
                busy: busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
