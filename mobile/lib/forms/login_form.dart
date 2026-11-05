import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../auth/field_rules.dart';
import '../auth/submit_action.dart';
import '../routes.dart';
import '../widgets/auth_widgets.dart';

/// The "Log in" tab of [AuthScreen]. Same texts as `LoginPage` in
/// web/src/AuthPages.tsx.
class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.api,
    required this.onCreateAccount,
  });

  final ApiClient api;

  /// Switches to the "Create account" tab.
  final VoidCallback onCreateAccount;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> with SubmitAction<LoginForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final body = LoginBody(
      email: FieldRules.normalizeEmail(_email.text),
      password: _password.text,
    );
    await runAction(() async {
      final result = await widget.api.login(body);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.account,
        (_) => false,
        arguments: result.me,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeading(eyebrow: 'GOOD TO SEE YOU', title: 'Welcome back.'),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 19,
              children: [
                AuthField(
                  id: 'login-email',
                  label: 'Email address',
                  placeholder: 'you@example.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  maxLength: 254,
                  validator: FieldRules.email,
                ),
                AuthField(
                  id: 'login-password',
                  label: 'Password',
                  placeholder: 'Your password',
                  controller: _password,
                  password: true,
                  autofillHints: const [AutofillHints.password],
                  validator: FieldRules.loginPassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submit,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: LinkButton(
                    label: 'Forgot password?',
                    onPressed: () => navigator.pushNamed(Routes.forgotPassword),
                  ),
                ),
                if (error != null) Notice(error!, error: true),
                if (errorCode == 'email_not_verified')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: LinkButton(
                      label: 'Resend your verification email',
                      onPressed: () => navigator.pushNamed(
                        Routes.checkEmail,
                        arguments: FieldRules.normalizeEmail(_email.text),
                      ),
                    ),
                  ),
                SubmitButton(label: 'Log in', busy: busy, onPressed: _submit),
              ],
            ),
          ),
        ),
        FormSwitch(
          prompt: 'New around here? ',
          action: 'Create an account',
          onPressed: widget.onCreateAccount,
        ),
      ],
    );
  }
}
