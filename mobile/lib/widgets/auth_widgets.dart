// Building blocks of the auth screens. Each one mirrors a piece of
// web/src/components.tsx and its styles in web/src/styles.css (phone layout).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../routes.dart';
import '../theme.dart';

const _bold = FontWeight.w700;

/// The white page with the Hacky brand on top, like the web's phone layout.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 25, 24, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandHeader(),
                  const SizedBox(height: 44),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "h." mark followed by "hacky." in the brand colors.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hacky',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.action,
              borderRadius: AppTheme.borderRadius,
            ),
            child: const Text(
              'h.',
              style: TextStyle(
                color: AppColors.onAction,
                fontSize: 23,
                fontWeight: _bold,
                letterSpacing: -2,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 11),
          const Text.rich(
            TextSpan(
              text: 'hacky',
              children: [
                TextSpan(
                  text: '.',
                  style: TextStyle(color: AppColors.action),
                ),
              ],
            ),
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 27,
              fontWeight: _bold,
              letterSpacing: -1.6,
            ),
          ),
        ],
      ),
    );
  }
}

enum AuthTab { login, register }

/// The "Log in" / "Create account" switch on top of both forms.
class AuthTabs extends StatelessWidget {
  const AuthTabs({super.key, required this.current});

  final AuthTab current;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 33),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: AppTheme.borderRadius,
      ),
      child: Row(
        children: [
          _tab(context, 'Log in', AuthTab.login, Routes.login),
          _tab(context, 'Create account', AuthTab.register, Routes.register),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String label, AuthTab tab, String route) {
    final active = tab == current;
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: active
              ? null
              : () => Navigator.of(context).pushReplacementNamed(route),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.white : null,
              borderRadius: AppTheme.borderRadius,
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 5,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: _bold,
                color: active ? AppColors.ink : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Eyebrow, title and optional body text at the top of each screen.
class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.body,
  });

  final String eyebrow;
  final String title;

  /// Muted text; use [strong] for the bold parts.
  final InlineSpan? body;

  static TextSpan strong(String text) => TextSpan(
    text: text,
    style: const TextStyle(color: AppColors.ink, fontWeight: _bold),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: AppColors.action,
              fontSize: 10,
              fontWeight: _bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 33,
                fontWeight: _bold,
                letterSpacing: -1.1,
                height: 1.2,
              ),
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 12),
            Text.rich(
              body!,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A labeled text field. Password fields get a Show / Hide button.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.id,
    required this.label,
    required this.controller,
    this.placeholder,
    this.hint,
    this.password = false,
    this.keyboardType,
    this.autofillHints,
    this.validator,
    this.maxLength,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  /// Same id as the web input; tests find the field with `Key(id)`.
  final String id;
  final String label;
  final TextEditingController controller;
  final String? placeholder;

  /// Small help text under the field.
  final String? hint;
  final bool password;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final int? maxLength;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: _bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: widget.label,
          child: TextFormField(
            key: Key(widget.id),
            controller: widget.controller,
            obscureText: widget.password && !_visible,
            enableSuggestions: !widget.password,
            autocorrect: false,
            keyboardType: widget.keyboardType,
            autofillHints: widget.autofillHints,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: (_) => widget.onSubmitted?.call(),
            validator: widget.validator,
            inputFormatters: [
              if (widget.maxLength != null)
                LengthLimitingTextInputFormatter(widget.maxLength),
            ],
            style: const TextStyle(color: AppColors.ink, fontSize: 16),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: const TextStyle(color: AppColors.muted),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              suffixIcon: widget.password ? _toggle() : null,
            ),
          ),
        ),
        if (widget.hint != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.hint!,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _toggle() {
    final action = _visible ? 'Hide' : 'Show';
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Semantics(
        label: '$action ${widget.label.toLowerCase()}',
        excludeSemantics: true,
        button: true,
        child: TextButton(
          onPressed: () => setState(() => _visible = !_visible),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.muted,
            textStyle: const TextStyle(fontSize: 11),
          ),
          child: Text(action),
        ),
      ),
    );
  }
}

/// A green success or red error message box.
class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: error ? AppColors.dangerWash : AppColors.successWash,
          border: Border.all(color: AppColors.line),
          borderRadius: AppTheme.borderRadius,
        ),
        child: Text(
          message,
          style: TextStyle(
            color: error ? AppColors.danger : AppColors.success,
            fontSize: 13,
            height: 1.65,
          ),
        ),
      ),
    );
  }
}

/// The blue full-width button. Shows "Please wait…" while [busy].
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(49)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: busy
            ? const [
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.disabledInk,
                  ),
                ),
                Text('Please wait…'),
              ]
            : [Text(label), const Icon(Icons.arrow_forward, size: 17)],
      ),
    );
  }
}

/// The white outlined button ("Try again", "Sign out").
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(49),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: _bold,
        ),
      ),
      child: Text(label),
    );
  }
}

/// A small bold blue text link ("Forgot password?", "Create an account").
class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.action,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size(0, 40),
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12,
          fontWeight: _bold,
        ),
      ),
      child: Text(label),
    );
  }
}

/// "New around here? Create an account" under a form.
class FormSwitch extends StatelessWidget {
  const FormSwitch({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            prompt,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          LinkButton(label: action, onPressed: onPressed),
        ],
      ),
    );
  }
}

/// Small centered muted text under a form.
class SmallNote extends StatelessWidget {
  const SmallNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          height: 1.7,
        ),
      ),
    );
  }
}

/// "← Back to log in" on the screens that aren't the login form.
class BackToLogin extends StatelessWidget {
  const BackToLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: TextButton.icon(
          onPressed: () =>
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(Routes.login, (_) => false),
          icon: const Icon(Icons.arrow_back, size: 17),
          label: const Text('Back to log in'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.muted,
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// The square icon above the heading on the email screens.
class StatusIcon extends StatelessWidget {
  const StatusIcon(this.glyph, {super.key});

  final String glyph;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 52,
          height: 52,
          margin: const EdgeInsets.only(bottom: 25),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.hover,
            borderRadius: AppTheme.borderRadius,
          ),
          child: Text(
            glyph,
            style: const TextStyle(color: AppColors.action, fontSize: 27),
          ),
        ),
      ),
    );
  }
}
