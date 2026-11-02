# Building the APK

Android Studio is not needed: Flutter runs Gradle from the command line, using the Android SDK and JDK already installed.

## Steps

1. **Build.** In VS Code press **`Ctrl+Shift+B`** (task "Build APK").
   Or in a terminal: `powershell -ExecutionPolicy Bypass -File tool/build_apk.ps1`
2. **Wait.** The first build (or the first after `flutter clean`) takes a few minutes; later builds are faster.
   At the end the terminal prints:
   ```
   APK: D:\dev\customized_apps\amlich_vietnam\build\apk\amlich-1.0.0-20261102-1430.apk
   ```
3. **Install.** Copy the `.apk` without a suffix to the phone, open it, and allow "Install unknown apps".
   A new build installs over the old one because both are signed with the same key.

## Output files (`build\apk\`)

| File | For |
|---|---|
| `amlich-<version>-<date-time>.apk` | Almost every current phone (arm64) |
| `amlich-<version>-<date-time>-arm32.apk` | Very old 32-bit Android phones |
| `amlich-<version>-<date-time>-x86_64.apk` | Emulators |

The version comes from the `version:` line of `pubspec.yaml` (the part before `+`); the date-time is the build time
(`yyyyMMdd-HHmm`), so builds of the same version do not overwrite each other.

## Troubleshooting

- **Odd errors after changing dependencies:** run `flutter clean`, then `flutter pub get`, then build again.
- **`OutOfMemoryError` or a hanging build:** Gradle's memory is set by `org.gradle.jvmargs=-Xmx3g` in
  `android/gradle.properties`. Close other applications, or raise it to `-Xmx4g`.
- The APK is signed with the **debug key**. That is fine for personal use, but it cannot be uploaded to Google Play.
