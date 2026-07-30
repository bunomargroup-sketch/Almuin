import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/extensions/context_x.dart';
import 'core/router/app_router.dart';
import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';

/// Root widget.
///
/// RTL is automatic: `MaterialApp` derives `Directionality` from the active
/// locale (`ar` => RTL, `en` => LTR). Arabic is the first-class locale.
class AlmuinApp extends ConsumerWidget {
  const AlmuinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'المُعين · Almuin',
      debugShowCheckedModeBanner: false,
      routerConfig: router,

      // ---- Theming (Material 3, luxury minimal Islamic palette) ----
      theme: AppTheme.light(settings),
      darkTheme: AppTheme.dark(settings),
      themeMode: settings.themeMode,

      // ---- Localization & RTL ----
      locale: settings.locale,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supported) {
        // Arabic-first: fall back to Arabic rather than English when unknown.
        if (deviceLocale == null) return const Locale('ar');
        return supported.firstWhere(
          (l) => l.languageCode == deviceLocale.languageCode,
          orElse: () => const Locale('ar'),
        );
      },

      // Apply the user font-scale for mushaf-style reading comfort while
      // keeping the app accessible.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              (media.textScaler.scale(1.0) * settings.fontScale)
                  .clamp(0.85, 1.6),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
