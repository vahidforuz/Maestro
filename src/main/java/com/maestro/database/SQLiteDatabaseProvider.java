package com.maestro.database;

import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;

public class SQLiteDatabaseProvider implements DatabaseProvider {
   private final String jdbcUrl;
   private final ThreadLocal<Connection> transactionConnection = new ThreadLocal<>();

   public SQLiteDatabaseProvider(Path databasePath) {
      this.jdbcUrl = "jdbc:sqlite:" + databasePath;
   }

   @Override
   public Connection getConnection() throws SQLException {
      Connection connection = transactionConnection.get();
      if (connection != null) {
         return connection;
      }

      Connection newConnection = DriverManager.getConnection(jdbcUrl);
      enableForeignKeys(newConnection);
      return newConnection;
   }

   @Override
   public void releaseConnection(Connection connection) throws SQLException {
      if (connection != null && connection != transactionConnection.get()) {
         connection.close();
      }
   }

   public void beginTransaction() throws SQLException {
      if (transactionConnection.get() != null) {
         return;
      }

      Connection connection = DriverManager.getConnection(jdbcUrl);
      enableForeignKeys(connection);
      connection.setAutoCommit(false);
      transactionConnection.set(connection);
   }

   public void commitTransaction() throws SQLException {
      Connection connection = transactionConnection.get();
      if (connection != null) {
         connection.commit();
      }
   }

   public void rollbackTransaction() throws SQLException {
      Connection connection = transactionConnection.get();
      if (connection != null) {
         connection.rollback();
      }
   }

   public void endTransaction() throws SQLException {
      Connection connection = transactionConnection.get();
      transactionConnection.remove();
      if (connection != null) {
         connection.setAutoCommit(true);
         connection.close();
      }
   }

   private void enableForeignKeys(Connection connection) throws SQLException {
      try (Statement statement = connection.createStatement()) {
         statement.execute("PRAGMA foreign_keys = ON");
      }
   }
}
