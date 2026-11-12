import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../auth/field_rules.dart';
import '../auth/submit_action.dart';
import '../routes.dart';
import '../widgets/auth_widgets.dart';

/// The "Create account" tab of [AuthScreen]. Same texts and limits as
/// `RegisterPage` in web/src/AuthPages.tsx. On success, opens the screen
/// where the user types the emailed code.
class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key, required this.api, required this.onLogIn});

  final ApiClient api;

  /// Switches to the "Log in" tab.
  final VoidCallback onLogIn;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm>
    with SubmitAction<RegisterForm> {
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
      handle: FieldRules.normalizeHandle(_handle.text),
      email: email,
      password: _password.text,
    );
    await runAction(() async {
      await widget.api.register(body);
      if (!mounted) return;
      // Not awaited: the future only completes when that screen closes.
      Navigator.of(context).pushNamed(Routes.verifyEmail, arguments: email);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  label: 'Username',
                  placeholder: 'yourname',
                  prefix: '@',
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
          'We’ll email you a 6-digit code to finish creating your account.',
        ),
        FormSwitch(
          prompt: 'Already part of the crew? ',
          action: 'Log in',
          onPressed: widget.onLogIn,
        ),
      ],
    );
  }
}
