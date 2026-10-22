# Maestro

run the desktop GUI app with:
```
  cd /home/vahid/Maestro
  mvn -pl maestro-desktop -am javafx:run

  Other runnable modules:

  # API server
  mvn -pl maestro-api -am spring-boot:run

  # review worker
  mvn -pl maestro-review-worker -am spring-boot:run
```

Flutter client:
```
  cd /home/vahid/Maestro
  npx --yes supabase start
  python3 scripts/write_local_flutter_config.py

  cd /home/vahid/Maestro/maestro-mobile
  flutter pub get
  flutter run -d chrome --web-port=7357 --dart-define-from-file=.local.flutter.web.json
```

## Flutter + Supabase migration status

Flutter now signs teachers in with Supabase Auth and reads/writes existing
teacher, student, lesson, review, and payment workflows through Supabase.
No Spring API is needed for the Flutter app. The Java modules remain for legacy
desktop use and data migration. See [local development](docs/local-development.md)
and [cutover status](docs/supabase-flutter-cutover.md).

To start the local Supabase stack on Windows/WSL2, enable Docker Desktop's WSL
integration for this distro, then run from the repository root:

    npx --yes supabase start
    npx --yes supabase status

To stop the local stack:

    npx --yes supabase stop

The start command applies versioned migrations to local PostgreSQL and does not
touch the original SQLite files. Local synthetic teachers can sign in as
`ada.teacher@maestro.example` or `ben.teacher@maestro.example` with password
`LocalMaestro123!`. These accounts are only for local development.
