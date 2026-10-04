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