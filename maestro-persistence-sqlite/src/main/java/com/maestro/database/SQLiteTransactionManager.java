package com.maestro.database;

import java.sql.SQLException;

public class SQLiteTransactionManager implements com.maestro.repository.TransactionManager {
   private final SQLiteDatabaseProvider databaseProvider;

   public SQLiteTransactionManager(SQLiteDatabaseProvider databaseProvider) {
      this.databaseProvider = databaseProvider;
   }

   @Override
   public void runInTransaction(TransactionWork work) {
      try {
         databaseProvider.beginTransaction();
         work.run();
         databaseProvider.commitTransaction();
      } catch (Exception exception) {
         try {
            databaseProvider.rollbackTransaction();
         } catch (SQLException rollbackException) {
            exception.addSuppressed(rollbackException);
         }
         throw new IllegalStateException("Database transaction failed", exception);
      } finally {
         try {
            databaseProvider.endTransaction();
         } catch (SQLException exception) {
            throw new IllegalStateException("Could not close database transaction", exception);
         }
      }
   }
}
