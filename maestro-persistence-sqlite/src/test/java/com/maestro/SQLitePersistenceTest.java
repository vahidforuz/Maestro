package com.maestro;

import com.maestro.database.DatabaseInitializer;
import com.maestro.database.LegacyDataMigrator;
import com.maestro.database.SQLiteDatabaseProvider;
import com.maestro.model.CourseNote;
import com.maestro.model.Instrument;
import com.maestro.model.Level;
import com.maestro.model.LessonStatus;
import com.maestro.model.Payment;
import com.maestro.model.ReviewStatus;
import com.maestro.model.Student;
import com.maestro.model.StudentCourse;
import com.maestro.model.StudentProject;
import com.maestro.model.Teacher;
import com.maestro.repository.RepositoryFactory;
import com.maestro.repository.sqlite.SQLiteRepositoryFactory;
import com.maestro.service.PaymentService;
import com.maestro.service.PaymentServiceImpl;
import com.maestro.service.ReviewService;
import com.maestro.service.ReviewServiceImpl;
import java.io.ObjectOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import junit.framework.TestCase;

public class SQLitePersistenceTest extends TestCase {
   public void testStudentProjectCourseNotePaymentPersistAfterReopen() throws Exception {
      Path databasePath = tempDatabasePath();
      SQLiteDatabaseProvider provider = new SQLiteDatabaseProvider(databasePath);
      new DatabaseInitializer(provider).initialize();
      RepositoryFactory repositories = new SQLiteRepositoryFactory(provider);

      Teacher teacher = new Teacher(12, "Teacher", "111", "teacher@example.com", "Studio");
      repositories.teachers().save(teacher);

      Student student = new Student(
            "Ada",
            "Lovelace",
            "222",
            "ada@example.com",
            Instrument.PIANO,
            Level.BEGINNER,
            teacher.getId(),
            DayOfWeek.MONDAY,
            LocalTime.of(16, 0),
            20);
      student.setId(101);
      StudentProject project = student.getCurrentProject();
      project.addPiece("Prelude");
      StudentCourse firstCourse = project.getCourses().get(0);
      firstCourse.setStatus(LessonStatus.PRESENT);
      CourseNote note = firstCourse.addNote("Prelude");
      note.setComment("Good rhythm");
      note.setReviewSchedule(1, firstCourse.getDate());
      repositories.students().save(student);
      repositories.payments().save(new Payment(student, 40, LocalDate.of(2026, 10, 1), "Cash", "Two lessons"));

      RepositoryFactory reopened = repositories(databasePath);
      Student loaded = reopened.students().findById(101).orElseThrow();
      assertEquals("Ada", loaded.getFirstName());
      assertEquals(1, loaded.getProjects().size());
      assertEquals("Prelude", loaded.getProjects().get(0).getPieces().get(0));
      assertEquals(LessonStatus.PRESENT, loaded.getProjects().get(0).getCourses().get(0).getStatus());
      assertEquals("Good rhythm", loaded.getProjects().get(0).getCourses().get(0).getNotes().get(0).getComment());
      assertEquals(1, reopened.payments().findByStudent(loaded).size());

      loaded.setPhone("333");
      reopened.students().update(loaded);
      assertEquals("333", repositories(databasePath).students().findById(101).orElseThrow().getPhone());

      reopened.students().deleteById(101);
      assertFalse(repositories(databasePath).students().findById(101).isPresent());
   }

   public void testPaymentServiceCreatesCoursesAndPersistsRelationships() throws Exception {
      Path databasePath = tempDatabasePath();
      RepositoryFactory repositories = repositories(databasePath);
      PaymentService paymentService = new PaymentServiceImpl(
            repositories.payments(),
            repositories.students(),
            repositories.transactionManager());

      Student student = new Student(
            "Grace",
            "Hopper",
            "",
            "",
            Instrument.PIANO,
            Level.BEGINNER,
            null,
            DayOfWeek.TUESDAY,
            LocalTime.of(17, 0),
            20);
      student.setId(202);
      repositories.students().save(student);

      paymentService.addPayment(new Payment(student, 100, LocalDate.of(2026, 10, 2), "Card", ""), student.getCurrentProject());

      Student loaded = repositories(databasePath).students().findById(202).orElseThrow();
      assertEquals(5, loaded.getCurrentProject().getCourses().size());
      assertEquals(1, repositories(databasePath).payments().findByStudent(loaded).size());
      assertEquals(0.0, loaded.getPaymentCreditBalance());
   }

   public void testAddCourseToSelectedProjectPersistsAfterReopen() throws Exception {
      Path databasePath = tempDatabasePath();
      RepositoryFactory repositories = repositories(databasePath);

      Student student = new Student(
            "Clara",
            "Schumann",
            "",
            "",
            Instrument.PIANO,
            Level.INTERMEDIATE,
            null,
            DayOfWeek.MONDAY,
            LocalTime.of(16, 0),
            10);
      student.setId(303);
      StudentProject firstProject = student.getCurrentProject();
      StudentProject secondProject = student.addProject();
      secondProject.setName("Project 2");
      StudentCourse addedCourse = student.addCourseToProject(secondProject);
      repositories.students().save(student);

      Student loaded = repositories(databasePath).students().findById(303).orElseThrow();
      StudentProject loadedFirstProject = loaded.findProjectById(firstProject.getId());
      StudentProject loadedSecondProject = loaded.findProjectById(secondProject.getId());

      assertNotNull(loadedFirstProject);
      assertNotNull(loadedSecondProject);
      assertEquals(1, loadedFirstProject.getCourses().size());
      assertEquals(1, loadedSecondProject.getCourses().size());

      StudentCourse loadedCourse = loadedSecondProject.findCourseById(addedCourse.getId());
      assertNotNull(loadedCourse);
      assertEquals(firstProject.getCourses().get(0).getDate().plusWeeks(1), loadedCourse.getDate());
      assertEquals(LocalTime.of(16, 0), loadedCourse.getHour());
      assertEquals(10.0, loadedCourse.getPrice());
   }

   public void testTeacherProfilePersistsAfterReopen() throws Exception {
      Path databasePath = tempDatabasePath();
      RepositoryFactory repositories = repositories(databasePath);

      Teacher teacher = new Teacher(88, "Vahid Foruzanmehr", "555", "vahid@example.com", "123 Music Ave");
      teacher.setFirstName("Vahid");
      teacher.setLastName("Foruzanmehr");
      teacher.setStudioName("Maestro Music Studio");
      teacher.setCity("Toronto");
      teacher.setPostalCode("M1M 1M1");
      teacher.setMainInstrument("Piano");
      teacher.setOtherInstruments("Guitar");
      teacher.setDefaultLessonDuration(60);
      teacher.setDefaultLessonPrice(25);
      teacher.setCurrency("CAD");
      teacher.setProfileImagePath("/tmp/profile.png");
      repositories.teachers().save(teacher);

      Teacher loaded = repositories(databasePath).teachers().findById(88).orElseThrow();
      assertEquals("Vahid", loaded.getFirstName());
      assertEquals("Foruzanmehr", loaded.getLastName());
      assertEquals("Maestro Music Studio", loaded.getStudioName());
      assertEquals("Toronto", loaded.getCity());
      assertEquals("M1M 1M1", loaded.getPostalCode());
      assertEquals("Piano", loaded.getMainInstrument());
      assertEquals("Guitar", loaded.getOtherInstruments());
      assertEquals(60, loaded.getDefaultLessonDuration());
      assertEquals(25.0, loaded.getDefaultLessonPrice());
      assertEquals("CAD", loaded.getCurrency());
      assertEquals("/tmp/profile.png", loaded.getProfileImagePath());

      loaded.setDefaultLessonDuration(45);
      loaded.setDefaultLessonPrice(30);
      loaded.setEmail("updated@example.com");
      repositories.teachers().update(loaded);

      Teacher updated = repositories(databasePath).teachers().findById(88).orElseThrow();
      assertEquals(45, updated.getDefaultLessonDuration());
      assertEquals(30.0, updated.getDefaultLessonPrice());
      assertEquals("updated@example.com", updated.getEmail());
   }

   public void testTeacherDefaultsCanPrefillNewStudentWithoutChangingExistingCourses() throws Exception {
      Teacher teacher = new Teacher(89, "Default Teacher", "", "", "");
      teacher.setDefaultLessonDuration(60);
      teacher.setDefaultLessonPrice(35);
      teacher.setMainInstrument("PIANO");

      Student existing = new Student(
            "Existing",
            "Student",
            "",
            "",
            Instrument.PIANO,
            Level.BEGINNER,
            teacher.getId(),
            DayOfWeek.MONDAY,
            LocalTime.of(16, 0),
            20);

      Student createdWithDefault = new Student(
            "New",
            "Student",
            "",
            "",
            Instrument.valueOf(teacher.getMainInstrument()),
            Level.BEGINNER,
            teacher.getId(),
            DayOfWeek.TUESDAY,
            LocalTime.of(17, 0),
            teacher.getDefaultLessonPrice());

      teacher.setDefaultLessonPrice(50);

      assertEquals(20.0, existing.getCoursePrice());
      assertEquals(35.0, createdWithDefault.getCoursePrice());
      assertEquals(50.0, teacher.getDefaultLessonPrice());
   }

   public void testTransactionRollback() throws Exception {
      Path databasePath = tempDatabasePath();
      RepositoryFactory repositories = repositories(databasePath);

      try {
         repositories.transactionManager().runInTransaction(() -> {
            repositories.teachers().save(new Teacher(55, "Rollback", "", "", ""));
            throw new IllegalStateException("force rollback");
         });
         fail("Expected rollback exception");
      } catch (IllegalStateException expected) {
         assertFalse(repositories.teachers().findById(55).isPresent());
      }
   }

   public void testLegacyMigrationRunsOnce() throws Exception {
      Path databasePath = tempDatabasePath();
      SQLiteDatabaseProvider provider = new SQLiteDatabaseProvider(databasePath);
      new DatabaseInitializer(provider).initialize();
      RepositoryFactory repositories = new SQLiteRepositoryFactory(provider);
      Path legacyDir = Files.createTempDirectory("maestro-legacy-test");
      Path teachersFile = legacyDir.resolve("teachers.tsv");
      Path studentsFile = legacyDir.resolve("students.ser");
      Path paymentsFile = legacyDir.resolve("payments.tsv");

      Files.writeString(
            teachersFile,
            "3\tLegacy Teacher\t555\tlegacy@example.com\tStudio\tACTIVE\n",
            StandardCharsets.UTF_8);

      Student student = new Student(
            "Legacy",
            "Student",
            "",
            "",
            Instrument.GUITAR,
            Level.INTERMEDIATE,
            3,
            DayOfWeek.WEDNESDAY,
            LocalTime.of(18, 0),
            30);
      student.setId(77);
      student.getCurrentProject().addPiece("Etude");
      try (ObjectOutputStream output = new ObjectOutputStream(Files.newOutputStream(studentsFile))) {
         output.writeObject(List.of(student));
      }

      Files.writeString(paymentsFile, "77\t30\t2026-10-03\tCash\tLegacy payment\n", StandardCharsets.UTF_8);

      LegacyDataMigrator migrator = new LegacyDataMigrator(
            provider,
            repositories.transactionManager(),
            repositories.teachers(),
            repositories.students(),
            repositories.payments(),
            teachersFile,
            studentsFile,
            paymentsFile);
      migrator.migrateIfNeeded();
      migrator.migrateIfNeeded();

      RepositoryFactory reopened = repositories(databasePath);
      assertTrue(reopened.teachers().findById(3).isPresent());
      Student loaded = reopened.students().findById(77).orElseThrow();
      assertEquals("Legacy", loaded.getFirstName());
      assertEquals("Etude", loaded.getCurrentProject().getPieces().get(0));
      assertEquals(1, reopened.payments().findByStudent(loaded).size());
   }

   public void testScheduledReviewsAcceptDismissAndRollForward() throws Exception {
      Path databasePath = tempDatabasePath();
      RepositoryFactory repositories = repositories(databasePath);
      ReviewService reviewService = new ReviewServiceImpl(repositories.students());

      Student student = new Student(
            "Review",
            "Student",
            "",
            "",
            Instrument.PIANO,
            Level.BEGINNER,
            null,
            DayOfWeek.THURSDAY,
            LocalTime.of(16, 0),
            25);
      student.setId(303);
      StudentProject project = student.getCurrentProject();
      project.addPiece("Fur Elise");
      project.addPiece("Technique");

      StudentCourse october1 = project.getCourses().get(0);
      october1.setDate(LocalDate.of(2026, 10, 1));
      StudentCourse october15 = student.addCourseToProject(project);
      october15.setDate(LocalDate.of(2026, 10, 15));
      StudentCourse october22 = student.addCourseToProject(project);
      october22.setDate(LocalDate.of(2026, 10, 22));
      StudentCourse october29 = student.addCourseToProject(project);
      october29.setDate(LocalDate.of(2026, 10, 29));

      CourseNote elise = october1.addNote("Fur Elise");
      elise.setComment("Practice measures 10-18 slowly.");
      elise.setSourceCourseId(october1.getId());
      elise.setReviewSchedule(3, october1.getDate());

      CourseNote technique = october1.addNote("Technique");
      technique.setComment("Practice C major scale.");
      technique.setSourceCourseId(october1.getId());
      technique.setReviewSchedule(3, october1.getDate());

      CourseNote dismissed = october1.addNote("Technique");
      dismissed.setComment("Dismiss this review.");
      dismissed.setSourceCourseId(october1.getId());
      dismissed.setReviewSchedule(3, october1.getDate());

      repositories.students().save(student);

      assertEquals(0, reviewService.getDueReviews(student, october15).size());
      assertEquals(3, reviewService.getDueReviews(student, october22).size());

      reviewService.acceptReview(student, october22, elise);
      assertEquals(ReviewStatus.ACCEPTED, elise.getReviewStatus());
      assertEquals(Integer.valueOf(october22.getId()), elise.getAcceptedCourseId());
      assertEquals(october1.getDate(), elise.getCreatedDate());
      assertEquals(october22.getDate(), elise.getReviewedDate());
      assertEquals(0, october22.getNotes().size());

      reviewService.dismissReview(student, dismissed);
      assertEquals(ReviewStatus.DISMISSED, dismissed.getReviewStatus());
      assertEquals(1, reviewService.getDueReviews(student, october22).size());

      october22.setStatus(LessonStatus.CANCELED);
      assertEquals(0, reviewService.getDueReviews(student, october22).size());
      assertEquals(1, reviewService.getDueReviews(student, october29).size());

      reviewService.acceptReview(student, october29, technique);
      assertEquals(0, reviewService.getDueReviews(student, october29).size());

      Student reloaded = repositories(databasePath).students().findById(303).orElseThrow();
      StudentCourse reloadedOctober1 = reloaded.findCourseById(october1.getId());
      StudentCourse reloadedOctober29 = reloaded.findCourseById(october29.getId());
      assertEquals(3, reloadedOctober1.getNotes().size());
      assertEquals(0, reloadedOctober29.getNotes().size());
      assertEquals(ReviewStatus.ACCEPTED, reloadedOctober1.getNotes().get(1).getReviewStatus());
      assertEquals(october29.getDate(), reloadedOctober1.getNotes().get(1).getReviewedDate());
      assertEquals(0, new ReviewServiceImpl(repositories(databasePath).students())
            .getDueReviews(reloaded, reloadedOctober29).size());
   }

   public void testReviewTargetsFutureCoursesWithoutDuplicatingNotes() throws Exception {
      Path databasePath = tempDatabasePath();
      RepositoryFactory repositories = repositories(databasePath);
      ReviewService reviewService = new ReviewServiceImpl(repositories.students());

      Student student = new Student(
            "Target",
            "Review",
            "",
            "",
            Instrument.PIANO,
            Level.BEGINNER,
            null,
            DayOfWeek.MONDAY,
            LocalTime.of(16, 0),
            10);
      student.setId(404);
      StudentProject project = student.getCurrentProject();
      project.addPiece("Fur Elise");
      StudentCourse course1 = project.getCourses().get(0);
      course1.setDate(LocalDate.of(2026, 10, 5));
      CourseNote unresolvedFuture = course1.addNote("Fur Elise");
      unresolvedFuture.setComment("Resolve when next course exists.");
      unresolvedFuture.setReviewSchedule(1, course1.getDate());
      StudentCourse course2 = student.addCourseToProject(project);
      course2.setDate(LocalDate.of(2026, 10, 12));
      StudentCourse course3 = student.addCourseToProject(project);
      course3.setDate(LocalDate.of(2026, 10, 19));
      assertEquals(Integer.valueOf(course2.getId()), unresolvedFuture.getTargetCourseId());

      CourseNote nextCourse = course1.addNote("Fur Elise");
      nextCourse.setComment("Practice bars 10-18 slowly.");
      nextCourse.setReviewSchedule(1, course2.getDate(), course2.getId());

      CourseNote inTwoCourses = course1.addNote("Fur Elise");
      inTwoCourses.setComment("Work on left-hand fingering.");
      inTwoCourses.setReviewSchedule(2, course3.getDate(), course3.getId());
      repositories.students().save(student);

      assertEquals(2, reviewService.getDueReviews(student, course2).size());
      assertEquals(unresolvedFuture.getId(), reviewService.getDueReviews(student, course2).get(0).note().getId());
      assertEquals(nextCourse.getId(), reviewService.getDueReviews(student, course2).get(1).note().getId());
      assertEquals(1, reviewService.getDueReviews(student, course3).size());
      assertEquals(inTwoCourses.getId(), reviewService.getDueReviews(student, course3).get(0).note().getId());

      reviewService.acceptReview(student, course2, nextCourse);
      assertEquals(ReviewStatus.ACCEPTED, nextCourse.getReviewStatus());
      assertEquals(0, course2.getNotes().size());

      reviewService.rescheduleReview(student, course2, inTwoCourses);
      assertEquals(Integer.valueOf(course3.getId()), inTwoCourses.getTargetCourseId());
      assertEquals(ReviewStatus.PENDING, inTwoCourses.getReviewStatus());

      Student reloaded = repositories(databasePath).students().findById(404).orElseThrow();
      StudentCourse reloadedCourse1 = reloaded.findCourseById(course1.getId());
      StudentCourse reloadedCourse2 = reloaded.findCourseById(course2.getId());
      StudentCourse reloadedCourse3 = reloaded.findCourseById(course3.getId());
      assertEquals(3, reloadedCourse1.getNotes().size());
      assertEquals(0, reloadedCourse2.getNotes().size());
      assertEquals(0, reloadedCourse3.getNotes().size());
      assertEquals(Integer.valueOf(reloadedCourse2.getId()), reloadedCourse1.getNotes().get(0).getTargetCourseId());
      assertEquals(ReviewStatus.ACCEPTED, reloadedCourse1.getNotes().get(1).getReviewStatus());
      assertEquals(ReviewStatus.PENDING, reloadedCourse1.getNotes().get(2).getReviewStatus());
      assertEquals(1, new ReviewServiceImpl(repositories(databasePath).students())
            .getDueReviews(reloaded, reloadedCourse3).size());
   }

   private RepositoryFactory repositories(Path databasePath) {
      SQLiteDatabaseProvider provider = new SQLiteDatabaseProvider(databasePath);
      new DatabaseInitializer(provider).initialize();
      return new SQLiteRepositoryFactory(provider);
   }

   private Path tempDatabasePath() throws Exception {
      return Files.createTempDirectory("maestro-sqlite-test").resolve("music_school.db");
   }
}
