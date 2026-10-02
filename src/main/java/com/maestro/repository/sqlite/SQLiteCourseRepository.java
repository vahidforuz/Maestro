package com.maestro.repository.sqlite;

import com.maestro.database.DatabaseProvider;
import com.maestro.model.LessonStatus;
import com.maestro.model.StudentCourse;
import com.maestro.repository.CourseRepository;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

public class SQLiteCourseRepository extends SQLiteRepositorySupport implements CourseRepository {
   public SQLiteCourseRepository(DatabaseProvider databaseProvider) {
      super(databaseProvider);
   }

   @Override
   public StudentCourse save(int studentId, int projectId, StudentCourse course, int sortOrder) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement(
               "INSERT OR REPLACE INTO courses (id, student_id, project_id, title, day, course_date, hour, price, status, "
                     + "assignment, comment, homework_next_lesson, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")) {
            statement.setInt(1, course.getId());
            statement.setInt(2, studentId);
            statement.setInt(3, projectId);
            statement.setString(4, course.getTitle());
            statement.setString(5, course.getDay() == null ? null : course.getDay().name());
            statement.setString(6, course.getDate() == null ? null : course.getDate().toString());
            statement.setString(7, course.getHour() == null ? null : course.getHour().toString());
            statement.setDouble(8, course.getPrice());
            statement.setString(9, course.getStatus().name());
            statement.setString(10, course.getAssignment());
            statement.setString(11, course.getComment());
            statement.setString(12, course.getHomeworkNextLesson());
            statement.setInt(13, sortOrder);
            statement.executeUpdate();
         }
         return course;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not save course", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public List<StudentCourse> findByProjectId(int studentId, int projectId) {
      Connection connection = null;
      try {
         connection = getConnection();
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
                  courses.add(course);
               }
            }
         }
         return courses;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not load courses", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public void deleteById(int studentId, int courseId) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement(
               "DELETE FROM courses WHERE student_id = ? AND id = ?")) {
            statement.setInt(1, studentId);
            statement.setInt(2, courseId);
            statement.executeUpdate();
         }
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not delete course", exception);
      } finally {
         close(connection);
      }
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
         throw new IllegalStateException("Could not close course repository connection", exception);
      }
   }
}
