import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/models/auth.dart';
import '../auth/error_text.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/auth_widgets.dart';

/// Placeholder home after login: who you are, your events, and Sign out.
/// Same texts as `AccountPage` in web/src/App.tsx.
///
/// Uses [me] from the login response, or loads `GET /api/me` when the app
/// starts with a saved token. A 401 means the token is no longer valid, so it
/// goes back to log in.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.api, this.me});

  final ApiClient api;
  final Me? me;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Me? _me = widget.me;
  String? _problem;

  @override
  void initState() {
    super.initState();
    if (_me == null) _load();
  }

  Future<void> _load() async {
    setState(() => _problem = null);
    try {
      final me = await widget.api.getMe();
      if (mounted) setState(() => _me = me);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _toLogin();
      } else {
        setState(() => _problem = ErrorText.of(e));
      }
    } catch (e) {
      if (mounted) setState(() => _problem = ErrorText.of(e));
    }
  }

  Future<void> _signOut() async {
    await widget.api.logout();
    if (mounted) _toLogin();
  }

  void _toLogin() =>
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (_) => false);

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return AuthLayout(
      children: [
        PageHeading(
          eyebrow: 'YOUR NEXT CHAPTER',
          title: me != null
              ? 'You’re in, ${me.profile.name.split(' ').first}.'
              : 'Welcome back.',
          body: const TextSpan(
            text: 'A big idea starts with a connection. Welcome to Hacky.',
          ),
        ),
        if (me == null && _problem == null)
          const Text(
            'Loading your account…',
            style: TextStyle(color: AppColors.muted),
          ),
        if (_problem != null) ...[
          Notice(_problem!, error: true),
          const SizedBox(height: 20),
          SecondaryButton(label: 'Try again', onPressed: _load),
        ],
        if (me != null) AccountCard(me: me),
        const SizedBox(height: 20),
        SecondaryButton(label: 'Sign out', onPressed: _signOut),
      ],
    );
  }
}

/// The user's initial, name, handle and events.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    final profile = me.profile;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.line),
        borderRadius: AppTheme.borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.action,
              foregroundColor: AppColors.onAction,
              child: Text(
                profile.name.isEmpty
                    ? '?'
                    : profile.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.name,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${profile.handle}',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 20),
          const Text(
            'YOUR EVENTS',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.7,
            ),
          ),
          if (me.events.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                'No events yet. Your organizer can help you join.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          for (final event in me.events)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _capitalize(event.role.name),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _capitalize(String word) =>
      word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';
}
