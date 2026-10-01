package com.maestro.service;

import com.maestro.model.Teacher;
import com.maestro.model.Status;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

public class TeacherServiceImpl implements TeacherService{

   private static final Path TEACHERS_FILE = Path.of("data", "teachers.tsv");
   private final List<Teacher> teachers = new ArrayList<>();

   public TeacherServiceImpl() {
      loadTeachers();
   }
   
   @Override
   public void addTeacher(Teacher teacher){
      teachers.add(teacher);
      saveTeachers();
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
      boolean removed = teachers.remove(teacher);
      if (removed) {
         saveTeachers();
      }
      return removed;
   }

   @Override
   public void deactivateTeacher(int id){
      Teacher teacher = findTeacherById(id);
      if(teacher != null){
         teacher.setStatus(Status.INACTIVE);
         saveTeachers();
      }
   }

   private void loadTeachers() {
      if (!Files.exists(TEACHERS_FILE)) {
         return;
      }

      try {
         List<String> lines = Files.readAllLines(TEACHERS_FILE, StandardCharsets.UTF_8);
         for (String line : lines) {
            if (line.isBlank()) {
               continue;
            }

            String[] values = line.split("\t", -1);
            if (values.length < 6) {
               continue;
            }

            Teacher teacher = new Teacher(
                  Integer.parseInt(values[0]),
                  unescape(values[1]),
                  unescape(values[2]),
                  unescape(values[3]),
                  unescape(values[4]));
            teacher.setStatus(Status.valueOf(values[5]));
            teachers.add(teacher);
         }
      } catch (IOException | IllegalArgumentException exception) {
         throw new IllegalStateException("Could not load teachers from " + TEACHERS_FILE, exception);
      }
   }

   private void saveTeachers() {
      List<String> lines = new ArrayList<>();
      for (Teacher teacher : teachers) {
         lines.add(teacher.getId()
               + "\t" + escape(teacher.getName())
               + "\t" + escape(teacher.getTelephone())
               + "\t" + escape(teacher.getEmail())
               + "\t" + escape(teacher.getAddress())
               + "\t" + teacher.getStatus());
      }

      try {
         Files.createDirectories(TEACHERS_FILE.getParent());
         Files.write(TEACHERS_FILE, lines, StandardCharsets.UTF_8);
      } catch (IOException exception) {
         throw new IllegalStateException("Could not save teachers to " + TEACHERS_FILE, exception);
      }
   }

   private String escape(String value) {
      if (value == null) {
         return "";
      }

      return value
            .replace("\\", "\\\\")
            .replace("\t", "\\t")
            .replace("\n", "\\n")
            .replace("\r", "\\r");
   }

   private String unescape(String value) {
      StringBuilder result = new StringBuilder();
      boolean escaping = false;

      for (int i = 0; i < value.length(); i++) {
         char character = value.charAt(i);
         if (escaping) {
            switch (character) {
               case 't':
                  result.append('\t');
                  break;
               case 'n':
                  result.append('\n');
                  break;
               case 'r':
                  result.append('\r');
                  break;
               default:
                  result.append(character);
                  break;
            }
            escaping = false;
         } else if (character == '\\') {
            escaping = true;
         } else {
            result.append(character);
         }
      }

      if (escaping) {
         result.append('\\');
      }

      return result.toString();
   }
}
