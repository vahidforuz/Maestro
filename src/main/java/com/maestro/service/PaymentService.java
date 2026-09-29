package com.maestro.service;

  import com.maestro.model.Payment;
  import com.maestro.model.Student;
  import java.util.List;

  public interface PaymentService {

    void addPayment(Payment payment);

    List<Payment> getAllPayments();

    List<Payment> getPaymentsByStudent(Student student);

    double getTotalPaidByStudent(Student student);
  }
