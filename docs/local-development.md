# Local Flutter + Supabase development

Flutter now uses Supabase Auth and the versioned PostgreSQL functions directly. The Spring API is only for the legacy Java apps; do not start it for Flutter. No cloud connection is required.

## Start the existing local stack

From the repository root in WSL/Linux:

```bash
docker info
npx --yes supabase start
npx --yes supabase migration up --local
python3 scripts/write_local_flutter_config.py
```

`migration up --local` applies pending forward migrations without resetting existing data. The config script writes ignored files containing the **public** Supabase URL and publishable key for Web, Windows, and the Android emulator. It refuses a non-loopback Supabase API. It no longer writes any Spring API URL.

The local synthetic teachers are `ada.teacher@maestro.example` and `ben.teacher@maestro.example`, both with password `LocalMaestro123!`. Use them only with the local stack. Teacher sign-in uses Supabase Auth; after sign-in, the UI loads only that account's teacher row. A new authenticated account can create its teacher profile through the onboarding form. No teacher can select another teacher by numeric ID.

## Chrome

From `maestro-mobile/`:

```bash
flutter pub get
flutter run -d chrome --web-port=7357 --dart-define-from-file=.local.flutter.web.json
```

Open <http://localhost:7357>. Supabase Studio is <http://127.0.0.1:54323>; the Supabase API is <http://127.0.0.1:54321>. These are not the Flutter UI. `flutter run -d chrome` without the define file shows a configuration message; it never falls back to Spring.

## Windows desktop

Install Windows Flutter and Visual Studio with C++ desktop tools. Keep the local Supabase stack running in WSL with Docker Desktop WSL integration. In Windows PowerShell, from the Windows-accessible `maestro-mobile` directory:

```powershell
flutter pub get
flutter devices
flutter run -d windows --dart-define-from-file=.local.flutter.windows.json
```

If the Windows checkout is separate, run the config script there while local Supabase is reachable, or create an ignored `.local.flutter.windows.json` with `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from that local stack. Windows runtime behavior has not been tested in this WSL environment.

## Android and other targets

The Android emulator uses `.local.flutter.android.json` and host bridge `10.0.2.2`. The debug manifest permits HTTP for local development. Release builds should use HTTPS project URLs. iOS, macOS, and Linux runners require supported host toolchains; macOS and Linux runners are not yet present in this checkout.

## Checks

```bash
cd /home/vahid/Maestro
npx --yes supabase migration list --local
npx --yes supabase test db --local
python3 supabase/tests/local_access_smoke.py

cd maestro-mobile
flutter analyze
flutter test --dart-define-from-file=.local.flutter.web.json
flutter build web --dart-define-from-file=.local.flutter.web.json
```

The database test files wrap writes in transactions and roll them back. The Auth/Storage smoke test uploads then removes a temporary image. The Flutter integration test signs in as two local teachers and reads their separate rows. None of these commands resets the local database.

Never use `supabase db reset --local` on a database with data you need to keep. Do not run `supabase link`, `db push`, or `--linked` reset for local development. The original SQLite files remain untouched.
