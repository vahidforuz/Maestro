package com.maestro.repository.sqlite;

import com.maestro.database.DatabaseProvider;
import com.maestro.repository.PieceRepository;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

public class SQLitePieceRepository extends SQLiteRepositorySupport implements PieceRepository {
   public SQLitePieceRepository(DatabaseProvider databaseProvider) {
      super(databaseProvider);
   }

   @Override
   public void replacePieces(int studentId, int projectId, List<String> pieces) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement(
               "DELETE FROM pieces WHERE student_id = ? AND project_id = ?")) {
            statement.setInt(1, studentId);
            statement.setInt(2, projectId);
            statement.executeUpdate();
         }
         for (int index = 0; index < pieces.size(); index++) {
            try (PreparedStatement statement = connection.prepareStatement(
                  "INSERT INTO pieces (student_id, project_id, title, sort_order) VALUES (?, ?, ?, ?)")) {
               statement.setInt(1, studentId);
               statement.setInt(2, projectId);
               statement.setString(3, pieces.get(index));
               statement.setInt(4, index);
               statement.executeUpdate();
            }
         }
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not replace pieces", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public List<String> findByProjectId(int studentId, int projectId) {
      Connection connection = null;
      try {
         connection = getConnection();
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
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not load pieces", exception);
      } finally {
         close(connection);
      }
   }

   private void close(Connection connection) {
      try {
         releaseConnection(connection);
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not close piece repository connection", exception);
      }
   }
}
