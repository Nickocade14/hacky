import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../auth/field_rules.dart';
import '../auth/submit_action.dart';
import '../widgets/auth_widgets.dart';

/// "Check your inbox" after registering, with a form to resend the
/// verification email. Same texts as `VerifyPage` on the web when the page
/// has no token. The link itself opens the web, so there's no verify screen.
class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({super.key, required this.api, this.email});

  final ApiClient api;

  /// Where the link was sent, when known.
  final String? email;

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen>
    with SubmitAction<CheckEmailScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    if (!_form.currentState!.validate()) return;
    final body = EmailBody(email: FieldRules.normalizeEmail(_email.text));
    await runAction(() async {
      await widget.api.resendVerification(body);
      if (mounted) setState(() => _sent = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    return AuthLayout(
      children: [
        const BackToLogin(),
        const StatusIcon('↗'),
        PageHeading(
          eyebrow: 'ONE QUICK STEP',
          title: 'Check your inbox.',
          body: email != null
              ? TextSpan(
                  children: [
                    const TextSpan(text: 'We sent a verification link to '),
                    PageHeading.strong(email),
                    const TextSpan(
                      text: '. Open it to finish setting up your account.',
                    ),
                  ],
                )
              : const TextSpan(
                  text:
                      'Open the verification link in your email, or request '
                      'a new one below.',
                ),
        ),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 19,
            children: [
              AuthField(
                id: 'resend-email',
                label: 'Email address',
                placeholder: 'you@example.com',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                maxLength: 254,
                validator: FieldRules.email,
                textInputAction: TextInputAction.done,
                onSubmitted: _resend,
              ),
              if (_sent)
                const Notice(
                  'If this address has an unverified account, a new link is '
                  'on its way. Check your spam folder too.',
                ),
              if (error != null) Notice(error!, error: true),
              SubmitButton(
                label: 'Resend verification link',
                busy: busy,
                onPressed: _resend,
              ),
            ],
          ),
        ),
        const SmallNote(
          'Can’t find the email? Take a quick look in your spam folder.',
        ),
      ],
    );
  }
}
