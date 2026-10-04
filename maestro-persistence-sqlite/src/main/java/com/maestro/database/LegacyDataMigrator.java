package com.maestro.database;

import com.maestro.model.Payment;
import com.maestro.model.Status;
import com.maestro.model.Student;
import com.maestro.model.Teacher;
import com.maestro.repository.PaymentRepository;
import com.maestro.repository.StudentRepository;
import com.maestro.repository.TeacherRepository;
import com.maestro.repository.TransactionManager;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.List;

public class LegacyDataMigrator {
   private final Path teachersFile;
   private final Path studentsFile;
   private final Path paymentsFile;
   private final DatabaseProvider databaseProvider;
   private final TransactionManager transactionManager;
   private final TeacherRepository teacherRepository;
   private final StudentRepository studentRepository;
   private final PaymentRepository paymentRepository;

   public LegacyDataMigrator(
         DatabaseProvider databaseProvider,
         TransactionManager transactionManager,
         TeacherRepository teacherRepository,
         StudentRepository studentRepository,
         PaymentRepository paymentRepository) {
      this(
            databaseProvider,
            transactionManager,
            teacherRepository,
            studentRepository,
            paymentRepository,
            Path.of("data", "teachers.tsv"),
            Path.of("data", "students.ser"),
            Path.of("data", "payments.tsv"));
   }

   public LegacyDataMigrator(
         DatabaseProvider databaseProvider,
         TransactionManager transactionManager,
         TeacherRepository teacherRepository,
         StudentRepository studentRepository,
         PaymentRepository paymentRepository,
         Path teachersFile,
         Path studentsFile,
         Path paymentsFile) {
      this.teachersFile = teachersFile;
      this.studentsFile = studentsFile;
      this.paymentsFile = paymentsFile;
      this.databaseProvider = databaseProvider;
      this.transactionManager = transactionManager;
      this.teacherRepository = teacherRepository;
      this.studentRepository = studentRepository;
      this.paymentRepository = paymentRepository;
   }

   public void migrateIfNeeded() {
      migrateTeachers();
      migrateStudents();
      migratePayments();
   }

   private void migrateTeachers() {
      if (!Files.exists(teachersFile) || wasMigrated("teachers.tsv")) {
         return;
      }

      transactionManager.runInTransaction(() -> {
         for (String line : Files.readAllLines(teachersFile, StandardCharsets.UTF_8)) {
            if (line.isBlank()) {
               continue;
            }

            String[] values = line.split("\t", -1);
            if (values.length < 6) {
               continue;
            }

            Teacher teacher = new Teacher(
                  Integer.parseInt(values[0]),
                  unescape(values[1]),
                  unescape(values[2]),
                  unescape(values[3]),
                  unescape(values[4]));
            teacher.setStatus(Status.valueOf(values[5]));
            teacherRepository.save(teacher);
         }
         markMigrated("teachers.tsv");
      });
   }

   @SuppressWarnings("unchecked")
   private void migrateStudents() {
      if (!Files.exists(studentsFile) || wasMigrated("students.ser")) {
         return;
      }

      transactionManager.runInTransaction(() -> {
         try (ObjectInputStream input = new ObjectInputStream(Files.newInputStream(studentsFile))) {
            Object savedStudents = input.readObject();
            if (savedStudents instanceof List<?>) {
               for (Student student : (List<Student>) savedStudents) {
                  student.ensureEntityIds();
                  if (student.getTeacherId() != null && teacherRepository.findById(student.getTeacherId()).isEmpty()) {
                     student.setTeacherId(null);
                  }
                  studentRepository.save(student);
               }
            }
         }
         markMigrated("students.ser");
      });
   }

   private void migratePayments() {
      if (!Files.exists(paymentsFile) || wasMigrated("payments.tsv")) {
         return;
      }

      transactionManager.runInTransaction(() -> {
         for (String line : Files.readAllLines(paymentsFile, StandardCharsets.UTF_8)) {
            if (line.isBlank()) {
               continue;
            }

            String[] values = line.split("\t", -1);
            if (values.length < 5) {
               continue;
            }

            int studentId = Integer.parseInt(values[0]);
            Student student = studentRepository.findById(studentId).orElse(null);
            if (student == null) {
               continue;
            }

            paymentRepository.save(new Payment(
                  student,
                  Double.parseDouble(values[1]),
                  values[2].isBlank() ? null : LocalDate.parse(values[2]),
                  unescape(values[3]),
                  unescape(values[4])));
         }
         markMigrated("payments.tsv");
      });
   }

   private boolean wasMigrated(String source) {
      Connection connection = null;
      try {
         connection = databaseProvider.getConnection();
         try (PreparedStatement statement = connection.prepareStatement(
               "SELECT 1 FROM legacy_migrations WHERE source = ?")) {
            statement.setString(1, source);
            try (ResultSet resultSet = statement.executeQuery()) {
               return resultSet.next();
            }
         }
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not check legacy migration status", exception);
      } finally {
         close(connection);
      }
   }

   private void markMigrated(String source) throws SQLException {
      Connection connection = databaseProvider.getConnection();
      try (PreparedStatement statement = connection.prepareStatement(
            "INSERT OR REPLACE INTO legacy_migrations (source, migrated_at) VALUES (?, ?)")) {
         statement.setString(1, source);
         statement.setString(2, LocalDate.now().toString());
         statement.executeUpdate();
      }
   }

   private String unescape(String value) {
      StringBuilder result = new StringBuilder();
      boolean escaping = false;

      for (int i = 0; i < value.length(); i++) {
         char character = value.charAt(i);
         if (escaping) {
            switch (character) {
               case 't':
                  result.append('\t');
                  break;
               case 'n':
                  result.append('\n');
                  break;
               case 'r':
                  result.append('\r');
                  break;
               default:
                  result.append(character);
                  break;
            }
            escaping = false;
         } else if (character == '\\') {
            escaping = true;
         } else {
            result.append(character);
         }
      }

      if (escaping) {
         result.append('\\');
      }
      return result.toString();
   }

   private void close(Connection connection) {
      try {
         databaseProvider.releaseConnection(connection);
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not close legacy migrator connection", exception);
      }
   }
}
