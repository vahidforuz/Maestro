package com.maestro.repository;

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
