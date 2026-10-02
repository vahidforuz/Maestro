package com.maestro.database;

import java.sql.SQLException;

public class TransactionManager {
   private final SQLiteDatabaseProvider databaseProvider;

   public TransactionManager(SQLiteDatabaseProvider databaseProvider) {
      this.databaseProvider = databaseProvider;
   }

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

   @FunctionalInterface
   public interface TransactionWork {
      void run() throws Exception;
   }
}
