# Maestro Mobile

Flutter client for the existing Maestro Spring Boot REST API.

This module is intentionally separate from the JavaFX desktop app. It does not duplicate Java business logic; it reads and writes Maestro data through REST/JSON.

## Run the API

From the repository root:

```sh
mvn -pl maestro-api -am spring-boot:run
```

The API defaults to `http://localhost:8080/api`.

## Run Flutter

From this folder:

```sh
flutter pub get
flutter run -d chrome --dart-define=MAESTRO_API_BASE_URL=http://localhost:8080/api
```

For Android emulator, use the host bridge:

```sh
flutter run -d android --dart-define=MAESTRO_API_BASE_URL=http://10.0.2.2:8080/api
```

For iOS, generate the Xcode platform directory with the Flutter toolchain before the first run:

```sh
flutter create --platforms=ios .
flutter run -d ios --dart-define=MAESTRO_API_BASE_URL=http://localhost:8080/api
```

## Implemented increment

- Maestro theme and logo asset
- REST API client
- Dashboard
- Students list
- Student Profile

Remaining sections are wired into navigation as placeholders for future API-backed increments.
