# Teacher–student messaging

The messaging migration is `supabase/migrations/20261024100000_messaging.sql`.
It is a forward-only migration. It does not change existing students, lessons,
payments, pieces, or notes. The Flutter UI is in `maestro-mobile/lib/screens/messages_screen.dart`
and uses the existing Supabase Auth session.

## Local verification

With the existing local Docker/Supabase stack running, from the repository root:

```sh
npx --yes supabase migration up --local
npx --yes supabase test db --local
python3 supabase/tests/local_access_smoke.py
```

`migration up --local` applies only pending migrations. Do not use `db reset`
on a data-bearing local stack. The pgTAP file checks direct SQL/API-role
access, duplicate conversation opens, sender identity, idempotency, unread
counts, image attachment access, teacher and student isolation, and revocation.
The migration is already applied in the local stack. All 32 messaging pgTAP
assertions pass. The full database suite currently has two unrelated failures
in `calendar_availability.sql` against existing local data.

## Access model

One `conversations` row exists for each `(teacher_id, student_id)` pair. Opening
one uses a unique constraint and checked RPC, so concurrent opens return the
same row. Every read and write checks an active `teacher_students` relationship,
an active teacher, and an enabled `student_portal_access` grant linked to an
Auth user. `students.user_id` is not a messaging grant. Only that teacher and
linked student can read or send. Existing guardians do not inherit chat access.
Message inserts, attachment metadata inserts, and read-marker writes are only
available through checked RPCs. Clients cannot directly update message history
or another user's read marker. A send uses a client UUID; retrying it returns the
same server row. Server timestamps determine order. Text is limited to 4,000
characters and 30 messages per minute per sender.

The private `maestro-messages` Storage bucket allows PDFs, JPEG/PNG/WebP images,
and common audio formats up to 20 MB. Objects have a conversation/message path.
The upload policy checks the sender and current membership; the read policy
requires finalized attachment metadata and current membership. Audio is loaded
only after tapping play and streams through the authenticated Storage endpoint.
Other files are streamed with the current Auth token into a temporary mobile
file after a deliberate tap, then passed to the device viewer. Images use
60-second signed URLs, issued only after Storage checks current membership.
Thumbnails request a 480-pixel transform and fall back to the original if
image transformation is unavailable. The full-screen viewer requests a
separate short-lived URL. No public bucket URL is issued. Already downloaded
bytes cannot be recalled after revocation; an issued image URL remains usable
until its 60-second expiry. New signing and authenticated downloads are denied
after revocation. Browser non-image file viewing and image saving are currently disabled.
Failed uploads can be
retried with the same message client UUID. An uploaded object left behind by a
failed metadata commit needs a periodic orphan cleanup job.

Lesson and piece cards are shared from the chat action menu. The server checks
the pair and student portal permissions before accepting references. A lesson
card contains its title and date; a piece card contains its title. Private
lesson notes and payment data are never copied into messages. Chat references
do not change calendar scheduling.

## Notifications and platform setup

Each new message creates at most one content-free outbox event for the other
participant if that user's message-alert preference is enabled. The outbox is
private to the service role. No push dispatcher, APNs/FCM credentials, device
token registration, OS permission prompt, or notification deep-link handler is
configured in this repository. To enable background push, deploy a trusted
outbox consumer that checks the recipient still has access before sending,
uses a generic lock-screen alert, records `processed_at` idempotently, and
opens the conversation ID through app navigation. Do not include message text
in lock-screen payloads by default.

Android declares `RECORD_AUDIO` and the recorder asks for permission at use.
The iOS folder currently lacks an Xcode Runner project. After generating it as
described in `maestro-mobile/ios/README.md`, add `NSMicrophoneUsageDescription`
to Runner `Info.plist` before building on iOS. Audio recordings are capped at
five minutes and 20 MB, with preview and retry. No physical Android/iOS device
was available here for recording, playback, keyboard, or profile-mode tests.

## Performance

Conversation summaries and total unread counts share one Realtime listener in
the teacher shell, including while another page is selected. The student
Messages screen owns its listener while visible. The inbox refreshes after
reconnection or app resume. A room initially loads 40
messages and requests older pages with a `(created_at, id)` cursor. Its message,
read, and attachment listeners are scoped to that room and removed on exit.
The reversed lazy list keeps the newest message anchored without scrolling a
user away from older history. Native uploads stream from disk. The browser
fallback buffers selected files, capped at 20 MB. The current summary RPC
returns up to 500 conversations; a cursor for the conversation list is needed
for studios beyond that size. No device profile measurements are available.
