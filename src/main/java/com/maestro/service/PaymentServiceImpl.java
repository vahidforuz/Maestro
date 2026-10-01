package com.maestro.service;

import com.maestro.model.Payment;
import com.maestro.model.Student;
import java.util.ArrayList;
import java.util.List;

public class PaymentServiceImpl implements PaymentService {
   private final List<Payment> payments = new ArrayList<>();

   @Override
   public void addPayment(Payment payment) {
      payments.add(payment);
   }

   @Override
   public List<Payment> getAllPayments() {
      return new ArrayList<>(payments);
   }

   @Override
   public List<Payment> getPaymentsByStudent(Student student) {
      List<Payment> studentPayments = new ArrayList<>();
      for (Payment payment : payments) {
         if (isSameStudent(payment.getStudent(), student)) {
            studentPayments.add(payment);
         }
      }

      return studentPayments;
   }

   @Override
   public double getTotalPaidByStudent(Student student) {
      double total = 0;
      for (Payment payment : getPaymentsByStudent(student)) {
         total += payment.getAmount();
      }

      return total;
   }

   private boolean isSameStudent(Student first, Student second) {
      if (first == null || second == null) {
         return false;
      }

      if (first.getId() != 0 || second.getId() != 0) {
         return first.getId() == second.getId();
      }

      return first == second;
   }
}
