# Current Maestro architecture

> Historical pre-cutover snapshot. See [current Flutter cutover status](../supabase-flutter-cutover.md).

Baseline inspected on 2026-10-22 from branch version2_supabase, commit 293a1c8. This describes code and read-only SQLite metadata, not README claims. See ../migration/feature-inventory.md for screen-level behavior.

## Repository map and runtime

| Module | Implemented responsibility | Runtime dependency |
| --- | --- | --- |
| maestro-domain | Java models, enums, repository and transaction interfaces | None |
| maestro-application | Teacher, student, payment, and review services; three empty service source files for group/course/enrolment | Domain |
| maestro-persistence-sqlite | Schema migrations 1–3, JDBC repositories, legacy TSV/serialized-data importer, transaction manager | Domain, SQLite |
| maestro-api | Spring Boot REST controllers and dependency wiring | Application, SQLite; default relative data/music_school.db |
| maestro-review-worker | Spring scheduler polling GET /api/students hourly | Running API; currently logs reachability only, does not deliver reminders |
| maestro-desktop | JavaFX teacher application, calendar, profiles, payment dashboard | Java services and SQLite directly |
| maestro-mobile | Flutter teacher application for Android, iOS, web | Spring REST API |

The Flutter entry point is maestro-mobile/lib/main.dart. It reads MAESTRO_API_BASE_URL from a Dart define, defaults to http://localhost:8080/api, and injects MaestroApi(ApiClient) into MaterialApp. maestro-mobile/lib/screens/maestro_app.dart holds a teacher object, selected section, selected student, and selected course in StatefulWidget state. Five sections use a bottom NavigationBar below 840 px and a sidebar at wider widths. Student profile replaces the section body; there is no named route registry, deep-link handling, persistent session, or state-management package. Screens use StatefulWidget, FutureBuilder, callbacks, and local state. Dependencies are Flutter, http, and intl. Theme and reusable widgets are under lib/theme and lib/widgets; JSON models are under lib/models.

Tracked Flutter platform projects exist for Android, iOS, and web. Windows, macOS, and Linux projects do not exist yet. The iOS README says its platform directory should be generated, but an ios directory is already tracked; its completeness still needs validation on macOS. There is no Flutter-side SQLite dependency. SQLite is the Java API's and JavaFX app's persistence layer.

## Current request path and trust boundary

Flutter screen → MaestroApi → ApiClient (unauthenticated HTTP/JSON) → Spring controller → Java service/repository → SQLite.

The gate lists all teachers, accepts a numeric teacher ID, or creates an account, then keeps the chosen Teacher in memory. The API has no authentication or authorization middleware. GET /students and GET /payments return all records. studio_metrics.dart filters students and payments on the client; it considers students without a teacher visible to every teacher and payments without a student visible to every teacher. This is presentation filtering, not access control. API controllers also expose student update/delete and teacher delete directly. The migration must close this security gap without treating the current gate as secure authentication.

## SQLite schema and actual data locations

DatabaseInitializer creates schema_migrations and legacy_migrations, plus teachers, students, projects, courses, pieces, notes, and payments. The key relationships are:

| Table | Key and relationships | Relevant data |
| --- | --- | --- |
| teachers | integer id | contact, status, studio, instruments, lesson defaults, currency, profile image path |
| students | integer id; nullable teacher_id → teachers | identity/contact, birthday, status, instrument, level, recurring day/hour and price, first-lesson legacy fields, credit balance, next project/course IDs |
| projects | (student_id, id) → students | name, paid_course_count, sort_order |
| courses | (student_id, id); (student_id, project_id) → projects | title, day/date/hour, price, status, assignment, comment, homework, sort_order |
| pieces | integer id; (student_id, project_id) → projects | title, sort_order |
| notes | integer id; (student_id, course_id) → courses | piece/comment, review weeks/date/status, source/accepted/target course references, reviewed date/history, sort_order |
| payments | integer id; student_id → students | signed amount, date, method, note |

Indexes cover teacher/student, project/student, course date, payments/student, and note review lookup. SQLite uses REAL for money and TEXT for dates/times/enums. Some review course references are integer fields without declared foreign keys. Repositories recreate a student's nested graph when saving it; this requires particular care when translating concurrent edits to normalized PostgreSQL rows. Deleting a student cascades its projects, courses, pieces, notes, and payments in SQLite.

Three separate tracked database files exist and are **not identical**:

| Read-only source | Teachers | Students | Projects | Courses | Pieces | Notes | Payments |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| data/music_school.db | 1 | 3 | 3 | 20 | 4 | 7 | 7 |
| maestro-desktop/data/music_school.db | 1 | 2 | 2 | 13 | 4 | 6 | 3 |
| maestro-api/data/music_school.db | 1 | 2 | 3 | 16 | 2 | 3 | 3 |

The path is relative to the process working directory, so launches from different directories can use different databases. The root database has zero schema_migrations rows despite the application defining migrations; it has three legacy_migrations rows. A read-only foreign_key_check on the root database returned zero violations. None of these checks establishes which file is canonical. The TSV/serialized legacy sources in data/ must also be retained until provenance is resolved. No data was copied or changed.

## Business behavior in the implementation

- Student creation initializes a first project and first course. Additional courses copy the first course's day, time, and price, and choose the next unused weekly date. The Java domain maintains per-student project/course IDs.
- Lesson statuses are NOTHING, PRESENT, ABSENT, CANCELED, and MOVED. Flutter shows CANCELED as “CANCELLED” in calendar labels. The teacher default duration determines displayed calendar end times; courses do not store their own duration.
- PaymentServiceImpl saves the payment and updates the student graph inside a SQLite transaction. For positive course price it combines existing credit with the amount, floors credit divided by course price, accounts for already existing unpaid project courses, creates only missing courses, increases paid_course_count, and stores remaining credit rounded to cents. If price is nonpositive, the full payment becomes credit. The existing persistence test expects a $100 payment at $20 per course to leave five total courses, not five newly added courses: the initial course counts toward the five.
- Flutter also calculates a displayed balance as total student payments minus prices of PRESENT or ABSENT courses. This differs from the stored payment_credit_balance and from paid_course_count. The meanings must be reconciled before moving money logic. Negative amounts appear as refunds in the JavaFX payment dashboard, but there is no dedicated refund/correction operation.
- Notes can be scheduled for review after 1–4 courses in Flutter. The API targets a future course by project order when one exists; otherwise it uses a date offset. Moving course dates updates related review dates. Creating future courses resolves pending targets. Accepting a review records reviewed course/date and history; rescheduling rolls to the next course or a one-week date. Desktop additionally offers dismiss; Flutter does not expose it. The worker only polls the API and logs success/failure.

## Baseline verification

flutter analyze: passed with no issues. flutter test: one harness-only test passed; no workflow assertions. mvn -pl maestro-persistence-sqlite -am test -q: nine persistence tests passed, including payment creation, rollback, and review scheduling. No Android, iOS, web browser, or desktop UI flow was run during this audit.
