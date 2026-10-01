package com.maestro.model;

import java.util.ArrayList;
import java.util.List;

public class StudentProject {
   private String name;
   private final List<StudentCourse> courses = new ArrayList<>();
   private final List<String> pieces = new ArrayList<>();

   public StudentProject(String name) {
      this.name = name;
   }

   public String getName() {
      return name;
   }

   public void setName(String name) {
      this.name = name;
   }

   public List<StudentCourse> getCourses() {
      return courses;
   }

   public List<String> getPieces() {
      return pieces;
   }

   public void addPiece(String piece) {
      pieces.add(piece == null ? "" : piece);
   }

   public void setPiece(int index, String piece) {
      String oldPiece = pieces.get(index);
      String newPiece = piece == null ? "" : piece;
      pieces.set(index, newPiece);
      for (StudentCourse course : courses) {
         for (CourseNote note : course.getNotes()) {
            if (oldPiece.equals(note.getPiece())) {
               note.setPiece(newPiece);
            }
         }
      }
   }

   public void removePiece(int index) {
      String removedPiece = pieces.remove(index);
      for (StudentCourse course : courses) {
         for (CourseNote note : course.getNotes()) {
            if (removedPiece.equals(note.getPiece())) {
               note.setPiece("");
            }
         }
      }
   }

   @Override
   public String toString() {
      return name;
   }
}
