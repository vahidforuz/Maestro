package com.maestro.service;

import com.maestro.model.Student;
import com.maestro.repository.StudentRepository;
import java.util.ArrayList;
import java.util.List;

public class StudentServiceImpl implements StudentService {
   private final StudentRepository studentRepository;
   private final List<Student> students = new ArrayList<>();

   public StudentServiceImpl(StudentRepository studentRepository) {
      this.studentRepository = studentRepository;
      students.addAll(studentRepository.findAll());
   }

   @Override
   public void addStudent(Student student) {
      studentRepository.save(student);
      students.add(student);
   }

   @Override
   public List<Student> getAllStudents() {
      return new ArrayList<>(students);
   }

   @Override
   public Student findStudentById(int id) {
      for (Student student : students) {
         if (student.getId() == id) {
            return student;
         }
      }

      return studentRepository.findById(id).orElse(null);
   }

   @Override
   public void saveStudents() {
      for (Student student : students) {
         studentRepository.update(student);
      }
   }
}
