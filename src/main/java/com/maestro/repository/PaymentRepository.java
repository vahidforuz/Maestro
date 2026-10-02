package com.maestro.repository;

import com.maestro.model.Payment;
import com.maestro.model.Student;
import java.util.List;

public interface PaymentRepository {
   Payment save(Payment payment);

   List<Payment> findAll();

   List<Payment> findByStudent(Student student);

   void deleteById(int id);
}
