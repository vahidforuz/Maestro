package com.maestro.service;

import com.maestro.model.Status;
import com.maestro.model.Teacher;
import com.maestro.repository.TeacherRepository;
import java.util.ArrayList;
import java.util.List;

public class TeacherServiceImpl implements TeacherService {
   private final TeacherRepository teacherRepository;
   private final List<Teacher> teachers = new ArrayList<>();

   public TeacherServiceImpl(TeacherRepository teacherRepository) {
      this.teacherRepository = teacherRepository;
      teachers.addAll(teacherRepository.findAll());
   }

   @Override
   public void addTeacher(Teacher teacher) {
      teacherRepository.save(teacher);
      teachers.add(teacher);
   }

   @Override
   public List<Teacher> getAllTeachers() {
      return new ArrayList<>(teachers);
   }

   @Override
   public boolean teacherExists(int id) {
      return findTeacherById(id) != null;
   }

   @Override
   public Teacher findTeacherById(int id) {
      for (Teacher teacher : teachers) {
         if (teacher.getId() == id) {
            return teacher;
         }
      }

      return teacherRepository.findById(id).orElse(null);
   }

   @Override
   public void updateTeacher(Teacher teacher) {
      teacherRepository.update(teacher);
      for (int index = 0; index < teachers.size(); index++) {
         if (teachers.get(index).getId() == teacher.getId()) {
            teachers.set(index, teacher);
            return;
         }
      }
      teachers.add(teacher);
   }

   @Override
   public boolean deleteTeacherById(int id) {
      Teacher teacher = findTeacherById(id);
      if (teacher == null) {
         return false;
      }

      teacherRepository.deleteById(id);
      return teachers.remove(teacher);
   }

   @Override
   public void deactivateTeacher(int id) {
      Teacher teacher = findTeacherById(id);
      if (teacher != null) {
         teacher.setStatus(Status.INACTIVE);
         teacherRepository.update(teacher);
      }
   }
}
