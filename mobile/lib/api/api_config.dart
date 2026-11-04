import 'package:flutter/foundation.dart';

/// Where the API lives. Paths in docs/openapi.yaml already start with `/api`.
abstract final class ApiConfig {
  /// Production server. TODO: replace with the team's domain once it's bought
  /// (docs/openapi.yaml still lists it as pending).
  static const productionBaseUrl = 'https://your-domain.com';

  /// The dev server (`npm run dev` in server/) as seen from the Android
  /// emulator: 10.0.2.2 is the host machine's localhost.
  static const androidEmulatorBaseUrl = 'http://10.0.2.2:8787';

  /// Release builds use production, debug builds use the emulator address.
  /// Override with `--dart-define=API_BASE_URL=https://...`.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? productionBaseUrl : androidEmulatorBaseUrl,
  );
}
