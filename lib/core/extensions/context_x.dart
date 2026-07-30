import 'package:flutter/material.dart';

// Re-export the generated localizations so feature code imports one file.
export 'package:almuin/l10n/app_localizations.dart' show AppLocalizations;

import 'package:almuin/l10n/app_localizations.dart';

extension ContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;

  bool get isArabic => Directionality.of(this) == TextDirection.rtl;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
