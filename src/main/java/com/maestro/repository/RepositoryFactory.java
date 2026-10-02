package com.maestro.repository;

import com.maestro.database.TransactionManager;

public interface RepositoryFactory {
   StudentRepository students();

   TeacherRepository teachers();

   PaymentRepository payments();

   ProjectRepository projects();

   CourseRepository courses();

   NoteRepository notes();

   PieceRepository pieces();

   TransactionManager transactionManager();
}
