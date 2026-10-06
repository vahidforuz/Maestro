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
  mvn -pl maestro-api -am spring-boot:run

  cd /home/vahid/Maestro/maestro-mobile
  flutter pub get
  flutter run -d chrome --dart-define=MAESTRO_API_BASE_URL=http://localhost:8080/api
```
