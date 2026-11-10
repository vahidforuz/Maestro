# Parent portal and activation email setup

The `send-invitation` Supabase Edge Function sends student and parent activation
emails. It calls the existing checked invitation RPC with the teacher's JWT.
The Flutter app contains no mail or Supabase administrative secret.

For local email delivery, put `MAESTRO_FROM_EMAIL`, `MAESTRO_APP_URL`, and
`RESEND_API_KEY` in the ignored `supabase/functions/.env`, then restart the local
Supabase stack so the Edge Runtime loads them. A real, verified sender and an
inbox you control are required; `pat.parent@maestro.example` is only a seeded
local account and cannot receive mail. The app URL must open Maestro from the
recipient's device, such as the local web URL when testing in one browser.

Configure these Edge Function secrets before enabling email delivery:

- `RESEND_API_KEY`: API key for the mail provider.
- `MAESTRO_FROM_EMAIL`: verified sender address.
- `MAESTRO_APP_URL`: public URL for the Flutter app, including any base path.
- `SUPABASE_URL` and `SUPABASE_ANON_KEY`: Supabase project values normally
  provided to Edge Functions by Supabase.

Allow the app URL in Supabase Auth redirect URLs. The activation email opens
the existing student flow with `?invite=` or the parent flow with
`?parent_invite=`. The recipient confirms their Supabase Auth email, signs in
with the invited address, and accepts the one-use invitation. An existing
account can sign in and accept without creating another Auth user.

If delivery fails, the student or parent invitation row remains. The teacher
can resend it from Student Access or Parents / Guardians. Email delivery
requires an accessible web entry point for Maestro; native-only deployments
need an app link or equivalent URL handler for that entry point.

If the local API gateway returns HTTP 503 with `name resolution failed`, Kong
could not route to the Edge Runtime. Confirm that the local stack and its Edge
Runtime container are running, that Flutter points to the same local API port,
and that `POST /functions/v1/send-invitation` reaches the function. The app
offers a manual parent invitation link for this exact gateway failure using
the teacher-authorized RPC; it does **not** claim an email was sent. The same
manual option is used when the function reports missing email configuration.
Restoring the Edge Runtime and configuring delivery are still required for
automatic email invitations. The function now checks its email configuration
before it creates a token.

From the local development machine, use `npx --yes supabase status` to confirm
the API port, `docker ps` to inspect the Edge Runtime container, and
`curl -i -X POST http://127.0.0.1:54321/functions/v1/send-invitation` to
check the gateway route. A healthy route may reject this unauthenticated probe;
it should not return the DNS 503. If the Edge Runtime is not running, start the
local stack with `npx --yes supabase start` or serve this function with
`npx --yes supabase functions serve send-invitation --env-file supabase/functions/.env`.

The parent portal migrations are
`20261103130000_parent_access.sql` and
`20261103131000_parent_messaging.sql`, followed by
`20261104120000_parent_finance_isolation.sql` for the stricter parent payment
authorization. Apply them in order in a reviewed
environment. No migration or function was deployed as part of this change.
