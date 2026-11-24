# Maestro Flutter deployment

## Anonymous availability test correction (2026-11-23)

The local run after `20261123170000_explicit_flutter_table_grants.sql`
reported 17 of 19 files passing. Its 55 new grant assertions passed. The two
failures came from old tests that queried `availability_share_links` and
`teacher_time_blocks` as `anon` and expected an empty result. PostgreSQL now
correctly rejects those direct queries with `42501` before RLS can filter rows.
Anonymous users do not need `SELECT` on either table. The public Flutter page
calls only `maestro_shared_availability`, a token-scoped `SECURITY DEFINER` RPC.
The RPC validates a 64-character bearer token against its stored SHA-256 hash,
checks expiry/revocation and date range, and returns free slots plus limited
teacher display metadata. The internal raw RPC is not executable by `anon`.
Neither private block titles/notes nor student names are returned.

`supabase/tests/database/availability_sharing.sql` and
`supabase/tests/database/time_blocks.sql` now assert the intended permission
denial, lack of anonymous grants, and unchanged public slot behavior. The
sharing test revokes its fixture by link ID, matching Flutter's permitted
column-level update. Its expiry test uses an elevated test-only fixture update
inside a transaction that rolls back. **No new database migration is needed**
for these two failures. The 55 assertions in
`explicit_flutter_table_grants.sql` remain unchanged.

Run the full local suite again from the repository root:

```bash
cd /home/vahid/Maestro
npx supabase test db
```

The sandbox cannot access the Docker socket, so all 19 files passing remains
to be confirmed by this command on the user's local machine. The cloud
database was not changed. Once the full suite passes, review the linked
migration list and dry run:

```bash
cd /home/vahid/Maestro
npx supabase migration list --linked
npx supabase db push --dry-run
```

After explicit approval, only if the dry run lists
`20261123170000_explicit_flutter_table_grants.sql` as the sole pending
migration:

```bash
cd /home/vahid/Maestro
npx supabase db push
npx supabase migration list --linked
```

## Cloud sign-in permission repair (2026-11-23)

After sign-in, `PortalShell._restore()` calls
`SupabaseMaestroDataSource.fetchTeachers()`. That method issues
`public.teachers` `SELECT *` filtered by the current Auth user's `user_id`.
PostgreSQL checks the role's table privilege before evaluating the existing
`teachers_self_read` RLS policy. The first 36 migrations create that RLS policy
but never explicitly grant table `SELECT` to `authenticated`. The hosted error
`42501 permission denied for table teachers` confirms the missing effective
grant there. Local success may come from different default table privileges;
the local and cloud ACLs could not be compared from this sandbox.

The following read-only query in each project's SQL editor confirms the
effective role privilege before or after applying the migration:

```sql
select
  has_table_privilege('authenticated', 'public.teachers', 'SELECT')
    as teacher_select,
  has_column_privilege('authenticated', 'public.profiles', 'role', 'SELECT')
    as profile_role_select,
  has_column_privilege('authenticated', 'public.payments', 'amount', 'SELECT')
    as payment_amount_select;
```

The forward-only migration
`supabase/migrations/20261123170000_explicit_flutter_table_grants.sql` adds
explicit grants for Flutter's direct queries. It covers the teacher and profile
role reads, lesson/piece/note and payment reads, teacher calendar CRUD, and
availability-link read/revoke. It also adds column-level permission to update
the teacher timezone already edited by Settings. Existing RLS policies are
unchanged. Student/project financial columns stay outside their existing
read grants; payment reads expose only the columns Flutter needs. Direct writes
to student, project, lesson, piece, note, and payment data remain RPC-only.
The audit found explicit grants already present for student/parent access,
messaging, practice-video tables, and teacher/student relationship reads;
`teacher_piece_progress` and `legacy_id_map` have no direct Flutter access.

The corrective migration has been applied locally. Use the full local test
command and the separate cloud preflight/apply commands above. Neither
command resets or seeds a database.

The new `supabase/tests/database/explicit_flutter_table_grants.sql` contains
55 privilege and RLS assertions for teacher isolation, financial column
restriction, parent finance denial, and direct-write denial. The user ran
these locally and all 55 passed. This sandbox cannot access the Docker socket.
No cloud migration was applied. After the approved push, sign out and back in
to refresh the role page, then repeat teacher, student, and parent staging
checks with dedicated test accounts. Runtime staging permission checks remain
pending until then.

## Environments and launch commands

Flutter initializes `supabase_flutter` in `maestro-mobile/lib/main.dart` from
`SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. `MAESTRO_ENV` selects `local` or
`cloud-staging`. Existing local define files omit `MAESTRO_ENV` and continue to
select `local`. The client accepts only the local API on port 54321 in local
mode, and only the Maestro Supabase HTTPS origin in cloud staging mode. The
cloud staging JSON contains a public publishable key, never a database password
or privileged key.

From `/home/vahid/Maestro`, with the local Docker stack already running:

```bash
python3 scripts/write_local_flutter_config.py
cd maestro-mobile
flutter pub get
flutter run -d chrome --web-port=7357 --dart-define-from-file=.local.flutter.web.json
```

For cloud staging in a separate browser origin:

```bash
cd /home/vahid/Maestro/maestro-mobile
flutter pub get
flutter run -d chrome --web-port=7358 --dart-define-from-file=config/cloud-staging.json
```

The local Android emulator remains available with
`flutter run -d android --dart-define-from-file=.local.flutter.android.json`.
Cloud staging on Android uses
`flutter run -d android --dart-define-from-file=config/cloud-staging.json`.
Windows local development keeps `.local.flutter.windows.json`. These commands
switch the backend at build/launch time; they do not migrate or copy client data.
Use a separate browser profile for each environment if an Auth session is
already stored for the other backend.

## Cloud settings to verify or configure

The linked Supabase project is `jplmrmxibajrvrlhmvkp`. Its 36 migrations have
already been applied remotely according to the deployment handoff. Do not run
`db reset`, `db push`, or seeds as part of Flutter launch.

1. Confirm or set the cloud Auth Site URL and allowed redirect URLs to the actual hosted
   Maestro staging web origin. `http://localhost:7358` can be allowed for one
   developer's local browser, but is not a usable invitation destination for
   other people. Keep email confirmation enabled and configure a working SMTP
   sender, templates, rate limits, and the intended signup policy. The local
   `supabase/config.toml` values (`127.0.0.1:7357`) are local only.
2. Confirm or enable the **Before User Created** Auth hook in the cloud project, targeting
   `public.maestro_before_user_created`. The migration creates the function and
   grants its Auth role permission; `supabase/config.toml` enables the hook for
   local Supabase. A migration does not prove the hosted Auth hook is enabled.
   Test that uninvited student and parent signup is rejected. Decide whether
   public teacher self-registration is intended: the hook explicitly allows a
   `teacher` signup intent, and a confirmed new account can register as a teacher.
3. Confirm or deploy the `send-invitation` Edge Function from
   `supabase/functions/send-invitation/index.ts`, and set its cloud secrets
   `RESEND_API_KEY`, `MAESTRO_FROM_EMAIL`, and `MAESTRO_APP_URL`. The sender must
   be verified with the mail provider. `MAESTRO_APP_URL` must be the public web
   app URL that receives `?invite=` and `?parent_invite=`. Supabase supplies the
   function's project URL and public API key. The function uses the caller's JWT
   with checked invitation RPCs; do not put a service role key in Flutter or
   function configuration for this flow. Function deployment and secrets have
   not been verified here.
4. Confirm cloud Storage has the private `maestro-private` and
   `maestro-messages` buckets and their object policies from migrations. Confirm
   Realtime publication includes `lessons`, `lesson_notes`, `messages`,
   `conversation_reads`, and `message_attachments`. The Flutter messaging client
   subscribes to the last three. Migration history matching does not prove
   Storage uploads, signed reads, or WebSocket subscriptions work at runtime.

## Verification status

| Flow | Repository evidence | Cloud status |
| --- | --- | --- |
| Auth | Sign-in, signup, session restoration, and sign-out use Supabase Auth. Student and parent signup check invitation tokens. | A user confirmed cloud sign-in; role resolution currently fails on the missing `teachers` grant until the corrective migration is applied. Signup, confirmation, and other roles remain unverified. |
| Email invitations | Both portals call `send-invitation`; its checked RPC creates one-use tokens and Resend sends mail. | Function, secrets, sender, and public app URL unverified. |
| Password reset | Teacher, student, and parent screens request reset email. | **Blocked:** no password recovery event handling or new-password form exists in Flutter. Delivery and redirect also unverified. |
| Storage | Migrations define private buckets and RLS; messaging uploads to `maestro-messages`. | Live cloud upload/read isolation unverified. |
| Messaging and Realtime | Checked message RPCs, RLS, attachment policies, and Postgres Changes subscriptions exist. | Live delivery, cross-account visibility, and subscription reconnect unverified. |
| Permissions | SQL tests cover teacher ownership, student access, parent finances, messaging isolation, and a parent with children under two teachers. | Tests were not run against cloud. Cloud test users and approved writes are needed for end-to-end checks. |

The local database tests in `supabase/tests/database/` wrap changes in a
transaction and roll them back. Run them against the local stack, not the linked
cloud project:

```bash
cd /home/vahid/Maestro
npx --yes supabase test db --local
python3 supabase/tests/local_access_smoke.py
cd maestro-mobile
flutter analyze
flutter test --dart-define-from-file=.local.flutter.web.json
```

The local smoke test uses only the loopback Supabase API and synthetic accounts.
The Flutter integration test also requires the seeded local stack. After the
cloud Auth hook, mail, web origin, and function are configured, use dedicated
cloud test users to exercise teacher A, teacher B, a student, and a parent with
two children. Check cross-teacher record denial, student and parent financial
visibility, invitation acceptance, private attachments, message delivery, and
Realtime updates. These actions create or update cloud Auth and app records, so
they require separate approval under the current deployment constraint.

## Current blockers and risks

- Password reset is incomplete in the Flutter client: a reset link has no flow
  to accept a recovery session and set a new password. A UI change is required
  to complete it, and this deployment task expressly excludes UI changes.
- The hosted Before User Created hook may be absent. If absent, the intended
  invitation-only signup rule is not enforced by Auth. Public teacher signup is
  allowed by the hook even when enabled; confirm the enrollment policy.
- Without a hosted Maestro URL and redirect allow-list, confirmation,
  invitation, and recovery links may return to the wrong page or localhost.
- Without the deployed function, verified sender, and secrets, activation email
  delivery fails. Parent invitations have a manual-token fallback for specific
  gateway/configuration failures; student invitations require the function.
- A user confirmed cloud sign-in, but this sandbox could not reach the cloud
  API or inspect dashboard settings. Storage, invitation delivery, Realtime,
  and runtime role isolation remain unverified. Do not treat applied migrations
  as an end-to-end security test.
- Production finance rules for a student shared by two teachers, credits,
  refunds, and reconciliation remain unresolved in
  `docs/supabase-migration-status.md`. The cloud schema is staged, but those
  business rules need a decision and tests before real financial use.
- Legacy SQLite client data has not been imported. No data transfer was made
  here. A later migration needs a separately approved source, identity mapping,
  reconciliation, backup, and restore rehearsal.
- Messaging has no background push dispatcher, and failed attachment metadata
  commits can leave orphan Storage objects. A retention/cleanup process is
  needed if these features are operated at scale.
