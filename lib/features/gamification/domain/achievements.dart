import 'package:flutter/material.dart';

/// Achievement catalogue. All are derivable from local DB facts — unlocking
/// happens in [AchievementEvaluator] whenever progress changes.
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.descAr,
    required this.icon,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String descAr;
  final IconData icon;
}

abstract final class AchievementCatalog {
  static const List<AchievementDef> all = [
    AchievementDef(
      id: 'first_dhikr',
      titleAr: 'البداية المباركة',
      titleEn: 'Blessed beginning',
      descAr: 'أكملت أول ذكر لك في المُعين',
      icon: Icons.emoji_events_outlined,
    ),
    AchievementDef(
      id: 'streak_3',
      titleAr: 'ثلاثة أيام متواصلة',
      titleEn: '3-day streak',
      descAr: 'المداومة أحب الأعمال إلى الله',
      icon: Icons.local_fire_department_outlined,
    ),
    AchievementDef(
      id: 'streak_7',
      titleAr: 'أسبوع من الذكر',
      titleEn: 'One week of dhikr',
      descAr: 'سبعة أيام متواصلة — ما شاء الله',
      icon: Icons.whatshot_outlined,
    ),
    AchievementDef(
      id: 'streak_30',
      titleAr: 'شهر كامل',
      titleEn: 'Full month',
      descAr: 'ثلاثون يومًا متواصلة من المداومة',
      icon: Icons.military_tech_outlined,
    ),
    AchievementDef(
      id: 'tasbeeh_100',
      titleAr: 'مائة تسبيحة',
      titleEn: '100 tasbeeh',
      descAr: 'سبحان الله وبحمده مائة مرة تُحطّ الخطايا',
      icon: Icons.touch_app_outlined,
    ),
    AchievementDef(
      id: 'tasbeeh_1000',
      titleAr: 'ألف تسبيحة',
      titleEn: '1,000 tasbeeh',
      descAr: 'ألف مرة ذكرتَ الله بالتسبيح',
      icon: Icons.diamond_outlined,
    ),
    AchievementDef(
      id: 'day_full',
      titleAr: 'يوم مكتمل',
      titleEn: 'Complete day',
      descAr: 'أكملت كل تذكيرات يوم واحد',
      icon: Icons.check_circle_outline,
    ),
    AchievementDef(
      id: 'fajr_warrior',
      titleAr: 'رفيق الفجر',
      titleEn: 'Fajr companion',
      descAr: 'أكملت أذكار الصباح ٧ مرات',
      icon: Icons.wb_twilight,
    ),
    AchievementDef(
      id: 'salawat_friday',
      titleAr: 'محب الجمعة',
      titleEn: 'Friday lover',
      descAr: 'صلَّيت على النبي ﷺ ١٠٠ مرة في يوم جمعة',
      icon: Icons.auto_awesome,
    ),
    AchievementDef(
      id: 'adhkar_50',
      titleAr: 'خمسون ذكرًا',
      titleEn: '50 adhkar read',
      descAr: 'قرأت خمسين ذكرًا موثقًا',
      icon: Icons.menu_book_outlined,
    ),
  ];

  static AchievementDef? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// Encouraging lines cycled on the progress surfaces (localized in arb where
/// user-facing chrome lives; these stay Arabic since content is Arabic-first).
const kEncouragementsAr = [
  'أحب الأعمال إلى الله أدومها وإن قلّ — متفق عليه',
  'فاذكروني أذكركم — البقرة ١٥٢',
  'ألا بذكر الله تطمئن القلوب — الرعد ٢٨',
  'كلمتان خفيفتان على اللسان ثقيلتان في الميزان: سبحان الله وبحمده سبحان الله العظيم',
  'ما شاء الله، استمر! القليل الدائم خير من الكثير المنقطع',
];
