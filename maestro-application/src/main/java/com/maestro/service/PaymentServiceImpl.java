package com.maestro.service;

import com.maestro.model.Payment;
import com.maestro.model.Student;
import com.maestro.model.StudentProject;
import com.maestro.repository.PaymentRepository;
import com.maestro.repository.StudentRepository;
import com.maestro.repository.TransactionManager;
import java.util.ArrayList;
import java.util.List;

public class PaymentServiceImpl implements PaymentService {
   private final PaymentRepository paymentRepository;
   private final StudentRepository studentRepository;
   private final TransactionManager transactionManager;
   private final List<Payment> payments = new ArrayList<>();

   public PaymentServiceImpl(
         PaymentRepository paymentRepository,
         StudentRepository studentRepository,
         TransactionManager transactionManager) {
      this.paymentRepository = paymentRepository;
      this.studentRepository = studentRepository;
      this.transactionManager = transactionManager;
      payments.addAll(paymentRepository.findAll());
   }

   @Override
   public void addPayment(Payment payment) {
      addPayment(payment, payment.getStudent().getCurrentProject());
   }

   @Override
   public void addPayment(Payment payment, StudentProject project) {
      transactionManager.runInTransaction(() -> {
         paymentRepository.save(payment);
         createCoursesCoveredByPayment(payment, project);
         studentRepository.update(payment.getStudent());
      });
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

   private void createCoursesCoveredByPayment(Payment payment, StudentProject project) {
      Student student = payment.getStudent();
      if (student == null || project == null) {
         return;
      }

      double coursePrice = student.getCoursePrice();
      if (coursePrice <= 0) {
         student.setPaymentCreditBalance(student.getPaymentCreditBalance() + payment.getAmount());
         return;
      }

      double availableCredit = student.getPaymentCreditBalance() + payment.getAmount();
      int paidCourseCount = (int) Math.floor(availableCredit / coursePrice);
      int existingUnpaidCourses = Math.max(0, project.getCourses().size() - project.getPaidCourseCount());
      int coursesToCreate = Math.max(0, paidCourseCount - existingUnpaidCourses);
      double remainingCredit = availableCredit - (paidCourseCount * coursePrice);

      student.addPaidCoursesToProject(project, coursesToCreate);
      project.addPaidCourseCount(paidCourseCount);
      student.setPaymentCreditBalance(roundCurrency(remainingCredit));
   }

   private double roundCurrency(double value) {
      return Math.round(value * 100.0) / 100.0;
   }
}
