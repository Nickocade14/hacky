import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../auth/field_rules.dart';
import '../auth/submit_action.dart';
import '../routes.dart';
import '../widgets/auth_widgets.dart';

/// Create an account. Same texts and limits as `RegisterPage` in
/// web/src/AuthPages.tsx. On success, opens "Check your inbox".
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SubmitAction<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final email = FieldRules.normalizeEmail(_email.text);
    final body = RegisterBody(
      name: _name.text.trim(),
      handle: _handle.text.trim().toLowerCase(),
      email: email,
      password: _password.text,
    );
    await runAction(() async {
      await widget.api.register(body);
      if (!mounted) return;
      // Not awaited: the future only completes when that screen closes.
      Navigator.of(context).pushNamed(Routes.checkEmail, arguments: email);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      children: [
        const AuthTabs(current: AuthTab.register),
        const PageHeading(
          eyebrow: 'YOUR PEOPLE ARE HERE',
          title: 'Let’s make it happen.',
          body: TextSpan(
            text: 'Create your account. Find your crew. Build something great.',
          ),
        ),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 19,
              children: [
                AuthField(
                  id: 'register-name',
                  label: 'Your name',
                  placeholder: 'What should we call you?',
                  controller: _name,
                  autofillHints: const [AutofillHints.name],
                  maxLength: 80,
                  validator: FieldRules.name,
                ),
                AuthField(
                  id: 'register-handle',
                  label: 'Handle',
                  placeholder: 'your_handle',
                  hint: FieldRules.handleHint,
                  controller: _handle,
                  autofillHints: const [AutofillHints.newUsername],
                  maxLength: 30,
                  validator: FieldRules.handle,
                ),
                AuthField(
                  id: 'register-email',
                  label: 'Email address',
                  placeholder: 'you@example.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  maxLength: 254,
                  validator: FieldRules.email,
                ),
                AuthField(
                  id: 'register-password',
                  label: 'Password',
                  placeholder: 'Make it a good one',
                  hint: FieldRules.passwordHint,
                  controller: _password,
                  password: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: FieldRules.newPassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submit,
                ),
                if (error != null) Notice(error!, error: true),
                SubmitButton(
                  label: 'Create account',
                  busy: busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        const SmallNote(
          'We’ll send a verification link to your inbox before you log in.',
        ),
        FormSwitch(
          prompt: 'Already part of the crew? ',
          action: 'Log in',
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed(Routes.login),
        ),
      ],
    );
  }
}
