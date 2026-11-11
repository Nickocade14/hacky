import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../routes.dart';
import '../theme.dart';

/// Shown for a moment at launch: restores the session from secure storage.
/// With a saved token it opens the signed-in shell, which checks the token
/// with `GET /api/me` and falls back to log in on a 401. Otherwise it opens
/// log in.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    bool loggedIn;
    try {
      loggedIn = await widget.api.isLoggedIn;
    } catch (_) {
      // Unreadable secure storage: start signed out.
      loggedIn = false;
    }
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacementNamed(loggedIn ? Routes.home : Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
