# Incremental migration plan

> Historical plan from before the Flutter Supabase cutover. See [current cutover status](../supabase-flutter-cutover.md) for implemented work and remaining tasks.

Status: approved to begin implementation on 2026-10-22. M0 regression work and M1 local Supabase setup have started. The current Java/SQLite applications and the existing Flutter UI remain intact until each replacement passes its gate. All work stays on the existing dedicated version2_supabase branch unless the user chooses another migration branch. No production system is in scope without explicit authorization.

## Delivery principles

1. Capture current mobile behavior with tests before changing its data source. Preserve the current five-section navigation, responsive breakpoints, screens, forms, and current working behavior.
2. Make one feature's data adapter and server rules at a time. Keep the REST adapter available during local parity verification; retire the Spring API only after every current Flutter operation has a verified Supabase path.
3. Use migration SQL under supabase/migrations; keep the original databases and legacy files read-only. Import into a fresh local database first. Never seed real student/payment data into the repository.
4. Enforce data access in RLS/Storage policies and transactional invariants in PostgreSQL RPCs or Edge Functions. Flutter display calculations may remain for UI convenience but cannot authorize or settle money.
5. Keep each milestone buildable: flutter analyze, meaningful Flutter tests, SQL migration/policy tests, and manual flows on platforms available at that milestone. Do not claim iOS/macOS or hardware coverage from Linux tooling.

## Milestones and estimates

Effort is engineering time for one experienced Flutter/Supabase engineer, excluding stakeholder wait time and unknown data cleanup. Ranges assume the current codebase and a local test Supabase project; they are not calendar deadlines. Milestones can overlap after the baseline gate. The initial teacher-facing migration totals roughly **18–27 engineer-weeks**; media and chat are separate future scopes.

| Milestone | Estimate | Concrete deliverable and exit gate |
| --- | ---: | --- |
| M0. Baseline and regression harness | 1–2 weeks | Fake REST repositories and Flutter widget/domain tests for every current screen path, forms, course/project/piece/note/payment behavior; record current bugs. Existing Flutter test currently covers only test harness startup. No source swap yet. |
| M1. Local Supabase foundation and schema | 2–3 weeks | WSL2/Docker/CLI setup, config.toml, versioned base migrations, constraints/indexes, test users/fixtures, RLS default deny, policy test harness, CI-safe local reset instructions. Schema replays cleanly locally. |
| M2. Auth and relationship permissions | 2–3 weeks | Supabase Auth for teachers, profile linking/invites, session restoration/sign-out, teacher_students and parent_students, two-teacher/guardian permission tests, no numeric-ID impersonation. Existing gate destination and account workflow remain usable. |
| M3. Read-only SQLite import and reconciliation | 2–3 weeks | Deterministic importer, legacy ID map, dry-run report, source fingerprint, row/relationship/financial checksums, duplicate/collision report, local restore rehearsal. The import is idempotent and never modifies originals. |
| M4. Teacher/student data adapter | 1–2 weeks | Teacher settings and student list/create/view/edit/delete through repository abstraction and RLS; existing mobile list/profile UI intact, with compatible missing edit/delete added. Compare REST and Supabase fixtures. |
| M5. Projects, pieces, lessons, calendar | 3–4 weeks | Nested graph repositories, server-side first project/course and weekly scheduling rules, all statuses, course/project/piece CRUD, calendar parity at phone and wide widths, student lesson history. Regression suite passes. |
| M6. Payments and balance reconciliation | 3–4 weeks | Atomic, idempotent payment RPC, decimal money, audit/correction model and approved refund semantics, existing course-generation rule, tenant ownership, balance view, financial RLS and concurrency tests. Reconciled totals match approved source. |
| M7. Notes and reviews | 2–3 weeks | Note CRUD, target resolution, due ordering, accept/keep/dismiss parity, history/date-change behavior, RLS, reminder design. Replace log-only worker only if actual notifications are in scope. |
| M8. Platform hardening and API cutover | 2–3 weeks | Generate Windows/macOS/Linux projects where toolchains permit; keyboard/mouse/window-resize, file/auth persistence, browser navigation, build and deployment instructions; remove runtime dependence on Spring after complete parity. Keep Java modules and SQLite sources in repository. |
| F1. Private media sharing | 2–3 weeks, later | Repository abstraction, private Storage bucket, metadata, guardian/teacher/student access tests, type/size/retention limits, 30–60 second clips, platform pickers. |
| F2. Chat and external integrations | 3–5 weeks per integration family, later | Authorized conversation schema/Realtime; or Google/Outlook OAuth sync; or email; or billing. Scope and estimate separately before implementation. |

The sequence is a gate, not a requirement to complete all future features in the first cutover. M8 is blocked until current mobile CRUD, scheduling, payments, and review flows pass parity tests. Teacher/student/guardian access tests are required even where student/guardian UI remains future work.

## Data migration procedure

1. Inventory each candidate database read-only using SQLite schema introspection, foreign_key_check, counts, maximum IDs, signed payment sums by student, note review states, and a cryptographic file hash. Include data/music_school.db, maestro-api/data/music_school.db, maestro-desktop/data/music_school.db, and legacy TSV/serialized sources. The three database files have different contents; do not concatenate them blindly.
2. Obtain the canonical source or an approved merge rule. Create a copy/snapshot outside the app's live path. Dry-run the importer against the copy; no in-place SQLite migrations or deletes.
3. Convert old IDs to UUIDs through stable source-scoped mapping rows. Preserve student+project and student+course composite identity, piece/note/payment integer IDs, references, order, and review history. Stage invalid rows for review instead of dropping them. Attach students to teacher_students from old teacher_id; link Auth identities only by a verified process.
4. Convert SQLite REAL monetary values to decimal cents with an explicit reconciliation report; preserve original value and source ID in a restricted migration audit until approved. Compare payment count, signed total by student, current credit, paid course count, charged lessons, and the UI balance calculation. Do not silently replace one balance definition with another.
5. Import in dependency order inside bounded transactions or repeatable batches; record import run ID and checksums. Validate row counts, FKs, orphan references, status values, course dates, and note target/accepted references. Repeat the import into a clean local database to prove idempotence.
6. At cutover, freeze writes to the chosen source for a short window, re-export a fresh snapshot, rerun reconciliation, then switch Flutter repository configuration. Keep an app-level rollback path to the old API until a signed acceptance gate. Production export/import requires separate authorization.

## Required test matrix

| Layer | Scenarios |
| --- | --- |
| Flutter unit/widget | Existing gate/dashboard/nav; student CRUD; project/piece/course/note CRUD; calendar day/week/month and opening lesson; teacher defaults/settings; both payment entry points; loading/error states and narrow/wide widths |
| PostgreSQL function | $100/$20 yields five total courses; existing unpaid courses; partial credit; nonpositive price; negative/refund cases after policy decision; concurrent and repeated requests; rounding; rollback on error |
| RLS | Teacher A versus teacher B, shared student with teacher-private financial/notes scopes, unassigned student, own-student account, two guardians with distinct rights, anonymous user, administrator provisioning |
| Storage | Private bucket listing/read/upload/delete; wrong student path, wrong teacher, revoked guardian, MIME/size limit, expired URL |
| Import | Counts and sums per source, key mapping, orphan detection, note history/reference preservation, restart/retry, original-file hash unchanged |
| Platforms | Web Chrome and Android in WSL-capable environment; Windows on Windows; Linux on Linux; iOS/macOS on a macOS runner. Record actual devices/builds and untested cases. |

Current baseline on 2026-10-22: Flutter analysis passed and three tests passed, including a teacher-to-student-profile workflow and a balance rule. The Maven SQLite module passed nine tests. Docker Desktop integration is active; four local migrations and synthetic seed replay cleanly. Fourteen pgTAP checks and six-account Auth/REST/Storage/finance isolation checks pass. Flutter Web builds with local Supabase public defines, and a Windows runner exists; Windows and Android runtime tests remain unrun. SQLite import and Flutter feature data cutover remain incomplete. Flutter screens depend on `MaestroDataSource`; the REST implementation still provides their data. See [local development](../local-development.md).

## Local setup and release workflow to implement

Keep the existing Java run instructions while migration proceeds. The Supabase Flutter commands below are targets for a later milestone and do not yet run the application:

    # WSL2 with Docker Desktop integration enabled
    supabase start
    supabase status
    supabase migration new <feature_name>
    supabase db reset --local
    supabase stop

    # Flutter from maestro-mobile
    flutter pub get
    flutter analyze
    flutter test
    flutter run -d chrome --dart-define=SUPABASE_URL=<local_url> --dart-define=SUPABASE_PUBLISHABLE_KEY=<local_public_key>
    flutter run -d android --dart-define=SUPABASE_URL=<android_host_bridge_url> --dart-define=SUPABASE_PUBLISHABLE_KEY=<local_public_key>

After toolchain/platform directories are added, verify flutter build web, flutter build apk, flutter build windows/linux/macos, and flutter build ios on their supported hosts. These are future commands, not test results. Local/hosted configurations must contain only project URL and publishable key. Use untracked secret files or backend environment secrets for privileged credentials. For a separately approved hosted project, inspect the linked project, review SQL diff, back up, then run supabase db push and supabase functions deploy <function>. Never run supabase db reset --linked on a data-bearing remote project; the official [CLI workflow](https://supabase.com/docs/guides/local-development/cli-workflows) documents that this destroys remote data.

## Risks and decision gates

| Risk | Evidence | Mitigation / decision needed |
| --- | --- | --- |
| Data source ambiguity | Three SQLite files differ in row counts and likely content; root DB has no schema_migrations rows | Confirm canonical source or merge policy before real import. |
| Access widening | Current API lists all data; Flutter filters locally; teacher ID is selectable | Auth identity linking, deny-by-default RLS, negative policy tests before adapter cutover. |
| Financial drift | Stored credit, paid_course_count, and UI paid-minus-attended balance differ; REAL amounts; refunds are negative payments | Agree on canonical accounting meaning and correction/refund behavior before M6; preserve old values and reconcile. |
| Multi-teacher ownership | SQLite has one nullable teacher_id; proposed design allows several teachers and guardians | Specify which teacher owns a lesson/payment/note and how a shared student is billed. |
| Deletion and audit | SQLite cascades student deletes to payments/notes | Approve retention/soft-delete policy before exposing student delete in SaaS. |
| Review history loss | Review references are partly unenforced integers; student graph is rewritten on save | Preserve source/target/accepted IDs and history, test date changes/deletion and idempotent import. |
| UI regressions | Only a trivial Flutter test exists; several screens are large and stateful | Add screen-level regression tests before repository replacement; adapt widgets rather than rewrite. |
| Platform/toolchain gaps | No Windows/macOS/Linux Flutter projects; iOS has not been built here | Generate projects incrementally, verify on proper hosts, document untested targets. |

Before any irreversible or high-impact action, resolve the relevant decision gate with a concrete proposal and evidence. No production database, deployment, module deletion, or source-data overwrite is part of this plan.
