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
| Home-screen widget | Planned |
| Google Calendar sync (through the Google account on the phone) | Planned |

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
- `test/`: run `flutter test`. Checks known Tết dates (including years where Vietnam and China differ, such as 1985 and
  2007), leap months, and a round trip of every day from 1900 to 2100.

## Building the APK

See [`docs/build-apk.md`](docs/build-apk.md). In short: press `Ctrl+Shift+B` in VS Code; the APK lands in `build\apk\`.
