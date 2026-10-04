package com.maestro.repository.sqlite;

import com.maestro.database.DatabaseProvider;
import com.maestro.model.Payment;
import com.maestro.model.Student;
import com.maestro.repository.PaymentRepository;
import com.maestro.repository.StudentRepository;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public class SQLitePaymentRepository extends SQLiteRepositorySupport implements PaymentRepository {
   private final StudentRepository studentRepository;

   public SQLitePaymentRepository(DatabaseProvider databaseProvider, StudentRepository studentRepository) {
      super(databaseProvider);
      this.studentRepository = studentRepository;
   }

   @Override
   public Payment save(Payment payment) {
      Connection connection = null;
      try {
         connection = getConnection();
         if (payment.getId() > 0) {
            try (PreparedStatement statement = connection.prepareStatement(
                  "INSERT OR REPLACE INTO payments (id, student_id, amount, payment_date, method, note) VALUES (?, ?, ?, ?, ?, ?)")) {
               bindPayment(statement, payment, true);
               statement.executeUpdate();
            }
         } else {
            try (PreparedStatement statement = connection.prepareStatement(
                  "INSERT INTO payments (student_id, amount, payment_date, method, note) VALUES (?, ?, ?, ?, ?)",
                  Statement.RETURN_GENERATED_KEYS)) {
               bindPayment(statement, payment, false);
               statement.executeUpdate();
               payment.setId(generatedId(statement));
            }
         }
         return payment;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not save payment", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public List<Payment> findAll() {
      Connection connection = null;
      try {
         connection = getConnection();
         List<Payment> payments = new ArrayList<>();
         try (PreparedStatement statement = connection.prepareStatement("SELECT * FROM payments ORDER BY id");
              ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
               payments.add(mapPayment(resultSet));
            }
         }
         return payments;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not load payments", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public List<Payment> findByStudent(Student student) {
      Connection connection = null;
      try {
         connection = getConnection();
         List<Payment> payments = new ArrayList<>();
         try (PreparedStatement statement = connection.prepareStatement(
               "SELECT * FROM payments WHERE student_id = ? ORDER BY id")) {
            statement.setInt(1, student.getId());
            try (ResultSet resultSet = statement.executeQuery()) {
               while (resultSet.next()) {
                  payments.add(mapPayment(resultSet, student));
               }
            }
         }
         return payments;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not load student payments", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public void deleteById(int id) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement("DELETE FROM payments WHERE id = ?")) {
            statement.setInt(1, id);
            statement.executeUpdate();
         }
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not delete payment", exception);
      } finally {
         close(connection);
      }
   }

   private void bindPayment(PreparedStatement statement, Payment payment, boolean includeId) throws SQLException {
      int offset = 0;
      if (includeId) {
         statement.setInt(1, payment.getId());
         offset = 1;
      }
      statement.setInt(1 + offset, payment.getStudent().getId());
      statement.setDouble(2 + offset, payment.getAmount());
      statement.setString(3 + offset, payment.getPaymentDate() == null ? null : payment.getPaymentDate().toString());
      statement.setString(4 + offset, payment.getMethod());
      statement.setString(5 + offset, payment.getNote());
   }

   private Payment mapPayment(ResultSet resultSet) throws SQLException {
      int studentId = resultSet.getInt("student_id");
      Student student = studentRepository.findById(studentId)
            .orElseThrow(() -> new IllegalStateException("Payment references missing student " + studentId));
      return mapPayment(resultSet, student);
   }

   private Payment mapPayment(ResultSet resultSet, Student student) throws SQLException {
      Payment payment = new Payment(
            student,
            resultSet.getDouble("amount"),
            dateValue(resultSet.getString("payment_date")),
            resultSet.getString("method"),
            resultSet.getString("note"));
      payment.setId(resultSet.getInt("id"));
      return payment;
   }

   private LocalDate dateValue(String value) {
      return value == null || value.isBlank() ? null : LocalDate.parse(value);
   }

   private void close(Connection connection) {
      try {
         releaseConnection(connection);
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not close payment repository connection", exception);
      }
   }
}
