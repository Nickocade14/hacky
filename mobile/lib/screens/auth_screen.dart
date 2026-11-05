import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../forms/login_form.dart';
import '../forms/register_form.dart';
import '../widgets/auth_widgets.dart';

/// Log in and Create account on one screen. The mascot, wordmark and tab
/// switch stay put; only the form below crossfades when the tab changes.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.api,
    this.initialTab = AuthTab.login,
  });

  final ApiClient api;
  final AuthTab initialTab;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthTab _tab = widget.initialTab;

  void _show(AuthTab tab) {
    FocusScope.of(context).unfocus();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      header: const MascotHeader(),
      children: [
        AuthTabs(current: _tab, onChanged: _show),
        AnimatedSwitcher(
          duration: AuthTabs.duration,
          // Keep both forms pinned to the top while they crossfade.
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: switch (_tab) {
            AuthTab.login => LoginForm(
              key: const ValueKey(AuthTab.login),
              api: widget.api,
              onCreateAccount: () => _show(AuthTab.register),
            ),
            AuthTab.register => RegisterForm(
              key: const ValueKey(AuthTab.register),
              api: widget.api,
              onLogIn: () => _show(AuthTab.login),
            ),
          },
        ),
      ],
    );
  }
}
