# Notification sound (optional)

Drop a gentle chime as `soft_chime.mp3` here (keep it under 1 second, soft
attack — think a single mu'adhdhin-like bell note, nothing jarring).

Then:

1. Copy it into the native folders too:
   - Android: `android/app/src/main/res/raw/soft_chime.mp3`
   - iOS: add `soft_chime.aiff` (or `.caf`, ≤30s) to the Runner bundle in Xcode.
2. In `lib/core/services/notification_service.dart` set:

```dart
sound: const RawResourceAndroidNotificationSound('soft_chime'),
```

and `DarwinNotificationDetails(sound: 'soft_chime.aiff')`.

Until then, Almuin uses each platform's default notification sound with the
user's sound/vibration preferences.
