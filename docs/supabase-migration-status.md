# Maestro Supabase migration status

Updated 2026-10-22. **Cloud deployment ready: NO.** This report describes the code currently wired into Flutter and the local verification performed. No Supabase Cloud project was linked or changed; no SQLite data was modified or imported.

## Current architecture

`maestro-mobile/lib/main.dart` requires `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, initializes Supabase, and injects `SupabaseMaestroDataSource` and `SupabaseTeacherAuth` into the existing Flutter screens. No active Flutter code calls Spring Boot, `localhost:8080`, or `/api/`. A missing configuration shows a setup message. A signed-out user sees email/password sign-in; a new eligible account sees teacher profile onboarding. Sessions persist through Supabase Auth. The app uses only the public publishable key.

Versioned SQL under `supabase/migrations/` defines PostgreSQL business tables, relationships, constraints, RLS, checked finance reads, teacher registration, teacher-scoped workflow writes, transactional payment/lesson allocation, a private Storage bucket, and Realtime publication for lessons and notes. The current Flutter app uses database tables and RPCs; it has no Storage upload UI, Realtime subscriptions, or Edge Functions. The legacy JavaFX desktop, Spring Boot API, review worker, Java domain services, and three SQLite databases remain in the repository for legacy use and migration reference. Flutter no longer depends on them.

## Feature status

`Complete` describes the implemented local Flutter-to-Supabase workflow, not a production release claim. `Partial` means a usable part exists with known gaps. `Untested` means implementation exists but lacks relevant execution evidence.

| Component | Status | Remaining work | Priority |
|---|---|---|---|
| Flutter UI | Partial | Existing dashboard, students, profile, calendar, payments, and settings screens use Supabase; verify full interactive flows and all six target platforms. macOS/Linux runners are absent. | P1 |
| Authentication | Partial | Auth sign-in/up/out, session restore, teacher onboarding and role guard work locally; decide production enrollment, confirmation, SMTP, redirects, and legacy identity linking. | P1 |
| PostgreSQL | Partial | Ten local migrations are applied; replay on a disposable clean stack, reconcile legacy data and financial semantics, then validate on staging. | P1 |
| Student management | Partial | List/profile/create and first project/lesson use Supabase; student edit/delete and legacy data import remain. | P1 |
| Lessons | Partial | Create/edit/delete, attendance, notes, and review scheduling use teacher-scoped RPCs; parity and interactive regression coverage remain. | P1 |
| Calendar | Partial | Existing calendar reads Supabase lessons; verify interactive refresh and larger data sets. | P2 |
| Payments | Partial | Teacher-scoped reads and transactional, retry-guarded payment/allocation RPC work locally; resolve shared-student ownership, credit/refund/correction rules and reconciliation. | P1 |
| Reviews | Partial | Note create/edit/delete and accept/reschedule work; review dismissal and delivered reminders are absent. | P2 |
| Storage | Partial | Private bucket and access policies pass local checks; Flutter media upload/view and retention flow are absent. | P2 |
| Realtime | Partial | Lessons and notes are published; Flutter has no subscriptions or refresh handling. | P3 |
| Deployment configuration | Partial | CLI project, migrations, public Dart defines, local config generator and commands exist; Cloud staging, backups/restore rehearsal, import, platform verification and release settings remain. | P1 |

Additional Flutter capabilities preserved include teacher settings, student balances and payment history, projects and pieces, lesson notes, and the existing navigation. Parent/student app views are not implemented. The old review worker polls/logs but does not deliver reminders. No Edge Function is required for the current database-only operations; future secret-bearing integrations would need a server-side design.

## Security and business rules

Teacher and student visibility is enforced by RLS and checked RPCs. The numeric teacher-ID selector was removed. Direct writes to student and finance tables are denied; write RPCs validate the authenticated teacher and perform multi-row work in database transactions. The payment RPC uses a request key and rejects reuse with a different amount. Teacher Settings can update only allowed columns; identity columns are not client-editable. Tests cover separate Ada and Ben teacher accounts, shared-student note ownership, student/parent role denial, private Storage isolation, and payment behavior.

There is a material finance decision before production: project paid-course count is shared for a student associated with two teachers, while payments and lessons are teacher-owned. The current RPC preserves the one-teacher legacy allocation rule, but shared-student credit and allocation need an explicit ownership model. Flutter's displayed balance differs from stored payment credit, as in the legacy app. Refunds, corrections, and ledger reconciliation need a defined policy. Do not deploy finance workflows with shared students until these rules are settled and tested.

The three SQLite candidates contain different data. The read-only `scripts/inventory_sqlite.py` inventories them; no source has been chosen and there is no importer yet. A repeatable importer must record source fingerprints and ID mappings, validate row counts, references, identities and money, and rehearse rollback in an isolated database. It must never overwrite a source SQLite file.

## Local verification

- `flutter analyze`: PASS, no issues.
- `flutter test --dart-define-from-file=.local.flutter.web.json`: PASS, six tests, including live read-only local Supabase access for two teacher accounts.
- `npx --yes supabase test db --local`: PASS, 45 rollback-transaction assertions across schema, registration, grants, teacher isolation, student/project/piece/lesson/note/review writes, and payment allocation.
- `npx --yes supabase migration list --local`: PASS, all ten migrations match local history.
- `npx --yes supabase db lint --local`: PASS, no schema errors.
- `python3 supabase/tests/local_access_smoke.py`: PASS, local Auth, RLS, finance, roles and private Storage access.
- `flutter test --platform chrome --dart-define-from-file=.local.flutter.web.json`: PASS, six headless Chrome tests.
- `flutter build web --dart-define-from-file=.local.flutter.web.json`: PASS.

These checks do not replace a full interactive browser session, Windows runtime test, mobile/native runtime tests, or clean-database migration replay. The existing local database was not reset. Only pending forward migrations were applied; the pgTAP workflow tests roll back their changes.

## Remaining work in priority order and effort

1. Decide the canonical SQLite source, teacher ownership for shared students, payment/credit/refund semantics, retention, and production teacher enrollment; estimate 1–2 engineer-weeks plus product review.
2. Build and rehearse a repeatable SQLite import with identity and financial reconciliation on an isolated database; estimate 2–4 engineer-weeks after decisions.
3. Finish missing parity: student edit/delete, review dismissal, media UI, parent/student views, delivered reminders where required; estimate 3–6 engineer-weeks depending on scope.
4. Validate complete workflows interactively, improve profile graph loading for larger schools, and test target platforms; estimate 2–4 engineer-weeks. Windows needs Windows Flutter and Visual Studio C++ tools; macOS/Linux runners need to be generated in the existing app and tested on supported hosts.
5. Rehearse clean migration replay, staging Auth/RLS/Storage/finance tests, backups and restore, then production release; estimate 1–3 engineer-weeks after the above.

These are planning ranges, not a commitment. The Flutter cutover itself is implemented; the main blockers are legacy-data reconciliation, financial rules, parity, platform verification and release validation.

## Future Supabase Cloud deployment (not executed)

1. Agree on the ownership, finance, Auth enrollment, and import decisions. Preserve SQLite originals and fingerprints. Rehearse all migrations and import on a disposable local database; do not reset the current data-bearing local stack.
2. Create separate staging and production Supabase projects after approval. Match PostgreSQL versions. Keep project refs, CLI access token and database passwords outside Git. Create separate ignored Dart-define files with only each project's `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. Configure each project's Auth redirects, confirmation, SMTP and signup policy.
3. Back up the target database before each schema/data change and rehearse restore to a separate project. Back up Storage object bytes separately; database backups contain Storage metadata, not object bytes. Record migration versions and recovery points.
4. Link staging explicitly with `npx --yes supabase link --project-ref <staging-ref>`. Inspect `npx --yes supabase migration list` and `npx --yes supabase db push --dry-run`, review SQL and policy effects, then push only after approval. Never use `--include-seed`: `supabase/seed.sql` contains local demo users. Never reset a linked data-bearing project.
5. Run staging Auth/RLS, Storage, payment, shared-student and imported-data checks with staging test users. Build and test Flutter Web and supported native targets with staging public defines. No Edge Functions exist to deploy.
6. Repeat backup, migration review, approved push, smoke checks and production build for production after staging passes. Keep private keys and database passwords out of Flutter builds.

## Direct answers

1. **Is Maestro currently using Supabase correctly?** For its implemented Flutter workflows, **yes locally**: the app now uses Auth, RLS-backed tables and guarded RPCs, with only the public key. Production correctness still depends on the finance and import decisions.
2. **Which Flutter features still depend on the old backend?** None of the active Flutter feature data paths. The retained JavaFX/Spring/SQLite modules and review worker are separate legacy components.
3. **Can the complete application run locally?** The current Flutter teacher app can run against local Supabase without Spring Boot. A full interactive run and all target platforms remain unverified; absent features and legacy data are not magically present.
4. **Is the database ready for Supabase Cloud?** The schema is versioned and works locally, but **not yet production-ready** because import, finance semantics, clean replay and staging checks remain.
5. **What remains before deployment?** Complete the priority work above and the staged deployment procedure.
6. **Is Maestro ready for deployment? NO.**

See [Flutter cutover status](supabase-flutter-cutover.md) and [local development](local-development.md) for implementation detail and exact run commands.
