# Implemented feature inventory

> Historical Flutter/Java parity inventory. See [current cutover status](../supabase-flutter-cutover.md) for the active data path.

Inspected the Flutter source, Java controllers/services/models/JavaFX views, SQLite schema, and existing tests on 2026-10-22. “Implemented” means reachable code or API exists; it does not claim a complete or tested user workflow. Flutter is the behavioral baseline for existing mobile features. See ../architecture/current-architecture.md for data flow and schema.

## Flutter screens and navigation

| Area | Implemented Flutter behavior | Source |
| --- | --- | --- |
| Entry / gate | List teachers, select one, sign in by numeric ID, create a teacher record; session held in memory only | lib/main.dart; screens/teacher_gate_screen.dart; screens/maestro_app.dart |
| Dashboard | Current-month revenue and lesson summary, today’s lessons, payment-attention list, review-note summary, links to student/calendar, add student | screens/dashboard_screen.dart |
| Students | Search by name/email/phone/instrument/level; responsive list/table; add with first/last name, contact, instrument, level, recurring day/hour, price prefilled from teacher | screens/students_screen.dart |
| Student profile | Header/detail view, back action, tabs for Courses, Projects / Pieces, Payments; opens selected lesson from calendar | screens/student_profile_screen.dart |
| Courses / attendance | Add in chosen project; select/open, edit and delete; edit day/date/start time/price/status/assignment/comment/homework. Status choices: NOTHING, PRESENT, ABSENT, CANCELED, MOVED. Quick “present” action | screens/student_profile_screen.dart |
| Projects / pieces | Create, rename, delete projects; add, rename, delete pieces in projects | screens/student_profile_screen.dart |
| Notes / reviews | Add/edit/delete piece-linked lesson note with comment and 0–4 course review offset; display due reviews and history; mark reviewed, keep for next lesson, edit source note | screens/student_profile_screen.dart |
| Student payments | List payments, amount/date/method/note; add a payment; show total paid, credit balance, and calculated remaining lessons | screens/student_profile_screen.dart |
| Payments dashboard | Month/year and student-name search, revenue total, history; add payment for selected student | screens/payments_screen.dart |
| Calendar | Day/week/month; previous/today/next; search; mini-month on wide layout; lesson cards by time; details sheet with status, project, pieces, review count; open student or lesson | screens/calendar_screen.dart |
| Settings | View/edit teacher contact/studio/instruments/default lesson duration/default price/currency; sign out | screens/settings_screen.dart |
| Shared UI | Theme/logo, cards, section headers, status badges, async loading/error states; mobile bottom navigation and desktop-width sidebar | theme/; widgets/; screens/maestro_app.dart |

All five top-level sections are connected in the current app. placeholder_screen.dart exists but is not selected from MaestroApp. The README’s statement that sections are placeholders is stale.

## Flutter behavior that is missing or partial

- Student edit and delete are **not exposed in the Flutter UI** and MaestroApi has no updateStudent/deleteStudent methods, although the Spring API has PUT/DELETE /students/{id}. The requested student edit/delete should be added as parity completion, with regression coverage for existing create/view flows.
- Teacher sign-in is not authenticated; any listed/typed teacher ID selects that teacher. Account creation has no verified ownership. Sign-out clears only in-memory state.
- Payment editing, deletion, explicit refunds, and corrections are not exposed in Flutter. A negative amount is accepted by the current API and rendered as a signed payment, but this is not a complete refund workflow.
- Calendar is a read/navigation surface. Lesson creation and editing occur in a student profile. Course duration is not editable per lesson; the teacher default controls displayed end time.
- Review dismissal exists in Java service/API/JavaFX, but Flutter only exposes reviewed and keep/reschedule. The worker does not issue reminders.
- Student/parent sign-in and views, file upload, media sharing, chat, Realtime, email, Google/Outlook sync, and billing are not implemented.
- Validation is uneven: student name and numeric price are checked, but date/time strings rely on API parsing; amount only needs to parse as a number, including negative values; teacher profile checks numeric duration/price but lacks range checks. Some async dialogs call APIs without error/finally handling.
- The student creation day list includes THURSDAY twice. The note dialog uses project.pieces.first, so attempting to add a note to a project with no pieces can fail. The global payment dialog initializes from students.first and depends on the button being disabled for an empty visible list. These are documented bugs to fix compatibly, without removing flows.
- Flutter filters teacher/student/payment visibility after unrestricted API reads. This is a security defect and cannot be carried into the target architecture.
- Flutter widget_test.dart asserts only that the harness runs; there are no workflow or permission tests.

## JavaFX-only or richer JavaFX behavior

| Area | JavaFX capability or difference | Migration treatment |
| --- | --- | --- |
| Student profile | “Edit Student” form exists in StudentProfileView; no Flutter counterpart. Java API supports update/delete. | Add compatible Flutter edit flow; decide whether delete is exposed and retain history safeguards. |
| Teacher profile | Change photo using desktop file chooser and profile image path. | Plan cross-platform image selection/storage with permissions; current Flutter settings only preserves the existing path. |
| Settings | Configurable course title mode in application settings. | Decide whether this is a shared preference; preserve as a desktop parity item, not a mobile feature claim. |
| Payments | More detailed month/year/student/type filters, payment/refund rows and summaries; negative amounts labeled refund. | Preserve existing Flutter payment screen first, then port useful desktop filters/refund flow once ledger semantics are settled. |
| Reviews | Dismiss review action and an explicit “show in review week” control. | Implement when review feature migrates, retaining current Flutter reviewed/keep behavior. |
| Calendar/course editing | JavaFX has separate date-change and pass-course controls, lesson history, and a wider editing surface. | Compare individual behavior against Flutter course edit and add only genuine missing workflows. |

ClassGroup, Course, Enrollment, TypeCourse, and related repository/service declarations exist in Java, but the relevant application service source files are empty and the SQLite schema has no tables for them. They are dormant scaffolding, not implemented SaaS features. There is no evidence of functional parent, chat, media, or external calendar modules.

## REST dependencies to replace incrementally

Flutter MaestroApi currently uses:

- GET /teachers, GET /teachers/{id}, POST /teachers, PUT /teachers/{id}
- GET /students, GET /students/{id}, POST /students
- GET /payments, GET /students/{id}/payments, POST /students/{id}/payments
- POST/PUT/DELETE /students/{id}/projects and nested pieces/courses/notes
- POST /students/{id}/reviews/{noteId}/accept/{courseId}
- POST /students/{id}/reviews/{noteId}/reschedule/{courseId}

The Spring API additionally exposes teacher/student DELETE, student PUT, GET due reviews, and review dismissal, none called by Flutter. There is no versioned API contract, authentication token, pagination, or optimistic concurrency. Student JSON embeds projects, courses, and notes, so many screens depend on a full nested student graph. Flutter payment JSON expects a nested student object for ID/name. A Supabase repository adapter must preserve these model shapes until presentation code is migrated and tested.

## Regression contract to capture before replacement

1. Gate → dashboard → section switches → student profile → back, at narrow and wide widths.
2. Teacher creation/settings edit, defaults on new student, and sign-out.
3. Student create/search/open; first project/course initialization; edit/delete after added.
4. Project/piece/course create, edit, delete; first-course and last-project guards; weekly date generation; all five statuses.
5. Calendar day/week/month navigation, search, card details, open lesson, duration display.
6. Payment add in both entry points, $100/$20 five-total-course behavior, existing unpaid lessons, partial credit, zero price, negative/correction decision, and three different balance displays.
7. Note CRUD; pending review target/date, due ordering, reviewed/reschedule/dismiss, history, date changes and target deletion.
8. Auth sessions; authorized and denied reads/writes for two unrelated teachers, shared student, student, two guardians, and admin; payments and private media.

Existing Java SQLitePersistenceTest covers some persistence/payment/review cases (nine passing tests). Existing Flutter tests do not yet cover these flows. No platform UI behavior has been verified by an actual device/browser run in this audit.
