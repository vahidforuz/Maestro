package com.maestro.repository.sqlite;

import com.maestro.database.DatabaseProvider;
import com.maestro.model.CourseNote;
import com.maestro.model.ReviewStatus;
import com.maestro.repository.NoteRepository;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public class SQLiteNoteRepository extends SQLiteRepositorySupport implements NoteRepository {
   public SQLiteNoteRepository(DatabaseProvider databaseProvider) {
      super(databaseProvider);
   }

   @Override
   public CourseNote save(int studentId, int courseId, CourseNote note, int sortOrder) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement(
               "INSERT OR REPLACE INTO notes (id, student_id, course_id, piece, comment, created_date, review_weeks, review_date, "
                     + "review_status, source_course_id, accepted_course_id, target_course_id, reviewed_date, review_history, sort_order) "
                     + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
               Statement.RETURN_GENERATED_KEYS)) {
            if (note.getId() > 0) {
               statement.setInt(1, note.getId());
            } else {
               statement.setObject(1, null);
            }
            statement.setInt(2, studentId);
            statement.setInt(3, courseId);
            statement.setString(4, note.getPiece());
            statement.setString(5, note.getComment());
            statement.setString(6, note.getCreatedDate() == null ? null : note.getCreatedDate().toString());
            statement.setObject(7, note.getReviewWeeks());
            statement.setString(8, note.getReviewDate() == null ? null : note.getReviewDate().toString());
            statement.setString(9, note.getReviewStatus() == null ? null : note.getReviewStatus().name());
            statement.setInt(10, note.getSourceCourseId());
            statement.setObject(11, note.getAcceptedCourseId());
            statement.setObject(12, note.getTargetCourseId());
            statement.setString(13, note.getReviewedDate() == null ? null : note.getReviewedDate().toString());
            statement.setString(14, note.getReviewHistory());
            statement.setInt(15, sortOrder);
            statement.executeUpdate();
            if (note.getId() <= 0) {
               note.setId(generatedId(statement));
            }
         }
         return note;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not save note", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public List<CourseNote> findByCourseId(int studentId, int courseId) {
      Connection connection = null;
      try {
         connection = getConnection();
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
                        nullableInt(resultSet, "accepted_course_id"),
                        dateValue(resultSet.getString("created_date")),
                        nullableInt(resultSet, "target_course_id"),
                        dateValue(resultSet.getString("reviewed_date")),
                        resultSet.getString("review_history"));
                  notes.add(note);
               }
            }
         }
         return notes;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not load notes", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public void deleteById(int noteId) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement("DELETE FROM notes WHERE id = ?")) {
            statement.setInt(1, noteId);
            statement.executeUpdate();
         }
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not delete note", exception);
      } finally {
         close(connection);
      }
   }

   private Integer nullableInt(ResultSet resultSet, String column) throws SQLException {
      int value = resultSet.getInt(column);
      return resultSet.wasNull() ? null : value;
   }

   private LocalDate dateValue(String value) {
      return value == null || value.isBlank() ? null : LocalDate.parse(value);
   }

   private <T extends Enum<T>> T enumValue(Class<T> type, String value) {
      return value == null || value.isBlank() ? null : Enum.valueOf(type, value);
   }

   private void close(Connection connection) {
      try {
         releaseConnection(connection);
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not close note repository connection", exception);
      }
   }
}
