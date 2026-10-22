# Maestro Flutter

Flutter teacher application for local Supabase Auth and PostgreSQL. The dashboard, students, student profile, calendar, payments, settings, lesson attendance, notes, and reviews use `SupabaseMaestroDataSource`. Spring Boot is not needed to run this Flutter application.

## Local Supabase setup

From the repository root:

```bash
npx --yes supabase start
npx --yes supabase migration up --local
python3 scripts/write_local_flutter_config.py
```

The script creates ignored Dart-define files with the local Supabase URL and **public** publishable key. It does not write privileged keys. It does not reset the database.

## Chrome

From `maestro-mobile/`:

```bash
flutter pub get
flutter run -d chrome --web-port=7357 --dart-define-from-file=.local.flutter.web.json
```

Open <http://localhost:7357>. The backend API is <http://127.0.0.1:54321>; Supabase Studio is <http://127.0.0.1:54323>. For local synthetic data, sign in as `ada.teacher@maestro.example` or `ben.teacher@maestro.example` with password `LocalMaestro123!`.

## Windows desktop

With Windows Flutter and Visual Studio C++ desktop tools installed, and the same local Supabase stack reachable from Windows PowerShell:

```powershell
cd path\to\Maestro\maestro-mobile
flutter pub get
flutter run -d windows --dart-define-from-file=.local.flutter.windows.json
```

Windows runtime testing remains outstanding. A separate Windows checkout needs its own ignored public define file generated from the same local stack.

## Other targets and checks

The Android emulator uses `.local.flutter.android.json` (`10.0.2.2:54321`). iOS requires Xcode on macOS. macOS and Linux runner generation and runtime checks remain.

```bash
flutter analyze
flutter test --dart-define-from-file=.local.flutter.web.json
flutter test --platform chrome --dart-define-from-file=.local.flutter.web.json
flutter build web --dart-define-from-file=.local.flutter.web.json
```

See [local development](../docs/local-development.md), [cutover status](../docs/supabase-flutter-cutover.md), and [migration status](../docs/supabase-migration-status.md) for remaining work and deployment blockers.
