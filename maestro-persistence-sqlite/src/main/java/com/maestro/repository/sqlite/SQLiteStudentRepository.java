package com.maestro.repository.sqlite;

import com.maestro.database.DatabaseProvider;
import com.maestro.model.CourseNote;
import com.maestro.model.Instrument;
import com.maestro.model.LessonStatus;
import com.maestro.model.Level;
import com.maestro.model.ReviewStatus;
import com.maestro.model.Status;
import com.maestro.model.Student;
import com.maestro.model.StudentCourse;
import com.maestro.model.StudentProject;
import com.maestro.repository.StudentRepository;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public class SQLiteStudentRepository extends SQLiteRepositorySupport implements StudentRepository {
   public SQLiteStudentRepository(DatabaseProvider databaseProvider) {
      super(databaseProvider);
   }

   @Override
   public Student save(Student student) {
      student.ensureEntityIds();
      Connection connection = null;
      try {
         connection = getConnection();
         saveStudentRow(connection, student);
         replaceStudentGraph(connection, student);
         return student;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not save student", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public Optional<Student> findById(int id) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement("SELECT * FROM students WHERE id = ?")) {
            statement.setInt(1, id);
            try (ResultSet resultSet = statement.executeQuery()) {
               if (!resultSet.next()) {
                  return Optional.empty();
               }
               return Optional.of(mapStudent(connection, resultSet));
            }
         }
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not find student", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public List<Student> findAll() {
      Connection connection = null;
      try {
         connection = getConnection();
         List<Student> students = new ArrayList<>();
         try (PreparedStatement statement = connection.prepareStatement("SELECT * FROM students ORDER BY id");
              ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
               students.add(mapStudent(connection, resultSet));
            }
         }
         return students;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not load students", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public void update(Student student) {
      save(student);
   }

   @Override
   public void deleteById(int id) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement("DELETE FROM students WHERE id = ?")) {
            statement.setInt(1, id);
            statement.executeUpdate();
         }
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not delete student", exception);
      } finally {
         close(connection);
      }
   }

   private void saveStudentRow(Connection connection, Student student) throws SQLException {
      try (PreparedStatement statement = connection.prepareStatement(
            "INSERT OR REPLACE INTO students (id, first_name, family_name, name, email, phone, birthday, status, "
                  + "instrument, level, teacher_id, course_day, course_hour, course_price, present, "
                  + "first_course_status, next_week_assignment, this_week_comment, payment_credit_balance, "
                  + "next_project_id, next_course_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
                  + "ON CONFLICT(id) DO UPDATE SET "
                  + "first_name = excluded.first_name, "
                  + "family_name = excluded.family_name, "
                  + "name = excluded.name, "
                  + "email = excluded.email, "
                  + "phone = excluded.phone, "
                  + "birthday = excluded.birthday, "
                  + "status = excluded.status, "
                  + "instrument = excluded.instrument, "
                  + "level = excluded.level, "
                  + "teacher_id = excluded.teacher_id, "
                  + "course_day = excluded.course_day, "
                  + "course_hour = excluded.course_hour, "
                  + "course_price = excluded.course_price, "
                  + "present = excluded.present, "
                  + "first_course_status = excluded.first_course_status, "
                  + "next_week_assignment = excluded.next_week_assignment, "
                  + "this_week_comment = excluded.this_week_comment, "
                  + "payment_credit_balance = excluded.payment_credit_balance, "
                  + "next_project_id = excluded.next_project_id, "
                  + "next_course_id = excluded.next_course_id")) {
         statement.setInt(1, student.getId());
         statement.setString(2, student.getFirstName());
         statement.setString(3, student.getFamilyName());
         statement.setString(4, student.getName());
         statement.setString(5, student.getEmail());
         statement.setString(6, student.getPhone());
         statement.setString(7, student.getBirthday() == null ? null : student.getBirthday().toString());
         statement.setString(8, student.getStatus() == null ? null : student.getStatus().name());
         statement.setString(9, student.getInstrument() == null ? null : student.getInstrument().name());
         statement.setString(10, student.getLevel() == null ? null : student.getLevel().name());
         if (student.getTeacherId() == null) {
            statement.setObject(11, null);
         } else {
            statement.setInt(11, student.getTeacherId());
         }
         statement.setString(12, student.getCourseDay() == null ? null : student.getCourseDay().name());
         statement.setString(13, student.getCourseHour() == null ? null : student.getCourseHour().toString());
         statement.setDouble(14, student.getCoursePrice());
         statement.setInt(15, student.isPresent() ? 1 : 0);
         statement.setString(16, student.getFirstCourseStatus().name());
         statement.setString(17, student.getNextWeekAssignment());
         statement.setString(18, student.getThisWeekComment());
         statement.setDouble(19, student.getPaymentCreditBalance());
         statement.setInt(20, student.getNextProjectId());
         statement.setInt(21, student.getNextCourseId());
         statement.executeUpdate();
      }
   }

   private void replaceStudentGraph(Connection connection, Student student) throws SQLException {
      try (PreparedStatement statement = connection.prepareStatement("DELETE FROM projects WHERE student_id = ?")) {
         statement.setInt(1, student.getId());
         statement.executeUpdate();
      }

      List<StudentProject> projects = student.getProjects();
      for (int projectIndex = 0; projectIndex < projects.size(); projectIndex++) {
         StudentProject project = projects.get(projectIndex);
         try (PreparedStatement statement = connection.prepareStatement(
               "INSERT INTO projects (id, student_id, name, paid_course_count, sort_order) VALUES (?, ?, ?, ?, ?)")) {
            statement.setInt(1, project.getId());
            statement.setInt(2, student.getId());
            statement.setString(3, project.getName());
            statement.setInt(4, project.getPaidCourseCount());
            statement.setInt(5, projectIndex);
            statement.executeUpdate();
         }

         List<String> pieces = project.getPieces();
         for (int pieceIndex = 0; pieceIndex < pieces.size(); pieceIndex++) {
            try (PreparedStatement statement = connection.prepareStatement(
                  "INSERT INTO pieces (student_id, project_id, title, sort_order) VALUES (?, ?, ?, ?)")) {
               statement.setInt(1, student.getId());
               statement.setInt(2, project.getId());
               statement.setString(3, pieces.get(pieceIndex));
               statement.setInt(4, pieceIndex);
               statement.executeUpdate();
            }
         }

         List<StudentCourse> courses = project.getCourses();
         for (int courseIndex = 0; courseIndex < courses.size(); courseIndex++) {
            StudentCourse course = courses.get(courseIndex);
            try (PreparedStatement statement = connection.prepareStatement(
                  "INSERT INTO courses (id, student_id, project_id, title, day, course_date, hour, price, status, "
                        + "assignment, comment, homework_next_lesson, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")) {
               statement.setInt(1, course.getId());
               statement.setInt(2, student.getId());
               statement.setInt(3, project.getId());
               statement.setString(4, course.getTitle());
               statement.setString(5, course.getDay() == null ? null : course.getDay().name());
               statement.setString(6, course.getDate() == null ? null : course.getDate().toString());
               statement.setString(7, course.getHour() == null ? null : course.getHour().toString());
               statement.setDouble(8, course.getPrice());
               statement.setString(9, course.getStatus().name());
               statement.setString(10, course.getAssignment());
               statement.setString(11, course.getComment());
               statement.setString(12, course.getHomeworkNextLesson());
               statement.setInt(13, courseIndex);
               statement.executeUpdate();
            }

            List<CourseNote> notes = course.getNotes();
            for (int noteIndex = 0; noteIndex < notes.size(); noteIndex++) {
               CourseNote note = notes.get(noteIndex);
               try (PreparedStatement statement = connection.prepareStatement(
                     "INSERT INTO notes (id, student_id, course_id, piece, comment, review_weeks, review_date, "
                           + "review_status, source_course_id, accepted_course_id, sort_order) "
                           + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                     Statement.RETURN_GENERATED_KEYS)) {
                  if (note.getId() > 0) {
                     statement.setInt(1, note.getId());
                  } else {
                     statement.setObject(1, null);
                  }
                  statement.setInt(2, student.getId());
                  statement.setInt(3, course.getId());
                  statement.setString(4, note.getPiece());
                  statement.setString(5, note.getComment());
                  statement.setObject(6, note.getReviewWeeks());
                  statement.setString(7, note.getReviewDate() == null ? null : note.getReviewDate().toString());
                  statement.setString(8, note.getReviewStatus() == null ? null : note.getReviewStatus().name());
                  statement.setInt(9, note.getSourceCourseId());
                  statement.setObject(10, note.getAcceptedCourseId());
                  statement.setInt(11, noteIndex);
                  statement.executeUpdate();
                  if (note.getId() <= 0) {
                     note.setId(generatedId(statement));
                  }
               }
            }
         }
      }
   }

   private Student mapStudent(Connection connection, ResultSet resultSet) throws SQLException {
      Student student = new Student(
            resultSet.getString("first_name"),
            resultSet.getString("family_name"),
            resultSet.getString("phone"),
            resultSet.getString("email"),
            enumValue(Instrument.class, resultSet.getString("instrument")),
            enumValue(Level.class, resultSet.getString("level")),
            nullableInt(resultSet, "teacher_id"),
            enumValue(DayOfWeek.class, resultSet.getString("course_day")),
            timeValue(resultSet.getString("course_hour")),
            resultSet.getDouble("course_price"));
      student.setId(resultSet.getInt("id"));
      student.setName(resultSet.getString("name"));
      student.setBirthday(dateValue(resultSet.getString("birthday")));
      student.setStatus(enumValue(Status.class, resultSet.getString("status")));
      student.setPresent(resultSet.getInt("present") == 1);
      student.setFirstCourseStatus(enumValue(LessonStatus.class, resultSet.getString("first_course_status")));
      student.setNextWeekAssignment(resultSet.getString("next_week_assignment"));
      student.setThisWeekComment(resultSet.getString("this_week_comment"));
      student.setPaymentCreditBalance(resultSet.getDouble("payment_credit_balance"));
      student.setNextProjectId(resultSet.getInt("next_project_id"));
      student.setNextCourseId(resultSet.getInt("next_course_id"));
      student.replaceProjects(loadProjects(connection, student.getId()));
      return student;
   }

   private List<StudentProject> loadProjects(Connection connection, int studentId) throws SQLException {
      List<StudentProject> projects = new ArrayList<>();
      try (PreparedStatement statement = connection.prepareStatement(
            "SELECT * FROM projects WHERE student_id = ? ORDER BY sort_order, id")) {
         statement.setInt(1, studentId);
         try (ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
               StudentProject project = new StudentProject(resultSet.getString("name"));
               project.setId(resultSet.getInt("id"));
               project.setPaidCourseCount(resultSet.getInt("paid_course_count"));
               project.getPieces().addAll(loadPieces(connection, studentId, project.getId()));
               project.getCourses().addAll(loadCourses(connection, studentId, project.getId()));
               projects.add(project);
            }
         }
      }
      return projects;
   }

   private List<String> loadPieces(Connection connection, int studentId, int projectId) throws SQLException {
      List<String> pieces = new ArrayList<>();
      try (PreparedStatement statement = connection.prepareStatement(
            "SELECT title FROM pieces WHERE student_id = ? AND project_id = ? ORDER BY sort_order, id")) {
         statement.setInt(1, studentId);
         statement.setInt(2, projectId);
         try (ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
               pieces.add(resultSet.getString("title"));
            }
         }
      }
      return pieces;
   }

   private List<StudentCourse> loadCourses(Connection connection, int studentId, int projectId) throws SQLException {
      List<StudentCourse> courses = new ArrayList<>();
      try (PreparedStatement statement = connection.prepareStatement(
            "SELECT * FROM courses WHERE student_id = ? AND project_id = ? ORDER BY sort_order, id")) {
         statement.setInt(1, studentId);
         statement.setInt(2, projectId);
         try (ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
               StudentCourse course = new StudentCourse(
                     resultSet.getString("title"),
                     enumValue(DayOfWeek.class, resultSet.getString("day")),
                     dateValue(resultSet.getString("course_date")),
                     timeValue(resultSet.getString("hour")),
                     resultSet.getDouble("price"));
               course.setId(resultSet.getInt("id"));
               course.setStatus(enumValue(LessonStatus.class, resultSet.getString("status")));
               course.setAssignment(resultSet.getString("assignment"));
               course.setComment(resultSet.getString("comment"));
               course.setHomeworkNextLesson(resultSet.getString("homework_next_lesson"));
               course.getNotes().addAll(loadNotes(connection, studentId, course.getId()));
               courses.add(course);
            }
         }
      }
      return courses;
   }

   private List<CourseNote> loadNotes(Connection connection, int studentId, int courseId) throws SQLException {
      List<CourseNote> notes = new ArrayList<>();
      try (PreparedStatement statement = connection.prepareStatement(
            "SELECT * FROM notes WHERE student_id = ? AND course_id = ? ORDER BY sort_order, id")) {
         statement.setInt(1, studentId);
         statement.setInt(2, courseId);
         try (ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
               CourseNote note = new CourseNote(resultSet.getString("piece"));
               note.setId(resultSet.getInt("id"));
               note.setComment(resultSet.getString("comment"));
               note.setReviewData(
                     nullableInt(resultSet, "review_weeks"),
                     dateValue(resultSet.getString("review_date")),
                     enumValue(ReviewStatus.class, resultSet.getString("review_status")),
                     resultSet.getInt("source_course_id"),
                     nullableInt(resultSet, "accepted_course_id"));
               notes.add(note);
            }
         }
      }
      return notes;
   }

   private Integer nullableInt(ResultSet resultSet, String column) throws SQLException {
      int value = resultSet.getInt(column);
      return resultSet.wasNull() ? null : value;
   }

   private LocalDate dateValue(String value) {
      return value == null || value.isBlank() ? null : LocalDate.parse(value);
   }

   private LocalTime timeValue(String value) {
      return value == null || value.isBlank() ? null : LocalTime.parse(value);
   }

   private <T extends Enum<T>> T enumValue(Class<T> type, String value) {
      return value == null || value.isBlank() ? null : Enum.valueOf(type, value);
   }

   private void close(Connection connection) {
      try {
         releaseConnection(connection);
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not close student repository connection", exception);
      }
   }
}
