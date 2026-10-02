package com.maestro.repository;

import com.maestro.model.Student;
import java.util.List;
import java.util.Optional;

public interface StudentRepository {
   Student save(Student student);

   Optional<Student> findById(int id);

   List<Student> findAll();

   void update(Student student);

   void deleteById(int id);
}
