package com.maestro.repository;

public interface TransactionManager {
   void runInTransaction(TransactionWork work);

   @FunctionalInterface
   interface TransactionWork {
      void run() throws Exception;
   }
}
