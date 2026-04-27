# Odoo.sh Deployment Guide (Mulungi Internship)

This guide gives the exact next steps after creating your staging branch on Odoo.sh.

## 1) Push source code to the invited GitHub repository

Repository: `https://github.com/kola-tech/MulungiInternship`

From your project root:

```bash
git remote add internship https://github.com/kola-tech/MulungiInternship.git
git push internship HEAD:main
```

If `main` is protected, push to your branch instead:

```bash
git push internship HEAD:precious/staging
```

Then create a PR in GitHub if required by the project settings.

## 2) Connect the repo in Odoo.sh

1. Open Odoo.sh project dashboard.
2. Confirm the repository connected is `kola-tech/MulungiInternship`.
3. Confirm your branch exists in Odoo.sh (staging or dev branch).
4. Wait for build to complete.

## 3) Ensure module is installed on staging database

1. Open the staging database from Odoo.sh.
2. Activate developer mode.
3. Apps → Update Apps List.
4. Search for **National ID Application**.
5. Install (or upgrade) the module.

## 4) Verify endpoint is live on `mulungiinternship.odoo.com`

Check in browser (logged-in session may be required depending on route settings):

- `https://mulungiinternship.odoo.com/api/mobile/metadata?db=mulungiinternship`

If this returns metadata JSON, mobile API routing is up.

## 5) Point Flutter app to Odoo.sh database

Use compile-time defines when running/building Flutter:

```bash
flutter run -d android \
  --dart-define=API_BASE_URL=https://mulungiinternship.odoo.com \
  --dart-define=ODOO_DB=mulungiinternship
```

## 6) Generate split-ABI APKs for testing

```bash
cd flutter_app
flutter clean
flutter pub get
flutter build apk --release --split-per-abi \
  --dart-define=API_BASE_URL=https://mulungiinternship.odoo.com \
  --dart-define=ODOO_DB=mulungiinternship
```

Output APKs:

- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

## 7) Recommended smoke test checklist

- Signup from mobile app succeeds.
- Login succeeds and session persists.
- Application submit returns a tracking number.
- Tracking by number shows current workflow state.
- Rejection/approval flow updates are visible in tracking.

## Common challenges

- **403 or auth errors**: verify API route auth mode and bearer token usage.
- **Wrong DB errors**: ensure `ODOO_DB` matches exact database name on Odoo.sh.
- **CORS/network issues on emulator**: prefer real device or use https endpoint.
- **Build failed on Odoo.sh**: inspect build logs and ensure dependencies in manifest are correct.
