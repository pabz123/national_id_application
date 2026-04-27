# National ID Flutter App

Flutter client for the National ID assignment (BLoC architecture), integrated with Odoo APIs.

## Features

- Authentication: signup/login + persisted session
- 4-step application wizard:
  1. Account
  2. Personal Info
  3. Documents
  4. Review
- File uploads (passport photo + LC letter)
- Tracking with:
  - timeline
  - decision reason
  - next-step recommendation

## Prerequisites

- Flutter SDK 3.41+
- Dart 3.11+
- Running Odoo backend API

## Runtime Configuration

The app supports compile-time environment variables:

- `API_BASE_URL` (required for non-local environments)
- `ODOO_DB` (database name)

Example for Odoo.sh:

```bash
--dart-define=API_BASE_URL=https://mulungiinternship.odoo.com \
--dart-define=ODOO_DB=mulungiinternship
```

## Setup

1. Install dependencies:
   `flutter pub get`
2. Static checks:
   `flutter analyze`
3. Tests:
   `flutter test`

## Run

### Web server (recommended for local integration)

```bash
flutter run -d web-server --web-port=5000 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8067 \
  --dart-define=ODOO_DB=Odoo-Project
```

Open `http://127.0.0.1:5000`.

### Android device (against Odoo.sh)

```bash
flutter run -d android \
  --dart-define=API_BASE_URL=https://mulungiinternship.odoo.com \
  --dart-define=ODOO_DB=mulungiinternship
```

## Build

### Build web

```bash
flutter build web \
  --dart-define=API_BASE_URL=https://mulungiinternship.odoo.com \
  --dart-define=ODOO_DB=mulungiinternship
```

Output: `build/web/`

### Build optimized APKs (split ABI)

Use split-per-ABI so each APK is smaller:

```bash
flutter build apk --release --split-per-abi \
  --dart-define=API_BASE_URL=https://mulungiinternship.odoo.com \
  --dart-define=ODOO_DB=mulungiinternship
```

Generated files:

- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

For most real Android phones, share `app-arm64-v8a-release.apk`.
