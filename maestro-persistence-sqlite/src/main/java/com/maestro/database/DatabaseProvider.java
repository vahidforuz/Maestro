package com.maestro.database;

import java.sql.Connection;
import java.sql.SQLException;

public interface DatabaseProvider {
   Connection getConnection() throws SQLException;

   default void releaseConnection(Connection connection) throws SQLException {
      if (connection != null) {
         connection.close();
      }
   }
}
