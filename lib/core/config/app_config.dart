import 'package:flutter/widgets.dart';

/// Compile-time configuration. Secrets are injected with --dart-define so no
/// credential ever lives in the repository:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
abstract final class AppConfig {
  static const String appNameAr = 'المُعين';
  static const String appNameEn = 'Almuin';

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// The app is intentionally fully functional without a backend; sync is a
  /// progressive enhancement (see docs/ARCHITECTURE.md).
  static bool get supabaseEnabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Optional AI edge function name on Supabase (see supabase/functions).
  static const String aiFunctionName = 'ai-assistant';
}

/// Locale registry — Arabic is the primary, first-class locale.
abstract final class AppLocales {
  static const arabic = Locale('ar');
  static const english = Locale('en');
  static const supported = [arabic, english];
}
