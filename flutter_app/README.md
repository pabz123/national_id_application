# National ID Flutter App

Flutter client for the National ID assignment (BLoC architecture), integrated with Odoo 19 APIs.

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

## Setup

1. Install dependencies:
   `flutter pub get`
2. Static checks:
   `flutter analyze`
3. Tests:
   `flutter test`

## Run

### Web server (recommended for local integration)

`flutter run -d web-server --web-port=5000 --dart-define=API_BASE_URL=http://127.0.0.1:8067`

Open `http://127.0.0.1:5000`.

### Chrome device

`flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8067`

## Build

Build distributable web artifacts:

`flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:8067`

Output: `build/web/`
