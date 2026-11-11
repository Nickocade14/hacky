import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../auth/field_rules.dart';
import '../auth/submit_action.dart';
import '../routes.dart';
import '../widgets/auth_widgets.dart';

/// Password reset in two steps, like `ForgotPasswordPage` on the web:
/// first the email gets a 6-digit code, then the code and a new password
/// reset it and log in, so this goes straight to Home.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SubmitAction<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  /// Where the code went. Null while asking for the email.
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_sentTo == null && !_emailForm.currentState!.validate()) return;
    final email = _sentTo ?? FieldRules.normalizeEmail(_email.text);
    await runAction(() async {
      await widget.api.forgotPassword(EmailBody(email: email));
      if (!mounted) return;
      _code.clear();
      setState(() => _sentTo = email);
    });
  }

  Future<void> _reset() async {
    final email = _sentTo;
    if (email == null || !_resetForm.currentState!.validate()) return;
    final body = ResetCodeBody(
      email: email,
      code: _code.text.trim(),
      password: _password.text,
    );
    await runAction(() async {
      final result = await widget.api.resetPassword(body);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.home, (_) => false, arguments: result.me);
    });
  }

  void _changeEmail() => setState(() {
    _sentTo = null;
    error = null;
    errorCode = null;
  });

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    return AuthLayout(
      children: [
        const BackToLogin(),
        PageHeading(
          eyebrow: 'IT HAPPENS TO THE BEST OF US',
          title: sentTo == null ? 'Forgot your password?' : 'Check your inbox.',
          body: sentTo == null
              ? const TextSpan(
                  text:
                      'No worries. We’ll email you a code to get back to your '
                      'people.',
                )
              : TextSpan(
                  children: [
                    const TextSpan(
                      text: 'If an account exists for ',
                    ),
                    PageHeading.strong(sentTo),
                    const TextSpan(
                      text: ', a 6-digit code is on its way. Enter it with '
                          'your new password.',
                    ),
                  ],
                ),
        ),
        if (sentTo == null) _emailStep() else _resetStep(),
      ],
    );
  }

  Widget _emailStep() => Form(
    key: _emailForm,
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
          onSubmitted: _sendCode,
        ),
        if (error != null) Notice(error!, error: true),
        SubmitButton(label: 'Send code', busy: busy, onPressed: _sendCode),
      ],
    ),
  );

  Widget _resetStep() => Form(
    key: _resetForm,
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 19,
        children: [
          AuthField(
            id: 'reset-code',
            label: 'Code',
            placeholder: '123456',
            hint: 'The code expires in 10 minutes.',
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            validator: FieldRules.code,
          ),
          AuthField(
            id: 'reset-password',
            label: 'New password',
            placeholder: 'Make it a good one',
            hint: FieldRules.passwordHint,
            controller: _password,
            password: true,
            autofillHints: const [AutofillHints.newPassword],
            validator: FieldRules.newPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: _reset,
          ),
          if (error != null) Notice(error!, error: true),
          SubmitButton(
            label: 'Reset password',
            busy: busy,
            onPressed: _reset,
          ),
          Wrap(
            spacing: 8,
            children: [
              LinkButton(label: 'Send a new code', onPressed: _sendCode),
              LinkButton(label: 'Use a different email', onPressed: _changeEmail),
            ],
          ),
        ],
      ),
    ),
  );
}
