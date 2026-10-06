package com.maestro.database;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDateTime;

public class DatabaseInitializer {
   private final DatabaseProvider databaseProvider;

   public DatabaseInitializer(DatabaseProvider databaseProvider) {
      this.databaseProvider = databaseProvider;
   }

   public void initialize() {
      Connection connection = null;
      try {
         connection = databaseProvider.getConnection();
         try (Statement statement = connection.createStatement()) {
            statement.execute("CREATE TABLE IF NOT EXISTS schema_migrations ("
                  + "version INTEGER PRIMARY KEY, "
                  + "applied_at TEXT NOT NULL)");
         }
         runMigration(connection, 1, this::createInitialSchema);
         runMigration(connection, 2, this::addTeacherProfileColumns);
         runMigration(connection, 3, this::addNoteReviewColumns);
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not initialize database", exception);
      } finally {
         try {
            databaseProvider.releaseConnection(connection);
         } catch (SQLException exception) {
            throw new IllegalStateException("Could not close database connection", exception);
         }
      }
   }

   private void createInitialSchema(Connection connection) throws SQLException {
      try (Statement statement = connection.createStatement()) {
            statement.execute("CREATE TABLE IF NOT EXISTS legacy_migrations ("
                  + "source TEXT PRIMARY KEY, "
                  + "migrated_at TEXT NOT NULL)");
            statement.execute("CREATE TABLE IF NOT EXISTS teachers ("
                  + "id INTEGER PRIMARY KEY, "
                  + "name TEXT NOT NULL, "
                  + "telephone TEXT, "
                  + "email TEXT, "
                  + "address TEXT, "
                  + "status TEXT NOT NULL, "
                  + "first_name TEXT NOT NULL DEFAULT '', "
                  + "last_name TEXT NOT NULL DEFAULT '', "
                  + "studio_name TEXT NOT NULL DEFAULT '', "
                  + "city TEXT NOT NULL DEFAULT '', "
                  + "postal_code TEXT NOT NULL DEFAULT '', "
                  + "main_instrument TEXT NOT NULL DEFAULT '', "
                  + "other_instruments TEXT NOT NULL DEFAULT '', "
                  + "default_lesson_duration INTEGER NOT NULL DEFAULT 60, "
                  + "default_lesson_price REAL NOT NULL DEFAULT 0, "
                  + "currency TEXT NOT NULL DEFAULT 'CAD', "
                  + "profile_image_path TEXT NOT NULL DEFAULT '')");
            statement.execute("CREATE TABLE IF NOT EXISTS students ("
                  + "id INTEGER PRIMARY KEY, "
                  + "first_name TEXT, "
                  + "family_name TEXT, "
                  + "name TEXT NOT NULL, "
                  + "email TEXT, "
                  + "phone TEXT, "
                  + "birthday TEXT, "
                  + "status TEXT, "
                  + "instrument TEXT, "
                  + "level TEXT, "
                  + "teacher_id INTEGER, "
                  + "course_day TEXT, "
                  + "course_hour TEXT, "
                  + "course_price REAL NOT NULL DEFAULT 0, "
                  + "present INTEGER NOT NULL DEFAULT 0, "
                  + "first_course_status TEXT NOT NULL DEFAULT 'NOTHING', "
                  + "next_week_assignment TEXT NOT NULL DEFAULT '', "
                  + "this_week_comment TEXT NOT NULL DEFAULT '', "
                  + "payment_credit_balance REAL NOT NULL DEFAULT 0, "
                  + "next_project_id INTEGER NOT NULL DEFAULT 1, "
                  + "next_course_id INTEGER NOT NULL DEFAULT 1, "
                  + "FOREIGN KEY (teacher_id) REFERENCES teachers(id))");
            statement.execute("CREATE TABLE IF NOT EXISTS projects ("
                  + "id INTEGER NOT NULL, "
                  + "student_id INTEGER NOT NULL, "
                  + "name TEXT NOT NULL, "
                  + "paid_course_count INTEGER NOT NULL DEFAULT 0, "
                  + "sort_order INTEGER NOT NULL DEFAULT 0, "
                  + "PRIMARY KEY (student_id, id), "
                  + "FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE)");
            statement.execute("CREATE TABLE IF NOT EXISTS courses ("
                  + "id INTEGER NOT NULL, "
                  + "student_id INTEGER NOT NULL, "
                  + "project_id INTEGER NOT NULL, "
                  + "title TEXT NOT NULL, "
                  + "day TEXT, "
                  + "course_date TEXT, "
                  + "hour TEXT, "
                  + "price REAL NOT NULL DEFAULT 0, "
                  + "status TEXT NOT NULL DEFAULT 'NOTHING', "
                  + "assignment TEXT NOT NULL DEFAULT '', "
                  + "comment TEXT NOT NULL DEFAULT '', "
                  + "homework_next_lesson TEXT NOT NULL DEFAULT '', "
                  + "sort_order INTEGER NOT NULL DEFAULT 0, "
                  + "PRIMARY KEY (student_id, id), "
                  + "FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE, "
                  + "FOREIGN KEY (student_id, project_id) REFERENCES projects(student_id, id) ON DELETE CASCADE)");
            statement.execute("CREATE TABLE IF NOT EXISTS pieces ("
                  + "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                  + "student_id INTEGER NOT NULL, "
                  + "project_id INTEGER NOT NULL, "
                  + "title TEXT NOT NULL, "
                  + "sort_order INTEGER NOT NULL DEFAULT 0, "
                  + "FOREIGN KEY (student_id, project_id) REFERENCES projects(student_id, id) ON DELETE CASCADE)");
            statement.execute("CREATE TABLE IF NOT EXISTS notes ("
                  + "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                  + "student_id INTEGER NOT NULL, "
                  + "course_id INTEGER NOT NULL, "
                  + "piece TEXT NOT NULL DEFAULT '', "
                  + "comment TEXT NOT NULL DEFAULT '', "
                  + "created_date TEXT, "
                  + "review_weeks INTEGER, "
                  + "review_date TEXT, "
                  + "review_status TEXT, "
                  + "source_course_id INTEGER NOT NULL DEFAULT 0, "
                  + "accepted_course_id INTEGER, "
                  + "target_course_id INTEGER, "
                  + "reviewed_date TEXT, "
                  + "review_history TEXT NOT NULL DEFAULT '', "
                  + "sort_order INTEGER NOT NULL DEFAULT 0, "
                  + "FOREIGN KEY (student_id, course_id) REFERENCES courses(student_id, id) ON DELETE CASCADE)");
            statement.execute("CREATE TABLE IF NOT EXISTS payments ("
                  + "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                  + "student_id INTEGER NOT NULL, "
                  + "amount REAL NOT NULL, "
                  + "payment_date TEXT, "
                  + "method TEXT, "
                  + "note TEXT, "
                  + "FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE)");

         }
         addColumnIfMissing(connection, "notes", "review_status", "TEXT");
         addColumnIfMissing(connection, "notes", "source_course_id", "INTEGER NOT NULL DEFAULT 0");
         addColumnIfMissing(connection, "notes", "accepted_course_id", "INTEGER");
         addColumnIfMissing(connection, "notes", "created_date", "TEXT");
         addColumnIfMissing(connection, "notes", "target_course_id", "INTEGER");
         addColumnIfMissing(connection, "notes", "reviewed_date", "TEXT");
         addColumnIfMissing(connection, "notes", "review_history", "TEXT NOT NULL DEFAULT ''");
         try (Statement statement = connection.createStatement()) {
            statement.execute("CREATE INDEX IF NOT EXISTS idx_students_teacher_id ON students(teacher_id)");
            statement.execute("CREATE INDEX IF NOT EXISTS idx_projects_student_id ON projects(student_id)");
            statement.execute("CREATE INDEX IF NOT EXISTS idx_courses_student_project ON courses(student_id, project_id)");
            statement.execute("CREATE INDEX IF NOT EXISTS idx_courses_date ON courses(course_date)");
            statement.execute("CREATE INDEX IF NOT EXISTS idx_payments_student_id ON payments(student_id)");
            statement.execute("CREATE INDEX IF NOT EXISTS idx_notes_course ON notes(student_id, course_id)");
            statement.execute("CREATE INDEX IF NOT EXISTS idx_notes_review_due ON notes(student_id, review_status, review_date)");
      }
   }

   private void addTeacherProfileColumns(Connection connection) throws SQLException {
      addColumnIfMissing(connection, "teachers", "first_name", "TEXT NOT NULL DEFAULT ''");
      addColumnIfMissing(connection, "teachers", "last_name", "TEXT NOT NULL DEFAULT ''");
      addColumnIfMissing(connection, "teachers", "studio_name", "TEXT NOT NULL DEFAULT ''");
      addColumnIfMissing(connection, "teachers", "city", "TEXT NOT NULL DEFAULT ''");
      addColumnIfMissing(connection, "teachers", "postal_code", "TEXT NOT NULL DEFAULT ''");
      addColumnIfMissing(connection, "teachers", "main_instrument", "TEXT NOT NULL DEFAULT ''");
      addColumnIfMissing(connection, "teachers", "other_instruments", "TEXT NOT NULL DEFAULT ''");
      addColumnIfMissing(connection, "teachers", "default_lesson_duration", "INTEGER NOT NULL DEFAULT 60");
      addColumnIfMissing(connection, "teachers", "default_lesson_price", "REAL NOT NULL DEFAULT 0");
      addColumnIfMissing(connection, "teachers", "currency", "TEXT NOT NULL DEFAULT 'CAD'");
      addColumnIfMissing(connection, "teachers", "profile_image_path", "TEXT NOT NULL DEFAULT ''");
      try (PreparedStatement statement = connection.prepareStatement(
            "UPDATE teachers SET first_name = CASE "
                  + "WHEN first_name = '' AND instr(name, ' ') > 0 THEN substr(name, 1, instr(name, ' ') - 1) "
                  + "WHEN first_name = '' THEN name ELSE first_name END, "
                  + "last_name = CASE "
                  + "WHEN last_name = '' AND instr(name, ' ') > 0 THEN substr(name, instr(name, ' ') + 1) "
                  + "ELSE last_name END")) {
         statement.executeUpdate();
      }
   }

   private void addNoteReviewColumns(Connection connection) throws SQLException {
      addColumnIfMissing(connection, "notes", "created_date", "TEXT");
      addColumnIfMissing(connection, "notes", "target_course_id", "INTEGER");
      addColumnIfMissing(connection, "notes", "reviewed_date", "TEXT");
      addColumnIfMissing(connection, "notes", "review_history", "TEXT NOT NULL DEFAULT ''");
   }

   private void runMigration(Connection connection, int version, Migration migration) throws SQLException {
      if (isMigrationApplied(connection, version)) {
         return;
      }

      boolean originalAutoCommit = connection.getAutoCommit();
      connection.setAutoCommit(false);
      try {
         migration.apply(connection);
         try (PreparedStatement statement = connection.prepareStatement(
               "INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)")) {
            statement.setInt(1, version);
            statement.setString(2, LocalDateTime.now().toString());
            statement.executeUpdate();
         }
         connection.commit();
      } catch (SQLException exception) {
         connection.rollback();
         throw exception;
      } finally {
         connection.setAutoCommit(originalAutoCommit);
      }
   }

   private boolean isMigrationApplied(Connection connection, int version) throws SQLException {
      try (PreparedStatement statement = connection.prepareStatement(
            "SELECT 1 FROM schema_migrations WHERE version = ?")) {
         statement.setInt(1, version);
         try (ResultSet resultSet = statement.executeQuery()) {
            return resultSet.next();
         }
      }
   }

   @FunctionalInterface
   private interface Migration {
      void apply(Connection connection) throws SQLException;
   }

   private void addColumnIfMissing(Connection connection, String tableName, String columnName, String columnDefinition)
         throws SQLException {
      try (Statement statement = connection.createStatement();
           java.sql.ResultSet columns = statement.executeQuery("PRAGMA table_info(" + tableName + ")")) {
         while (columns.next()) {
            if (columnName.equals(columns.getString("name"))) {
               return;
            }
         }
      }

      try (Statement statement = connection.createStatement()) {
         statement.execute("ALTER TABLE " + tableName + " ADD COLUMN " + columnName + " " + columnDefinition);
      }
   }
}
