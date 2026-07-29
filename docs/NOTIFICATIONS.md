# Notifications & Smart Scheduling

## What a reminder looks like

- **Title:** `أذكار الصباح · المُعين` (+ category)
- **Body:** the full dhikr expanded **BigText** (large Arabic, easy reading).
- **Reason line:** why now — e.g. "بعد الفجر بعشرين دقيقة", "يوم الجمعة —
  أكثِر من الصلاة على النبي ﷺ", "رمضان — شهر القرآن".
- **Sound/vibration:** follow user style (soft chime optional, see
  `assets/sounds/README.md`).
- **Actions:** `تم ✓` (completed → progress/streak) · `تأجيل ١٠ د`
  (snooze; reschedules itself) · `استمع` (opens `/dhikr/<id>?read=1` → TTS).
- **Tap anywhere:** deep link straight to the dhikr page.

## The scheduling rules (SmartScheduler)

| Category | Rule |
|---|---|
| morning | Fajr + 20 min (per-category offset editable) |
| evening | Maghrib − 20 min |
| afterPrayer | every fard prayer + 5 min (Fajr duplicate dropped in battery saver) |
| sleep | Isha + 45 min; if it lands in quiet hours, pulled to just before quiet hours |
| wakeUp | Fajr − 10 min |
| travel (travel mode only) | sunrise+30, pre-Dhuhr, Asr+15 |
| leaveHome | sunrise + 10 |
| istighfar / tasbeeh / salawat | N nudges evenly spread across the waking day (frequency level low/normal/high → 1/3/6 base, scaled per category) |
| quran | same nudge model; **×2 in Ramadan, ×1.5 in the last ten nights** |
| salawat on Friday | **×1.5 count** + Jumu'ah reason text |
| eid | one takbir reminder after Fajr |

Enforcement: quiet hours defer nudges (never anchors — users opted into
prayer-anchored times), the whole day is de-duplicated and capped at 14
notifications, keeping anchors & seasonal items and evenly thinning nudges.

## Situational categories (honest by design)

Rain, distress, gratitude, mosque/home entry are **not** clock-scheduled —
fake triggers would be worse than none. They are:

1. always browsable in the library,
2. suggested by the AI assistant when you describe the situation, and
3. integration points for future *real* triggers:
   - **rain:** a weather provider hook (one call to a city-level API per day,
     cached) — wire it into `SmartScheduler` as a new context flag,
   - **home/mosque:** geofence service (e.g. `geolocator` + native geofencing)
     emitting reminder events directly.

## Lifecycle

- First plan right after onboarding; re-planned on any relevant setting,
  profile, or location change.
- A workmanager task (`almuin.reschedule.v1`, ~12 h) keeps the rolling
  two-day window fresh and survives reboots (boot receiver re-arms alarms).
- Android 13+ notification permission is requested **after** onboarding.
- If exact-alarm permission is denied, scheduling falls back to inexact
  (AndroidScheduleMode.inexactAllowWhileIdle) and the app keeps working.
- Battery: no exemption request by default; optional in-app `batterySaver`
  mode lowers wakeups instead.
- Do Not Disturb: follows the system channel importance (high, reminder
  category); quiet hours inside the app mirror the user's DND habits.

## Background action handling

```
notificationBackgroundHandler (isolate)
 ├─ done    → AppDatabase.completeByNotificationId (progress + streak ✓)
 ├─ snooze  → status=snoozed + scheduleReminder(+10 min)
 └─ listen/tap → persist deep link → MainShell consumes on foreground
                 → context.go('/dhikr/<id>?read=1')
```
