import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/extensions/context_x.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/glass.dart';

/// The "More" tab: settings hub + links to statistics, achievements,
/// reminders management, about/privacy.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMore)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ---- Quick links --------------------------------------------
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(l10n.moreReminders),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/reminders'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bar_chart_outlined),
                title: Text(l10n.moreStatistics),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/stats'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: Text(l10n.moreAchievements),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/achievements'),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ---- Appearance ---------------------------------------------
          _Header(l10n.settingsAppearance),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: Text(l10n.settingsDarkMode),
                trailing: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                      visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.settings_suggest, size: 16)),
                    ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode, size: 16)),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode, size: 16)),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) =>
                      notifier.update((st) => st.copyWith(themeMode: v.first)),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.settingsLanguage),
                trailing: SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                      visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('العربية')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {s.locale.languageCode},
                  onSelectionChanged: (v) => notifier.update(
                      (st) => st.copyWith(locale: Locale(v.first))),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.font_download_outlined),
                title: Text(l10n.settingsArabicFont),
                trailing: DropdownButton<ArabicFontKey>(
                  value: s.arabicFontKey,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                        value: ArabicFontKey.amiri, child: Text('أميري')),
                    DropdownMenuItem(
                        value: ArabicFontKey.notoNaskh, child: Text('نسخ')),
                    DropdownMenuItem(
                        value: ArabicFontKey.cairo, child: Text('القاهرة')),
                  ],
                  onChanged: (v) => v == null
                      ? null
                      : notifier.update(
                          (st) => st.copyWith(arabicFontKey: v)),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  const Icon(Icons.format_size),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Slider(
                      value: s.fontScale,
                      min: 0.9,
                      max: 1.5,
                      divisions: 6,
                      label: s.fontScale.toStringAsFixed(2),
                      onChanged: (v) =>
                          notifier.update((st) => st.copyWith(fontScale: v)),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ---- Notifications ------------------------------------------
          _Header(l10n.settingsNotifications),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.music_note_outlined),
                title: Text(l10n.settingsSound),
                value: s.notificationSound,
                onChanged: (v) => notifier
                    .update((st) => st.copyWith(notificationSound: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.vibration),
                title: Text(l10n.settingsVibration),
                value: s.notificationVibration,
                onChanged: (v) => notifier
                    .update((st) => st.copyWith(notificationVibration: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.record_voice_over_outlined),
                title: Text(l10n.settingsReadAloud),
                value: s.ttsEnabled,
                onChanged: (v) =>
                    notifier.update((st) => st.copyWith(ttsEnabled: v)),
              ),
              const Divider(height: 24),
              SwitchListTile(
                secondary: const Icon(Icons.cloud_outlined),
                title: Text(l10n.settingsContextWeather),
                subtitle: Text(l10n.settingsContextSection),
                value: s.contextWeather,
                onChanged: (v) =>
                    notifier.update((st) => st.copyWith(contextWeather: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.public_outlined),
                title: Text(l10n.settingsContextNews),
                subtitle: Text(l10n.settingsContextNewsHint),
                isThreeLine: true,
                value: s.contextNews,
                onChanged: (v) =>
                    notifier.update((st) => st.copyWith(contextNews: v)),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('معاينة إشعار'),
                subtitle: const Text('جرّب شكل التذكير'),
                trailing: const Icon(Icons.play_circle_outline),
                onTap: () => NotificationService.instance.showNow(
                  999999,
                  'أذكار الصباح · المُعين',
                  'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
                  reason: 'بعد الفجر بعشرين دقيقة',
                  payload: '/adhkar/morn_asbahna',
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ---- Sync & about -------------------------------------------
          _Header(l10n.settingsCloudSync),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(AppConfig.supabaseEnabled
                    ? l10n.settingsCloudSyncOn
                    : l10n.settingsCloudSyncOff),
                trailing: AppConfig.supabaseEnabled
                    ? IconButton(
                        icon: const Icon(Icons.sync),
                        onPressed: () =>
                            ref.invalidate(syncNowProvider),
                      )
                    : null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(l10n.settingsPrivacy),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.settingsAbout),
                subtitle: const Text('المُعين ١٫٠٫٠ — رفيقك للذكر'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: context.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}
