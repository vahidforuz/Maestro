package com.maestro.service;

import com.maestro.model.Teacher;
import com.maestro.model.Status;
import java.util.ArrayList;
import java.util.List;

public class TeacherServiceImpl implements TeacherService{

   private final List<Teacher> teachers = new ArrayList<>();

   @Override
   public void addTeacher(Teacher teacher){
      teachers.add(teacher);
   }

   @Override
   public List<Teacher> getAllTeachers(){
      return new ArrayList<>(teachers);
   }
   
   @Override
   public boolean teacherExists(int id){
      for (Teacher teacher : teachers){
         if (teacher.getId() == id){
            return true;
         }
      }
      return false;
   }

   /*
   @Override
   public Teacher findTeacherById(int id){
      for(Teacher teacher : teachers){
         if(teacher.getId() == id ){
            return teacher;
         }
      }
      return null;
   }
   */

   @Override
   public Teacher findTeacherById(int id){
      return teachers.stream()
      .filter(teacher -> teacher.getId() == id)
      .findFirst()
      .orElse(null);
   }

   @Override
   public boolean deleteTeacherById(int id){
      Teacher teacher = findTeacherById(id);
      if(teacher == null){
         return false;
      }
      return teachers.remove(teacher);
   }

   @Override
   public void deactivateTeacher(int id){
      Teacher teacher = findTeacherById(id);
      if(teacher != null){
         teacher.setStatus(Status.INACTIVE);
      }
   }
}
