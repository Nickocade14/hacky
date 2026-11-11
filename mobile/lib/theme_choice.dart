import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the Dark mode switch on 08 My profile is remembered.
abstract interface class ThemeChoiceStore {
  /// True for dark, false for light, null when the user never chose.
  Future<bool?> read();
  Future<void> write(bool dark);
}

/// On the phone, so the choice stays after the app restarts.
class DeviceThemeChoiceStore implements ThemeChoiceStore {
  DeviceThemeChoiceStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'hacky_theme';

  final FlutterSecureStorage _storage;

  @override
  Future<bool?> read() async => switch (await _storage.read(key: _key)) {
    'dark' => true,
    'light' => false,
    _ => null,
  };

  @override
  Future<void> write(bool dark) =>
      _storage.write(key: _key, value: dark ? 'dark' : 'light');
}

/// Lasts while the app runs. The default, and what tests use.
class MemoryThemeChoiceStore implements ThemeChoiceStore {
  bool? _dark;

  @override
  Future<bool?> read() async => _dark;

  @override
  Future<void> write(bool dark) async => _dark = dark;
}

/// Light or dark: the user's choice, else the phone's setting. Same rule as
/// the web (web/src/lib/theme.ts). [HackyApp] listens and repaints.
class ThemeChoice extends ChangeNotifier {
  ThemeChoice([ThemeChoiceStore? store])
    : _store = store ?? MemoryThemeChoiceStore();

  /// The app's one choice. lib/main.dart gives it the device store.
  static ThemeChoice instance = ThemeChoice();

  final ThemeChoiceStore _store;
  bool? _dark;

  /// Null follows the phone.
  bool? get dark => _dark;

  /// Reads the saved choice, if any.
  Future<void> load() async {
    try {
      _dark = await _store.read();
    } catch (_) {
      return; // Unreadable storage: follow the phone.
    }
    notifyListeners();
  }

  void choose({required bool dark}) {
    _dark = dark;
    notifyListeners();
    // If it isn't saved, the choice lasts until the app closes.
    _store.write(dark).catchError((Object _) {});
  }
}
