# Calendar availability and sharing

The existing Flutter Calendar keeps its day, week, and month lesson views. The
Availability tab shows weekly working hours, lessons, and titled blocked time.
Availability records and blocks are separate from `lessons`; no lesson rows are copied.

## Scheduling data

- `teacher_availability_rules` stores Monday–Sunday recurring wall-clock ranges
  with effective dates. Editing or deleting a rule from a later week splits the
  rule, preserving earlier weeks.
- `teacher_availability_exceptions` stores single-date available or unavailable
  ranges. An available exception can open a weekly closure; an unavailable
  exception takes priority over all available ranges.
- Existing scheduled lessons occupy their stored duration (30, 45, or 60 minutes
  in the editor). The database rejects new overlaps for the same teacher and
  invalid end times. Existing lessons remain in place when availability changes.
- Teacher timezones are IANA names in `teachers.timezone`. Existing lesson
  `date` and `hour` columns are interpreted as teacher-local wall time. Week
  navigation uses calendar dates across daylight-saving transitions.
- `teacher_time_blocks` stores private titled blocks in teacher-local wall time.
  Blocks can be one-time, daily, weekly, or custom weekdays, including overnight
  and multi-day ranges. `teacher_time_block_exceptions` stores one-occurrence
  edits or cancellations. Both tables have teacher-owner RLS.

## Public links

The Share Availability dialog creates a random 256-bit link token. PostgreSQL
stores only its SHA-256 hash. The token is shown once, so a lost link should be
regenerated and the old link revoked. A link can have an expiration and date
range. The public `/availability/<token>` Flutter route calls the
`maestro_shared_availability` RPC without a login. Its server-side calculation
returns only available slots, the teacher's display name, and timezone. The
RPC excludes occupied lessons, blocked time, and private fields; share-link rows and lesson
records remain protected by RLS.

Hosted web deployments must serve the Flutter `index.html` for
`/availability/*`. The public route must use the same Supabase URL and
publishable key as the teacher app. For mobile builds, define
`MAESTRO_WEB_URL=https://your-domain.com` so the Share dialog can create the
hosted link. Web builds can use their current origin when this value is absent.
`MAESTRO_WEB_URL` is public configuration; it is not an OAuth secret.

## ICS export

Export Calendar offers free availability intervals or selected lessons for a
range up to 84 days. It converts teacher-local times to UTC on the server,
rejecting nonexistent local times during daylight-saving jumps. The `.ics`
file uses UTC `VEVENT`s, stable IDs, CRLF lines, and no student details.
Availability events are transparent. Blocked periods export as opaque private
events titled only "Blocked"; private block titles and notes are omitted. Web users can download or share the file;
mobile users get the platform share sheet; desktop users get a save dialog.

## Apply and verify locally

From the repository root:

```bash
npx --yes supabase migration up --local
npx --yes supabase test db --local
cd maestro-mobile
flutter pub get
flutter analyze
flutter test --dart-define-from-file=.local.flutter.web.json
flutter build web --dart-define-from-file=.local.flutter.web.json
```

The migrations are versioned in `supabase/migrations/20261023100000` through
`20261023130000`. Do not reset a data-bearing database to apply them.

## Remaining Google Calendar phase

Google OAuth, selected calendar import, automatic busy-time synchronization,
and optional lesson export are not connected yet. The integration should run
through Supabase Edge Functions with the OAuth client secret and refresh tokens
stored server-side. Use Google's calendar list and free/busy APIs for selected
calendars, then cache only busy ranges in a teacher-owned table. A provider
interface can later add Outlook without changing availability calculations.
An event mapping table is needed for idempotent optional lesson export.

To activate this phase, a hosted web origin, Google OAuth web client ID and
secret, and an authorized Edge Function redirect URI are required. The secret
must be configured in the server environment, never in Flutter build defines.
