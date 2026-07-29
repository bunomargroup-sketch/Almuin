import 'package:flutter/foundation.dart';

/// Tiny logging facade — swap for a crash reporter in release builds.
void logInfo(String message) {
  if (kDebugMode) debugPrint('[almuin] $message');
}

void logWarn(String message, [Object? error, StackTrace? st]) {
  if (kDebugMode) {
    debugPrint('[almuin][warn] $message ${error ?? ''}');
    if (st != null) debugPrint(st.toString());
  }
}
