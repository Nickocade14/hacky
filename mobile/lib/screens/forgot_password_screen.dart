import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../auth/field_rules.dart';
import '../auth/submit_action.dart';
import '../widgets/auth_widgets.dart';

/// Asks for a password reset email. Same texts as `ForgotPasswordPage` on the
/// web. The reset link opens the web, so there's no reset screen here.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SubmitAction<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final body = EmailBody(email: FieldRules.normalizeEmail(_email.text));
    await runAction(() async {
      await widget.api.forgotPassword(body);
      if (mounted) setState(() => _sent = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      children: [
        const BackToLogin(),
        const StatusIcon('↺'),
        PageHeading(
          eyebrow: 'IT HAPPENS TO THE BEST OF US',
          title: _sent ? 'Check your inbox.' : 'Forgot your password?',
          body: TextSpan(
            text: _sent
                ? 'If an account exists for that email, a password reset '
                      'link is on its way.'
                : 'No worries. We’ll send you a link to get back to your '
                      'people.',
          ),
        ),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 19,
            children: [
              AuthField(
                id: 'forgot-email',
                label: 'Email address',
                placeholder: 'you@example.com',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                maxLength: 254,
                validator: FieldRules.email,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
              ),
              if (_sent)
                const Notice(
                  'Check your email and spam folder. You can request another '
                  'link below if you need one.',
                ),
              if (error != null) Notice(error!, error: true),
              SubmitButton(
                label: _sent ? 'Send another link' : 'Send reset link',
                busy: busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
