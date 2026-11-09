import 'package:flutter/material.dart';

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

class HackyApp extends StatelessWidget {
  const HackyApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hacky',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: StartScreen(api: api),
      onGenerateRoute: AppRouter(api).route,
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
