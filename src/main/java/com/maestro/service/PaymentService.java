package com.maestro.service;

  import com.maestro.model.Payment;
  import com.maestro.model.Student;
  import com.maestro.model.StudentProject;
  import java.util.List;

  public interface PaymentService {

    void addPayment(Payment payment);

    void addPayment(Payment payment, StudentProject project);

    List<Payment> getAllPayments();

    List<Payment> getPaymentsByStudent(Student student);

    double getTotalPaidByStudent(Student student);
  }
