package com.maestro.repository.sqlite;

import com.maestro.database.DatabaseProvider;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

abstract class SQLiteRepositorySupport {
   protected final DatabaseProvider databaseProvider;

   SQLiteRepositorySupport(DatabaseProvider databaseProvider) {
      this.databaseProvider = databaseProvider;
   }

   protected Connection getConnection() throws SQLException {
      return databaseProvider.getConnection();
   }

   protected void releaseConnection(Connection connection) throws SQLException {
      databaseProvider.releaseConnection(connection);
   }

   protected int generatedId(Statement statement) throws SQLException {
      try (ResultSet keys = statement.getGeneratedKeys()) {
         return keys.next() ? keys.getInt(1) : 0;
      }
   }
}
