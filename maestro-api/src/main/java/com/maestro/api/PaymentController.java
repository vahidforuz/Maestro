package com.maestro.api;

import com.maestro.model.Payment;
import com.maestro.model.Student;
import com.maestro.service.PaymentService;
import com.maestro.service.StudentService;
import java.time.LocalDate;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api")
public class PaymentController {
   private final PaymentService paymentService;
   private final StudentService studentService;

   public PaymentController(PaymentService paymentService, StudentService studentService) {
      this.paymentService = paymentService;
      this.studentService = studentService;
   }

   @GetMapping("/payments")
   public List<Payment> findAll() {
      return paymentService.getAllPayments();
   }

   @GetMapping("/students/{studentId}/payments")
   public List<Payment> findByStudent(@PathVariable("studentId") int studentId) {
      return paymentService.getPaymentsByStudent(requireStudent(studentId));
   }

   @PostMapping("/students/{studentId}/payments")
   @ResponseStatus(HttpStatus.CREATED)
   public Payment create(@PathVariable("studentId") int studentId, @RequestBody PaymentRequest request) {
      Student student = requireStudent(studentId);
      Payment payment = new Payment(student, request.amount(), request.paymentDate(), request.method(), request.note());
      paymentService.addPayment(payment);
      return payment;
   }

   private Student requireStudent(int studentId) {
      Student student = studentService.findStudentById(studentId);
      if (student == null) {
         throw new ResponseStatusException(HttpStatus.NOT_FOUND);
      }
      return student;
   }

   public record PaymentRequest(double amount, LocalDate paymentDate, String method, String note) {
   }
}
