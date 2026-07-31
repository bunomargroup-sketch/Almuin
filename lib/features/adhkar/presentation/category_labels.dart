import 'package:flutter/material.dart';

import '../../../core/extensions/context_x.dart';
import '../domain/dhikr.dart';

/// Shared category → localized label mapping (used by the library,
/// onboarding wizard, and reminders pages).
String adhkarCategoryLabel(BuildContext context, DhikrCategory c) {
  final l10n = context.l10n;
  return switch (c) {
    DhikrCategory.morning => l10n.catMorning,
    DhikrCategory.evening => l10n.catEvening,
    DhikrCategory.afterPrayer => l10n.catAfterPrayer,
    DhikrCategory.sleep => l10n.catSleep,
    DhikrCategory.wakeUp => l10n.catWakeUp,
    DhikrCategory.enterHome => l10n.catEnterHome,
    DhikrCategory.leaveHome => l10n.catLeaveHome,
    DhikrCategory.enterMosque => l10n.catEnterMosque,
    DhikrCategory.leaveMosque => l10n.catLeaveMosque,
    DhikrCategory.travel => l10n.catTravel,
    DhikrCategory.rain => l10n.catRain,
    DhikrCategory.distress => l10n.catDistress,
    DhikrCategory.gratitude => l10n.catGratitude,
    DhikrCategory.istighfar => l10n.catIstighfar,
    DhikrCategory.tasbeeh => l10n.catTasbeeh,
    DhikrCategory.salawat => l10n.catSalawat,
    DhikrCategory.quran => l10n.catQuran,
    DhikrCategory.hadith => l10n.catHadith,
    DhikrCategory.dua => l10n.catDua,
    DhikrCategory.custom => l10n.catCustom,
  };
}

/// Category → icon mapping (single source). Modern, minimal glyphs.
extension DhikrCategoryIcon on DhikrCategory {
  IconData get icon => switch (this) {
        DhikrCategory.morning => Icons.wb_twilight,
        DhikrCategory.evening => Icons.nights_stay_outlined,
        DhikrCategory.afterPrayer => Icons.mosque_outlined,
        DhikrCategory.sleep => Icons.bedtime_outlined,
        DhikrCategory.wakeUp => Icons.alarm,
        DhikrCategory.enterHome => Icons.door_front_door_outlined,
        DhikrCategory.leaveHome => Icons.directions_walk_outlined,
        DhikrCategory.enterMosque => Icons.meeting_room_outlined,
        DhikrCategory.leaveMosque => Icons.outbond_outlined,
        DhikrCategory.travel => Icons.flight_takeoff,
        DhikrCategory.rain => Icons.thunderstorm_outlined,
        DhikrCategory.distress => Icons.favorite_border,
        DhikrCategory.gratitude => Icons.volunteer_activism_outlined,
        DhikrCategory.istighfar => Icons.water_drop_outlined,
        DhikrCategory.tasbeeh => Icons.touch_app_outlined,
        DhikrCategory.salawat => Icons.auto_awesome,
        DhikrCategory.quran => Icons.menu_book_outlined,
        DhikrCategory.hadith => Icons.format_quote_outlined,
        DhikrCategory.dua => Icons.pan_tool_outlined,
        DhikrCategory.custom => Icons.edit_note,
      };
}
