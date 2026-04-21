# National ID Application (Odoo 19 + Flutter)

Production-style National ID workflow with:
- Odoo approval pipeline (Stage 1 + Stage 2 + rejection handling)
- Mobile API for signup/login/application/track
- Flutter app (BLoC) for assignment flows
- Professional UI with unified header system and Material 3 design
- Responsive design optimized for mobile, tablet, and desktop

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

## Automated Development Setup

**Fast track**: From the project root, simply run:

```bash
bash START_DEVELOPMENT.sh
```

This script automatically:
- Activates Python venv
- Installs dependencies (passlib, psycopg2, etc.)
- Starts Odoo on port 8067
- Builds Flutter web app
- Serves Flutter on port 5000

Then open **http://127.0.0.1:5000** in your browser.

---

## Manual Installation

### Prerequisites

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

### Quick Start

From `custom_addons/national_id_application/flutter_app`:

```bash
flutter pub get
flutter analyze
flutter test
```

### Development (Debug Mode)

```bash
flutter run -d web-server --web-port=5000
```

Open: `http://127.0.0.1:5000`

### Production Build

```bash
flutter build web --release
cd build/web
python3 -m http.server 5000
```

Then open: `http://127.0.0.1:5000`

---

## UI Architecture

### Theme System (`lib/core/theme/`)

The app uses a **centralized, Material 3-compliant theme system** with:

**app_theme.dart**:
- Single `buildAppTheme()` function used in `main.dart`
- Color scheme: Deep forest green (#0C3D28) primary, accent greens, light variants
- Google Fonts integration (DM Sans, DM Serif Display)
- Unified input decoration, button themes, card themes
- Navigation bar theming

**nid_header.dart**:
- `NidHeader`: Reusable green header component (auth & authenticated variants)
  - Auth screens: Just title/subtitle + Uganda branding
  - Authenticated screens: User strip (avatar, name, email, tracking pill, logout button)
  - Decorative circular patterns for visual sophistication
- `NidSectionLabel`: Section header with hairline divider
- `NidInfoBanner`: Error/info alert banner with icon

### Screen Components

**Auth** (`features/auth/presentation/auth_gate_screen.dart`):
- `NidHeader` (auth variant)
- Tabbed login/signup forms
- Form validation with error banners
- Password visibility toggle
- Loading state indicator

**Home** (`features/home/presentation/home_screen.dart`):
- Bottom navigation bar (Apply / Track tabs)
- No Scaffold AppBar (each child renders its own NidHeader)

**Application** (`features/application/presentation/application_form_screen.dart`):
- `NidHeader` (authenticated variant with tracking reference)
- 4-step wizard form
- Organized sections (Account, Personal Info, Documents, Review)
- File upload zones
- Validation feedback

**Tracking** (`features/tracking/presentation/tracking_screen.dart`):
- `NidHeader` (authenticated variant)
- Reference input form
- Status display with color-coded information
- Decision details and next-step recommendations

### Responsive Design

All screens use:
- `ConstrainedBox` for max-width on large screens
- `MediaQuery` for adaptive layouts
- Flexible spacing and padding
- Proper text scaling

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
