# Bundled fonts (optional, recommended for guaranteed offline typography)

By default Almuin loads Amiri / Noto Naskh Arabic / Cairo / IBM Plex Sans
Arabic through the `google_fonts` package and caches them on-device after the
first fetch.

For a 100%-offline first launch, download the TTFs and drop them here:

- `Amiri-Regular.ttf`        → mushaf display (default)
- `NotoNaskhArabic-Regular.ttf`
- `Cairo-Regular.ttf`
- `IBMPlexSansArabic-Regular.ttf`

Then register them in `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: Amiri
      fonts: [{ asset: assets/fonts/Amiri-Regular.ttf }]
```

and set `google_fonts` to fall back to asset fonts (or reference the family
directly in `lib/core/theme/app_theme.dart`).
