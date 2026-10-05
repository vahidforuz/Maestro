package com.maestro.service;

import com.maestro.model.Teacher;
import com.maestro.model.Instrument;
import java.util.List;

public interface TeacherService {

   void addTeacher(Teacher teacher);

   List<Teacher> getAllTeachers();

   Teacher findTeacherById(int id);
  
//   public List<Teacher> getActiveTeachers();

   // List<Teacher> findTeachersByName(String name);

   // void updateTeacher(Teacher teacher);
   void updateTeacher(Teacher teacher);

   boolean deleteTeacherById(int id);

   boolean teacherExists(int id);

   // Optional later:

   // List<Teacher> findTeachersByInstrument(Instrument instrument);

   // void activateTeacher(int id);

   void deactivateTeacher(int id);
}
