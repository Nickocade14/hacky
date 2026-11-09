import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../auth/field_rules.dart';
import '../auth/submit_action.dart';
import '../routes.dart';
import '../widgets/auth_widgets.dart';

/// After "Create account": the user types the 6-digit code from the email.
/// The server only creates the account when the code is right, and then logs
/// in, so this goes straight to Home. Same texts as `VerifyPage` on the web.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.api, required this.email});

  final ApiClient api;

  /// Where the code was sent.
  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SubmitAction<VerifyEmailScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _resent = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_form.currentState!.validate()) return;
    final body = VerifyCodeBody(email: widget.email, code: _code.text.trim());
    await runAction(() async {
      final result = await widget.api.verifyEmail(body);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.home, (_) => false, arguments: result.me);
    });
  }

  Future<void> _resend() async {
    await runAction(() async {
      await widget.api.resendVerification(EmailBody(email: widget.email));
      if (!mounted) return;
      _code.clear();
      setState(() => _resent = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Someone verified this email or username first; the sign-up is gone.
    final startOver = errorCode == 'email_taken' || errorCode == 'handle_taken';
    return AuthLayout(
      children: [
        const BackToLogin(),
        const StatusIcon('↗'),
        PageHeading(
          eyebrow: 'ONE QUICK STEP',
          title: 'Check your inbox.',
          body: TextSpan(
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              PageHeading.strong(widget.email),
              const TextSpan(text: '. Enter it to finish creating your account.'),
            ],
          ),
        ),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 19,
            children: [
              AuthField(
                id: 'verify-code',
                label: 'Code',
                placeholder: '123456',
                hint: 'The code expires in 10 minutes.',
                controller: _code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                validator: FieldRules.code,
                textInputAction: TextInputAction.done,
                onSubmitted: _verify,
              ),
              if (_resent && error == null)
                const Notice(
                  'A new code is on its way. Check your spam folder too.',
                ),
              if (error != null) Notice(error!, error: true),
              if (startOver)
                Align(
                  alignment: Alignment.centerLeft,
                  child: LinkButton(
                    label: 'Back to create account',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              SubmitButton(
                label: 'Verify and continue',
                busy: busy,
                onPressed: _verify,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: LinkButton(label: 'Send a new code', onPressed: _resend),
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
