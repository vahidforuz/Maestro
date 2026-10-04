package com.maestro.repository;

import com.maestro.model.Teacher;
import java.util.List;
import java.util.Optional;

public interface TeacherRepository {
   Teacher save(Teacher teacher);

   Optional<Teacher> findById(int id);

   List<Teacher> findAll();

   void update(Teacher teacher);

   void deleteById(int id);
}
