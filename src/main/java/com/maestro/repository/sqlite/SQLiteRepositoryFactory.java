package com.maestro.repository.sqlite;

import com.maestro.database.SQLiteDatabaseProvider;
import com.maestro.database.TransactionManager;
import com.maestro.repository.CourseRepository;
import com.maestro.repository.NoteRepository;
import com.maestro.repository.PaymentRepository;
import com.maestro.repository.PieceRepository;
import com.maestro.repository.ProjectRepository;
import com.maestro.repository.RepositoryFactory;
import com.maestro.repository.StudentRepository;
import com.maestro.repository.TeacherRepository;

public class SQLiteRepositoryFactory implements RepositoryFactory {
   private final TransactionManager transactionManager;
   private final StudentRepository studentRepository;
   private final TeacherRepository teacherRepository;
   private final PaymentRepository paymentRepository;
   private final ProjectRepository projectRepository;
   private final CourseRepository courseRepository;
   private final NoteRepository noteRepository;
   private final PieceRepository pieceRepository;

   public SQLiteRepositoryFactory(SQLiteDatabaseProvider databaseProvider) {
      this.transactionManager = new TransactionManager(databaseProvider);
      this.studentRepository = new SQLiteStudentRepository(databaseProvider);
      this.teacherRepository = new SQLiteTeacherRepository(databaseProvider);
      this.paymentRepository = new SQLitePaymentRepository(databaseProvider, studentRepository);
      this.projectRepository = new SQLiteProjectRepository(databaseProvider);
      this.courseRepository = new SQLiteCourseRepository(databaseProvider);
      this.noteRepository = new SQLiteNoteRepository(databaseProvider);
      this.pieceRepository = new SQLitePieceRepository(databaseProvider);
   }

   @Override
   public StudentRepository students() {
      return studentRepository;
   }

   @Override
   public TeacherRepository teachers() {
      return teacherRepository;
   }

   @Override
   public PaymentRepository payments() {
      return paymentRepository;
   }

   @Override
   public ProjectRepository projects() {
      return projectRepository;
   }

   @Override
   public CourseRepository courses() {
      return courseRepository;
   }

   @Override
   public NoteRepository notes() {
      return noteRepository;
   }

   @Override
   public PieceRepository pieces() {
      return pieceRepository;
   }

   @Override
   public TransactionManager transactionManager() {
      return transactionManager;
   }
}
