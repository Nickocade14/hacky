import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/models/auth.dart';
import 'routes.dart';
import 'screens/account_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/check_email_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/start_screen.dart';
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
      Routes.checkEmail => CheckEmailScreen(
        api: api,
        email: settings.arguments as String?,
      ),
      Routes.forgotPassword => ForgotPasswordScreen(api: api),
      Routes.account => AccountScreen(api: api, me: settings.arguments as Me?),
      _ => AuthScreen(api: api),
    };
    return MaterialPageRoute<void>(settings: settings, builder: (_) => screen);
  }
}
