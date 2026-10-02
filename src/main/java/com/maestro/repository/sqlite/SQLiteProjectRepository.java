package com.maestro.repository.sqlite;

import com.maestro.database.DatabaseProvider;
import com.maestro.model.StudentProject;
import com.maestro.repository.ProjectRepository;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

public class SQLiteProjectRepository extends SQLiteRepositorySupport implements ProjectRepository {
   public SQLiteProjectRepository(DatabaseProvider databaseProvider) {
      super(databaseProvider);
   }

   @Override
   public StudentProject save(int studentId, StudentProject project, int sortOrder) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement(
               "INSERT OR REPLACE INTO projects (id, student_id, name, paid_course_count, sort_order) VALUES (?, ?, ?, ?, ?)")) {
            statement.setInt(1, project.getId());
            statement.setInt(2, studentId);
            statement.setString(3, project.getName());
            statement.setInt(4, project.getPaidCourseCount());
            statement.setInt(5, sortOrder);
            statement.executeUpdate();
         }
         return project;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not save project", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public List<StudentProject> findByStudentId(int studentId) {
      Connection connection = null;
      try {
         connection = getConnection();
         List<StudentProject> projects = new ArrayList<>();
         try (PreparedStatement statement = connection.prepareStatement(
               "SELECT * FROM projects WHERE student_id = ? ORDER BY sort_order, id")) {
            statement.setInt(1, studentId);
            try (ResultSet resultSet = statement.executeQuery()) {
               while (resultSet.next()) {
                  StudentProject project = new StudentProject(resultSet.getString("name"));
                  project.setId(resultSet.getInt("id"));
                  project.setPaidCourseCount(resultSet.getInt("paid_course_count"));
                  projects.add(project);
               }
            }
         }
         return projects;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not load projects", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public void deleteById(int studentId, int projectId) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement(
               "DELETE FROM projects WHERE student_id = ? AND id = ?")) {
            statement.setInt(1, studentId);
            statement.setInt(2, projectId);
            statement.executeUpdate();
         }
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not delete project", exception);
      } finally {
         close(connection);
      }
   }

   private void close(Connection connection) {
      try {
         releaseConnection(connection);
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not close project repository connection", exception);
      }
   }
}
