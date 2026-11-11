import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/api_client.dart';
import 'api/models/auth.dart';
import 'routes.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_thread_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/person_profile_screen.dart';
import 'screens/requests_screen.dart';
import 'screens/start_screen.dart';
import 'screens/verify_email_screen.dart';
import 'shell/signed_in_shell.dart';
import 'theme.dart';
import 'widgets/auth_widgets.dart';

/// The app. Light or dark follows the phone's setting, like the web follows
/// the system's (web/src/lib/theme.ts); switching it repaints every screen
/// without losing where the user is.
class HackyApp extends StatefulWidget {
  const HackyApp({super.key, required this.api});

  final ApiClient api;

  @override
  State<HackyApp> createState() => _HackyAppState();
}

class _HackyAppState extends State<HackyApp> with WidgetsBindingObserver {
  late final _router = AppRouter(widget.api);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static AppPalette _system() =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;

  @override
  void didChangePlatformBrightness() {
    setState(() {});
    // Widgets read AppColors while they build, and many are const, so a
    // rebuild from here wouldn't reach them: mark every one dirty too.
    _rebuildAll(context);
  }

  static void _rebuildAll(BuildContext context) {
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _system();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyle(palette),
      child: MaterialApp(
        title: 'Hacky',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(palette),
        home: StartScreen(api: widget.api),
        onGenerateRoute: _router.route,
      ),
    );
  }
}

/// Builds the screen for each name in [Routes]. Unknown names go to log in.
class AppRouter {
  const AppRouter(this.api);

  final ApiClient api;

  Route<void> route(RouteSettings settings) {
    final Widget screen = switch (settings.name) {
      Routes.register => AuthScreen(api: api, initialTab: AuthTab.register),
      Routes.verifyEmail => VerifyEmailScreen(
        api: api,
        email: settings.arguments as String,
      ),
      Routes.forgotPassword => ForgotPasswordScreen(api: api),
      Routes.home => SignedInShell(api: api, me: settings.arguments as Me?),
      Routes.person => _person(settings.arguments as PersonArgs),
      Routes.requests => RequestsScreen(
        api: api,
        eventSlug: (settings.arguments as RequestsArgs).eventSlug,
      ),
      Routes.chatThread => _chatThread(settings.arguments as ChatThreadArgs),
      _ => AuthScreen(api: api),
    };
    return MaterialPageRoute<void>(settings: settings, builder: (_) => screen);
  }

  Widget _person(PersonArgs args) => PersonProfileScreen(
    api: api,
    eventSlug: args.eventSlug,
    handle: args.handle,
  );

  Widget _chatThread(ChatThreadArgs args) => ChatThreadScreen(
    api: api,
    eventSlug: args.eventSlug,
    conversationId: args.conversationId,
  );
}
