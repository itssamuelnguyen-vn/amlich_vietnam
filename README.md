# amlich_vietnam

A Vietnamese lunar calendar app for Android, built with Flutter. It is for personal use: the APK is built locally and
installed directly on the phone, not published to Google Play. The app's user interface is in Vietnamese.

## Features

| Feature | Status |
|---|---|
| Month view with solar and lunar dates, holidays, stem-branch (Can Chi), solar terms, auspicious hours | Done |
| Day page: moon phase by lunar day, auspicious/inauspicious day star, a proverb per day | Done |
| Countdown to upcoming holidays, quick month/year picker, lunar-to-solar converter | Done |
| Event notes stored in SQLite, repeating monthly or yearly on a solar or lunar date (death anniversaries, lunar birthdays) | Done |
| Date tools: days between two dates (with weeks, months and working days), add/subtract days/weeks/months/years | Done |
| Home-screen widgets: "today" (4×2, shrinks to 2×2) and month grid (4×4) with event dots | Done |
| Countdown widget to the next Tết or a chosen event | Done |
| Reminders: per event (on the day or 1/3/7 days ahead) and the day before every mùng 1 and rằm | Done |
| Day almanac: trực, lunar mansion, lucky directions, clashing ages, Tam nương / Nguyệt kỵ | Done |
| Age lookup (lunar age, zodiac, nạp âm element, harmonies and clashes), family ages, good-day search | Done |
| Year view (12 months) | Done |
| Day counters ("together for 1,234 days"): saved milestones with photo, upcoming 100/1000-day marks and anniversaries, notifications and a home-screen widget | Done |
| Settings: theme, text size, week start, holiday groups; backup and restore to a file | Done |
| Google Calendar sync: one-way, app → a calendar on the phone (normally Google), no OAuth needed | Done |

## Project layout

- `lib/lunar/lunar_calendar.dart`: solar ↔ lunar conversion using Hồ Ngọc Đức's algorithm in UTC+7, with leap months,
  stem-branch, solar terms, auspicious hours and day stars. The Vietnamese calendar differs from the Chinese one (UTC+8)
  in some years, e.g. Tết 1985, so Chinese-calendar libraries cannot be used.
- `lib/lunar/holidays.dart`: solar and lunar holidays, upcoming-holiday countdown.
- `lib/lunar/proverbs.dart`: Vietnamese proverbs shown on the day page.
- `lib/events/`: the event model (occurrence rules) and `EventStore`, which keeps events in memory and writes them
  through to SQLite (`sqflite`); tests use the in-memory backend.
- `lib/theme.dart`: lacquer-red and gold theme, light and dark.
- `lib/screens/home_screen.dart`: bottom navigation with three tabs: calendar, events (`events_screen.dart`,
  `event_editor.dart`) and date tools (`tools_screen.dart`).
- `lib/screens/calendar_screen.dart`: the calendar tab, assembled from `lib/widgets/`: the day page (swipe to change
  day), the month grid (swipe to change month), the day's events, auspicious hours, upcoming holidays, month picker and lunar converter.
- `lib/widget/widget_bridge.dart` and `android/app/src/main/kotlin/.../`: the home-screen widgets. They are native
  Android `AppWidgetProvider`s with their own Kotlin port of the lunar calendar (`LunarCalendar.kt`), so they stay
  correct at midnight without starting Flutter. Flutter only sends them the upcoming event occurrences over the
  `amlich/widget` channel; tapping a day in the month widget opens the app on that day.
- `lib/lunar/almanac.dart`: day-selection rules (trực by solar-term month, the 28 mansions, Hỷ thần / Tài thần,
  clashes and harmonies, nạp âm). These are folk beliefs whose details vary between sources; the rules were checked
  against a published almanac on 13 dates (`test/almanac_test.dart`).
- `lib/data/`: the SQLite database (`app_database.dart`, version 3), settings, family ages and backup files.
- `lib/counters/`: day counters (model, store, screens). Photos are copied into the app's files; backups leave them out.
- Reminders (`Reminders.kt`) are scheduled natively from the occurrences Flutter syncs, so they fire with the app
  closed; they are rescheduled after each one, at midnight, on boot and on every sync.
- Google Calendar sync (`lib/sync/google_sync.dart`, `GoogleCalendarSync.kt`) writes events into a calendar the user
  picks through Android's CalendarContract, so the phone's Google account uploads them; no OAuth or Cloud project.
  Lunar recurrences cannot be calendar repeat rules, so each occurrence in the next two years is an all-day event.
  Rows are tracked by key and content hash, so a sync only touches what changed; past occurrences stay as history.
- `test/`: run `flutter test`. Checks known Tết dates (including years where Vietnam and China differ, such as 1985 and
  2007), leap months, and a round trip of every day from 1900 to 2100.
- `android/app/src/test/`: JVM test checking the Kotlin port against values printed by the Dart code. Run it with
  `android\gradlew.bat :app:testDebugUnitTest` (set `JAVA_HOME` to the JDK, e.g. `D:\dev\android-sdk\jbr`). Regenerate
  its fixture when the Dart lunar code changes.

## App icon

The launcher icon comes from `tool/icon/logo.png`. After replacing that file, regenerate every size with
`python tool/make_icons.py` (needs Pillow): it trims the logo, centres it so that even a circular mask keeps every drawn
pixel, and writes the legacy, adaptive (white background) and monochrome (Android 13+ themed) icons.

## Building the APK

See [`docs/build-apk.md`](docs/build-apk.md). In short: press `Ctrl+Shift+B` in VS Code; the APK lands in `build\apk\`.
