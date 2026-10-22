# Proposed Flutter + Supabase architecture

This is a design for approval, not an implemented system. Preserve maestro-mobile as the app location to avoid a disruptive move. Keep all Java modules and original SQLite/legacy data during migration. The target has no permanently running Spring Boot API or review worker.

## Client structure

Evolve maestro-mobile/lib in place:

    lib/
      core/config, routing, theme, errors, services
      features/authentication, teachers, students, calendar, lessons,
               projects, pieces, payments, notes, reviews
      main.dart

Add parents, media, and chat feature folders when those features are implemented; do not create empty product flows. Each feature can grow presentation, application, domain, and data directories as needed. Keep existing widgets, screen layout, five-section navigation, and models initially. Introduce repository interfaces at the current MaestroApi boundary, backed first by the existing REST adapter and then by Supabase adapters. Existing StatefulWidget/FutureBuilder/callback state is sufficient for the initial migration; introduce a new state package only if cross-screen state and tests show a concrete need. Store authenticated session in the Supabase client, and keep selection/navigation state separately from authorization state. Use responsive constraints for desktop/web while retaining mobile layouts.

## Server boundary and data model

Supabase Auth provides identities and session persistence. PostgreSQL is authoritative for relationships, schedules, notes, and financial data. Client reads and simple authorized edits use Supabase APIs under RLS. Transactional operations use tightly scoped PostgreSQL RPCs; Edge Functions handle external integrations, email, and operations requiring secrets. Realtime sends change notifications to authorized clients. Private Storage holds future media. Neither role claims in Flutter nor client-side filtering authorize a read or write.

Proposed initial tables, subject to migration fixtures and policy tests:

| Table | Purpose and important keys |
| --- | --- |
| profiles | id references auth.users; role/lifecycle and display metadata |
| teachers | uuid id, optional unique profile_id; existing teacher fields/defaults |
| students | uuid id, optional unique profile_id; existing student fields, recurring schedule defaults, legacy credit/counter fields during parity |
| teacher_students | teacher_id + student_id, relationship status and dates; supports multiple teachers |
| parent_students | parent profile_id + student_id, guardian rights/consent; supports multiple guardians |
| projects | uuid id, student_id, legacy key, name/order/paid count |
| lessons | uuid id, student_id, project_id, responsible teacher_id, date/time, duration, price, status, assignment/comment/homework/order |
| pieces | uuid id, project_id, title/order |
| lesson_notes | uuid id, source lesson_id, student_id, piece text/comment, review schedule and history |
| payments | uuid id, student_id, responsible teacher_id, signed amount, currency, date, method/note, correction relationship and audit fields |

Use a legacy_source + legacy_id mapping (or dedicated unique legacy columns scoped by source) for every imported entity. Existing project/course IDs are unique only within a student, so preserve those composite identities in the mapping. Use numeric(12,2) for money and explicit currency; reject silent binary-float drift. Keep legacy date/time semantics while selecting a teacher timezone for future timestamp-based events. Add FKs, check constraints for enum values and money validity, created_at/updated_at, relationship indexes, and query indexes such as lessons(teacher_id, date), payments(student_id, date), and notes(review_status, review_date). Deletion policy must protect financial/audit records; the current cascading delete behavior requires a reviewed product decision before SaaS cutover.

Do not create an attendance table initially: the current model stores status on a lesson. Do not create payment_allocations merely to satisfy a hypothetical design. Add them only if the reconciliation milestone shows they are needed to represent partial payments, multiple teachers, corrections, and balance provenance. The first RPC must reproduce the current “payment creates/credits courses” behavior atomically and idempotently, including the initial course, existing unpaid courses, zero price, negative amounts, and rounding. A separate immutable ledger/allocation design may be warranted after parity is proven.

## Access model

Every exposed application table has RLS enabled and tested for SELECT, INSERT, UPDATE, and DELETE. Default deny; grant operations by authenticated identity and active relationship. Teachers see only assigned students and the teacher-owned lessons, notes, and finances that their assignment permits. A student sees their own records. A guardian sees linked children's records within granted scopes; financial visibility needs an explicit guardian permission. An administrator role is provisioned through a controlled backend path, never from self-editable profile fields. A student with multiple teachers is visible to both teachers, but one teacher cannot read another teacher's private notes, payments, profile, or media. RLS helpers must avoid circular policy recursion and validate claims against protected tables. Writes must validate both old and new ownership with USING and WITH CHECK. Privileged RPCs use a fixed search_path, explicit authorization checks, and narrowly granted EXECUTE privileges. Service-role credentials remain server-side.

The current numeric teacher-ID gate will be replaced by an Auth sign-in/linking flow while preserving the user-facing destination and account creation workflow. Import existing teacher records first, then link each to a verified Auth user through an invitation or controlled claim; never infer ownership from a typed ID or unverified matching email. Student and guardian accounts are added when their views are built. Publishable key and project URL are client configuration; secrets are never in Dart defines, assets, logs, or Git.

## Future capabilities and boundaries

- Media: private bucket and media_files metadata only when implementation begins. Store student_id, uploader profile_id, intended recipients/visibility, content type, size, object path, created_at, and retention_at. Teacher/student uploads and guardian reads require active relationships. Enforce MIME allowlist, size limit, upload ownership, and object-path rules in Storage policies and/or a signed-upload Edge Function. Use authenticated reads or short-lived signed URLs. Initially budget for 30–60 second clips without processing. Put Storage behind a Flutter MediaRepository so S3 can replace the backend later.
- Chat: future conversations, participants, messages, and read markers keyed to verified teacher/student/guardian links. Membership drives RLS and Realtime subscriptions; membership changes revoke access. Do not add tables or UI until messaging is scoped.
- Calendar integrations: provider connection and sync-state tables, per-user OAuth with PKCE where applicable, encrypted refresh tokens in a backend-only store, outbound Edge Functions and inbound webhook verification. Google/Microsoft client secrets never enter Flutter.
- Email/review reminders: scheduled database job or scheduled Edge Function checks due reviews with idempotent delivery records and per-user preferences; replace the current log-only poller only when notifications are ready.
- Subscription billing: provider webhooks to Edge Functions, verified signatures, tenant/entitlement data, and server-enforced access. No client-authoritative billing state.

## Local and deployment path

On Windows/WSL2, install Docker Desktop with WSL integration, Flutter SDK, and Supabase CLI. Run CLI and Flutter from the WSL repository path; follow the official [local workflow](https://supabase.com/docs/guides/local-development/cli-workflows). After the implementation milestone creates supabase/config.toml and migrations:

    supabase start
    supabase status
    supabase migration new <name>
    supabase db reset --local
    supabase stop

Local Flutter uses Supabase URL and public publishable key from the local CLI status output, supplied through untracked configuration or Dart defines. Android emulator requires a host bridge address; browser and desktop can use localhost subject to platform networking. Hosted builds use environment-specific project URL and publishable key. Tests should use isolated local Auth users and resettable data. Do not run linked remote resets or import real data into seed files. Deploy to a separately approved project with reviewed migrations (supabase db push) and functions (supabase functions deploy <name>), after verifying the linked project and backing up data. The CLI can run locally with Docker without a paid Supabase subscription. See [migration workflow](https://supabase.com/docs/guides/local-development/cli-workflows), [RLS guidance](https://supabase.com/docs/guides/database/secure-data), and [Storage access control](https://supabase.com/docs/guides/storage/security/access-control).
