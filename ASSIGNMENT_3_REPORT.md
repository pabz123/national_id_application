# National ID Application – Internship Assignment 3 Report

**Intern:** Precious Mulungi Pabire  
**Reviewer support:** Codex technical review assistant  
**Date:** April 24, 2026  
**Timeline requested:** 1 week

---

## 1) Executive Summary

This submission now covers:

- Flutter app requirements (authentication, application form, tracking, and BLoC state management).
- Odoo backend workflow with **multi-stage approvals**.
- A strengthened security model based on:
  - **Groups/Roles**
  - **Access Rights** (`ir.model.access.csv`)
  - **Record Rules** (`ir.rule` domains)

I also reviewed the assignment against the stated acceptance criteria and included challenges and improvement recommendations.

---

## 2) GitHub Repository

> **Repository URL:** _Not configured in this local environment (`git remote -v` returned no remotes)._  
> Replace this line with your public/private GitHub link before submission.

Suggested format:

- `https://github.com/<username>/national_id_application`

---

## 3) Requirement-by-Requirement Review

## Part 1: Authentication

### ✅ Implemented
- Signup and login flows are implemented via `AuthBloc` events and state transitions.
- Proper success/failure handling is implemented with user-facing error messages from exceptions.
- Session restoration is implemented on app start.

### Evidence (code)
- Auth events/states and signup/login/logout flows: `flutter_app/lib/features/auth/bloc/auth_bloc.dart`
- Session persistence layer and repository wiring: `flutter_app/lib/features/auth/data/`

---

## Part 2: Application Form

### ✅ Implemented
- Form captures assignment-required fields (8–12+) including:
  - full name, DOB, gender, district, phone, next of kin details, etc.
- File upload implemented for:
  - passport photo
  - LC letter (supports image/pdf/doc/docx from picker)
- Field-level validation includes:
  - email format
  - phone formatting/length
  - DOB validity and age range
  - required fields before submit
- Tracking/reference returned after submission through the submission BLoC result.

### Evidence (code)
- Multi-step form, validations, upload flow: `flutter_app/lib/features/application/presentation/application_form_screen.dart`
- Submit state machine: `flutter_app/lib/features/application/bloc/application_submission_bloc.dart`
- API submit contract: `flutter_app/lib/features/application/data/application_repository.dart`

---

## Part 3: Application Tracking

### ✅ Implemented
- Tracking screen accepts tracking number and fetches status.
- Timeline/status rendering is implemented.
- Backend workflow states map to assignment stages (pending/review/approval/rejected progression).

### Evidence (code)
- Tracking UI and status cards: `flutter_app/lib/features/tracking/presentation/tracking_screen.dart`
- Tracking bloc/repository: `flutter_app/lib/features/tracking/`

---

## Part 4: State Management (BLoC)

### ✅ Implemented
- BLoC used across core domains:
  - authentication
  - application submission
  - tracking
- Explicit loading/success/failure statuses used consistently.
- Layering is separated into:
  - presentation/UI
  - bloc
  - data/repository

### Evidence (code)
- Auth BLoC: `features/auth/bloc`
- Application BLoC: `features/application/bloc`
- Tracking BLoC: `features/tracking/bloc`

---

## 4) Security & Approval Controls Implemented (Assignment 3 focus)

To address your latest request, security was refined in Odoo using the proper model:

### 4.1 Groups (Role Design)

Created/organized roles under module category **National ID**:

- Officer
- Approver (base)
- Stage 1 Approver
- Stage 2 Approver
- Admin

This supports **multi-stage approvals** by assigning users to stage-specific approver groups.

### 4.2 Access Rights (`ir.model.access.csv`)

Model-level CRUD permissions are configured by group for:

- `national.id.application`
- `national.id.district`
- approval/rejection wizard models
- mobile user model (admin)

### 4.3 Record Rules (`ir.rule`)

State-aware record rules enforce what each role can see/edit:

- Officers: can work on new/rejected lifecycle responsibilities.
- Stage 1 approvers: limited to Stage 1 and allowed downstream visibility.
- Stage 2 approvers: limited to Stage 2/final decision states.
- Admin: unrestricted full access.
- Additional rules added for district readability and mobile-user admin management.

This ensures stage separation is controlled by both action methods and security policy.

---

## 5) Key Challenges Faced

1. **Cross-layer consistency** (Flutter status names vs backend workflow states).  
2. **Validation depth** while keeping UX smooth in a multi-step form.  
3. **Duplicate application prevention** while still allowing re-apply after rejection.  
4. **Role design complexity** in multi-stage approvals (group inheritance + record-rule domains).  
5. **Keeping actions secure** by combining UI button groups, backend group checks, and record rules.

---

## 6) Recommendations for Final Submission Polish

1. Add a short demo video (2–4 minutes): signup → submit → track.
2. Include 4–6 screenshots in a dedicated `/docs/screenshots` section.
3. Add a `TESTING.md` with exact commands run and outputs.
4. Add seed users in Odoo docs:
   - officer user
   - stage 1 approver user
   - stage 2 approver user
   - admin user
5. Include a one-page architecture diagram (Flutter + Odoo + API endpoints).

---

## 7) Suggested Screenshot Captions for Your Report

- Login/Signup screen with validation.
- Application wizard step showing personal details and DOB picker.
- Document upload step showing photo + LC letter.
- Submission success with tracking number.
- Tracking screen with status timeline.
- Odoo backend application form in Stage 1/Stage 2 review.

---

## 8) Conclusion

The solution is in good shape for internship evaluation: required Flutter features are present, BLoC architecture is in place, and backend role-based multi-stage approvals are now clearly implemented with proper group/access/rule controls.

