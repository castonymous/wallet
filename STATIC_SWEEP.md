# OIS Finance v2.0.0 — Static Sweep

This source tree was statically reviewed before packaging.

Checks performed:

- All local `package:wallet/...` imports resolve to files in `lib/`.
- Dart/Kotlin/KTS bracket, string and comment structure is balanced.
- Android XML files parse successfully.
- Android widget `R.id` and layout references resolve to bundled resources.
- `pubspec.yaml` and the personal GitHub Actions YAML parse successfully.
- Declared Flutter asset paths exist.
- Invalid Flutter color constants such as `Colors.white45` are absent.
- Finance model constructor calls were checked for unknown/missing required named parameters.
- Android file export no longer passes a nullable byte array to `OutputStream.write`.
- Notification access checking uses Android framework APIs rather than an unnecessary AndroidX Core dependency.
- Android compile SDK follows the installed Flutter SDK; minSdk is 23 for on-device ML Kit OCR.
- Manifest explicitly removes `android.permission.INTERNET` during manifest merging.

The container used for this patch does not include the Flutter SDK, so the final Android/Flutter compiler validation is intentionally delegated to `.github/workflows/build-personal-apk.yml`. That workflow runs analyzer first and then builds the release APK.
