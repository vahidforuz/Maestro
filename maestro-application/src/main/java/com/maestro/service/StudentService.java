package com.maestro.service;

import com.maestro.model.Student;
import java.util.List;

public interface StudentService {

  void addStudent(Student student);

  List<Student> getAllStudents();

  Student findStudentById(int id);

  void saveStudents();
/*
  Student findStudentById(int id);

  List<Student> findStudentsByName(String name);

  void updateStudent(Student student);

  boolean deleteStudentById(int id);

  boolean studentExists(int id);

  List<Student> getActiveStudents();

  void activateStudent(int id);

  void deactivateStudent(int id);
   */
}
