package com.maestro.service;

import java.util.ArrayList;
import java.util.List;

import com.maestro.model.Student;
import com.maestro.model.Teacher;


public class StudentServiceImpl implements StudentService{
   private final List<Student> students = new ArrayList<>();
   
   @Override
   public void addStudent(Student student){
      students.add(student);
   }

   @Override
   public List<Student> getAllStudents(){
      return new ArrayList<>(students);
   }
   

}
