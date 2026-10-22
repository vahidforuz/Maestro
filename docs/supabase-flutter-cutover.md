# Flutter Supabase cutover status

Updated 2026-10-22. Flutter no longer calls Spring Boot or SQLite. The Java modules remain for legacy desktop use and data migration. No Cloud project was linked or changed.

## Active data path

`lib/main.dart` requires `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, initializes `supabase_flutter`, and injects `SupabaseMaestroDataSource` and `SupabaseTeacherAuth`. Missing defines display a configuration message. There is no `localhost:8080` fallback. The old Flutter REST adapter and its direct `http` dependency were removed. The local config generator writes only the public Supabase URL and key.

Supabase Auth email/password replaces numeric teacher-ID selection. The signed-in user loads only their own teacher row under RLS. A new Auth user without a teacher row sees profile onboarding using `register_teacher_with_contact`, which retains the form's separate contact email and calls the guarded `register_teacher` function. Sign-out calls Supabase Auth and the app restores a persisted session. Student and parent accounts cannot register as teachers through the registration functions.

The repository maps PostgreSQL `app_id` and snake_case columns into the existing Flutter models. The dashboard, students, profile, calendar, payments, and settings screens still use `MaestroDataSource`, now backed by Supabase. Private financial columns are read through checked RPCs.

## Current Flutter workflows

| Workflow | Supabase path |
|---|---|
| Teacher sign-in, restoration, onboarding, settings, sign-out | Auth; `teachers` self RLS; `register_teacher_with_contact` |
| Student listing, profile, dashboard, calendar | RLS reads of students, projects, lessons, pieces, notes plus finance RPCs |
| New student and first project/lesson | `maestro_create_student` transaction |
| Project and piece create/edit/delete | `maestro_student_command` |
| Lesson create/edit/delete, attendance, scheduling | `maestro_student_command` |
| Note create/edit/delete, review accept/reschedule | `maestro_student_command` |
| Payment and automatic lesson allocation | `maestro_record_payment` transaction with request key |
| Payments list and student history | Teacher-scoped `payments` SELECT RLS |

The migrations `20261022135000_flutter_workflow_writes.sql`, `20261022140000_teacher_owned_review_updates.sql`, `20261022141000_payment_retry_guard.sql`, `20261022142000_teacher_update_columns.sql`, and `20261022143000_teacher_contact_registration.sql` add and refine the write functions, grants, and contact email registration. Direct client writes to student and finance tables remain denied by RLS. Shared-student note changes are scoped to their teacher, payment-created lessons resolve pending reviews, and payment request keys cannot be reused for a different amount. The teacher grant migration revokes Supabase's broad default teacher UPDATE grant, leaving only Settings form columns editable. Private Storage and Realtime are backend-only; Flutter has no media or subscription UI. No Edge Functions exist or are required for these database-only workflows.

## Verified locally

- `flutter analyze`: no issues.
- `flutter test --dart-define-from-file=.local.flutter.web.json`: six tests pass, including live read-only integration for Ada and Ben's separate teacher/student/payment rows, signed-out login, non-teacher blocking, navigation, and balance calculation.
- `npx --yes supabase test db --local`: 45 assertions pass in rollback transactions. They cover teacher onboarding and contact email, identity-column grants, student, project, piece, lesson, attendance, note, review, payment, teacher settings, and shared-student isolation operations.
- `npx --yes supabase db lint --local`: no schema errors.
- `python3 supabase/tests/local_access_smoke.py`: local Auth, RLS, finance, role, and private Storage isolation checks pass.
- `flutter test --platform chrome --dart-define-from-file=.local.flutter.web.json`: six tests pass in headless Chrome, including local Supabase teacher reads.
- `flutter build web --dart-define-from-file=.local.flutter.web.json`: passed. A full interactive Chrome session and Windows runtime were not automated.

No database reset was performed. Only pending forward migrations were applied to the existing local database. The SQLite files were untouched.

## Remaining migration work

1. **Legacy data import:** the three SQLite copies differ. No canonical source was selected or imported; current local accounts/data are synthetic. `scripts/inventory_sqlite.py` is the read-only first step.
2. **Shared-student finances:** project `paid_course_count` is shared while payments and lessons are teacher-owned. The RPC preserves the existing one-teacher allocation rule, but credit and allocations between two teachers need a product decision and likely a ledger/schema change before production use.
3. **Financial reconciliation:** Flutter's displayed balance (payments minus PRESENT/ABSENT lesson prices) differs from stored credit and paid count, as in the old app. Define refunds/corrections and retention.
4. **Additional parity:** student edit/delete, review dismissal, teacher photo/media upload, parent/student app views, and delivered reminders remain absent. Storage and Realtime have no Flutter UI yet.
5. **Release checks:** `fetchStudents` loads each profile graph separately and needs pagination/optimization for large schools. Windows/Android/iOS/macOS/Linux runtime tests remain. macOS and Linux runners are absent. Production Auth signup, email confirmation, SMTP, redirects, and teacher enrollment need review.

## Run locally

From the repository root:

```bash
npx --yes supabase start
npx --yes supabase migration up --local
python3 scripts/write_local_flutter_config.py
```

From `maestro-mobile/`:

```bash
flutter pub get
flutter run -d chrome --web-port=7357 --dart-define-from-file=.local.flutter.web.json
```

Windows PowerShell with Windows Flutter and Visual Studio C++ tools, while the same local Supabase stack is reachable:

```powershell
cd path\to\Maestro\maestro-mobile
flutter pub get
flutter run -d windows --dart-define-from-file=.local.flutter.windows.json
```

See [local development](local-development.md) for account and networking details. Do not start Spring Boot for Flutter or reset the local database.
