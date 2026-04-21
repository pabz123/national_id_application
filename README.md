# National ID Application (Odoo 19 + Flutter)

Production-style National ID workflow with:
- Odoo approval pipeline (Stage 1 + Stage 2 + rejection handling)
- Mobile API for signup/login/application/track
- Flutter app (BLoC) for assignment flows

## Core Features

### 1. Odoo Workflow
- Stage flow: `new -> stage1_review -> stage1_approved -> stage2_review -> approved/rejected`
- Reject action restricted to review stages only (`stage1_review`, `stage2_review`)
- Rejections capture category + reason
- Rejected applicants can reapply (duplicates blocked only for active non-rejected applications)

### 2. Mobile API
- `POST /api/mobile/signup`
- `POST /api/mobile/login`
- `GET /api/mobile/metadata`
- `POST /api/mobile/application/submit`
- `GET /api/mobile/application/track?reference=<tracking_number>`

Tracking response includes:
- status timeline
- `decision_reason`
- `next_step_recommendation`

### 3. Flutter App (Assignment flows)
- `features/auth`: signup/login/session restore
- `features/application`: 4-step wizard (Account → Personal Info → Documents → Review)
- `features/tracking`: status timeline + decision feedback + next-step guidance

---

## Prerequisites

- Python 3.10+ (3.12 used in this project)
- PostgreSQL
- Odoo 19+ source
- Flutter SDK 3.41+ (Dart 3.11+)
- Chrome/Brave for Flutter web testing

---

## Download / Clone

Place this module under Odoo custom addons:

1. `git clone <your-repo-url>`
2. Ensure module path exists:
   `.../odoo-19.0/custom_addons/national_id_application`

---

## Odoo Installation

From Odoo root:

1. Create/activate virtualenv and install requirements.
2. Run Odoo with custom addons:
   `./venv/bin/python odoo-bin -d 'Odoo-db name' --addons-path=addons,custom_addons --http-port=8067`
3. In Odoo UI:
   - Apps → Update Apps List
   - Install **National ID Application**

For module updates after code changes:

`./venv/bin/python odoo-bin -d 'Odoo-db name' --addons-path=addons,custom_addons -u national_id_application`

---

## Flutter Installation and Run

From `custom_addons/national_id_application/flutter_app`:

1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. Run web app:
   `flutter run -d web-server --web-port=5000 --dart-define=API_BASE_URL=http://127.0.0.1:8067`

Open: `http://127.0.0.1:5000`

To build distributable web assets:

`flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:8067`

---

## API Smoke Checks

Examples:

1. Metadata:
   `curl 'http://127.0.0.1:8067/api/mobile/metadata?db=Odoo-Project'`
2. Track:
   `curl 'http://127.0.0.1:8067/api/mobile/application/track?db=Odoo-Project&reference=NID/2026/0001'`

---

## License

LGPL-3
