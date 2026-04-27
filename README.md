# National ID Application (Odoo 19 + Flutter)

**Status**: ✨ Production Ready ✨  
**Last Updated**: April 24, 2026

Production-style National ID workflow with:
- Odoo approval pipeline (Stage 1 + Stage 2 + rejection handling)
- Mobile API for signup/login/application/track
- Flutter app (BLoC) for assignment flows with enhanced form UX
- Professional UI with unified header system and Material 3 design
- Responsive design optimized for mobile, tablet, and desktop
- **NEW**: Typeable fields (Autocomplete), calendar date picker, one-application-per-user enforcement

## Core Features

### 1. Odoo Workflow
- Stage flow: `new -> stage1_review -> stage1_approved -> stage2_review -> approved/rejected`
- Reject action restricted to review stages only (`stage1_review`, `stage2_review`)
- Rejections capture category + reason
- Rejected applicants can reapply (duplicates blocked only for active non-rejected applications)
- **NEW**: One application per user constraint - prevents duplicate submissions unless rejected

### 2. Mobile API
- `POST /api/mobile/signup`
- `POST /api/mobile/login`
- `GET /api/mobile/metadata` (countries + districts list)
- `POST /api/mobile/application/submit` (with one-app guard, returns 409 if duplicate)
- `GET /api/mobile/application/track/<reference>` (with decision feedback)
- **NEW**: `GET /api/mobile/application/status` (check if user has active application)

Tracking response includes:
- status timeline
- `decision_reason`
- `next_step_recommendation`

### 3. Flutter App (Enhanced with UX improvements)
- `features/auth`: signup/login/session restore
- `features/application`: 4-step wizard (Account → Personal Info → Documents → Review)
  - **NEW**: Nationality field uses Autocomplete (searchable)
  - **NEW**: District field uses Autocomplete (filtered by country)
  - **NEW**: Date of Birth uses calendar picker (validates age ≤120 years)
  - **NEW**: Full Name enforces letters-only validation (no digits)
  - **NEW**: Next of Kin fields (name + phone, required)
- `features/tracking`: status timeline + decision feedback + next-step guidance


### 5. Security Model (Groups, Access Rights, Record Rules)
- Groups: Officer, Approver (base), Stage 1 Approver, Stage 2 Approver, Admin
- Access rights are defined in `security/ir.model.access.csv` per model/group
- Record rules in `security/national_id_security.xml` enforce stage-based visibility/write access
- Multi-stage approvals are role-separated:
  - Stage 1 approvers operate Stage 1 transitions
  - Stage 2 approvers operate final approval transitions
  - Admin has full supervisory access

---

### 4. Form Fields (12 Total)
1. Full Name (letters-only)
2. Email
3. Phone
4. Existing NIN (optional)
5. Date of Birth (calendar picker)
6. Gender
7. Nationality (searchable Autocomplete) ✨ NEW
8. District (searchable Autocomplete) ✨ NEW
9. Next of Kin Name (letters-only) ✨ NEW
10. Next of Kin Phone (10+ digits) ✨ NEW
11. Photo (upload)
12. LC Letter (upload)

---

## Automated Development Setup

**Fast track**: From the project root, simply run:

```bash
# First time (fresh database)
bash START_DEVELOPMENT.sh --init-db

# Subsequent runs
bash START_DEVELOPMENT.sh

# After code changes
bash START_DEVELOPMENT.sh --install

# Custom settings
bash START_DEVELOPMENT.sh --db mydb --odoo-port 8888 --flutter-port 5001
```

This script automatically:
- **Auto-detects** Odoo, Flutter, and Python paths (works on any machine)
- Activates Python venv
- Installs dependencies (passlib, psycopg2-binary, python-dateutil)
- Creates database (if `--init-db`)
- Installs/upgrades module
- Starts Odoo on port 8067
- Builds Flutter web app
- Serves Flutter on port 5000
- Performs health checks and validates services are responding

**NEW**: Portable script works on any machine without manual configuration!

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
3. User Status (check if has active application):
   `curl -H 'Authorization: Bearer <token>' 'http://127.0.0.1:8067/api/mobile/application/status?db=Odoo-Project'`



## License

LGPL-3
