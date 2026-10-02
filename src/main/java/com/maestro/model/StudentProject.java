package com.maestro.model;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

public class StudentProject implements Serializable {
   private static final long serialVersionUID = 1L;

   private int id;
   private String name;
   private int paidCourseCount;
   private final List<StudentCourse> courses = new ArrayList<>();
   private final List<String> pieces = new ArrayList<>();

   public StudentProject(String name) {
      this.name = name;
   }

   public String getName() {
      return name;
   }

   public int getId() {
      return id;
   }

   public void setId(int id) {
      this.id = id;
   }

   public void setName(String name) {
      this.name = name;
   }

   public int getPaidCourseCount() {
      return paidCourseCount;
   }

   public void addPaidCourseCount(int paidCourseCount) {
      this.paidCourseCount += Math.max(0, paidCourseCount);
   }

   public void setPaidCourseCount(int paidCourseCount) {
      this.paidCourseCount = Math.max(0, paidCourseCount);
   }

   public List<StudentCourse> getCourses() {
      return courses;
   }

   public StudentCourse findCourseById(int courseId) {
      for (StudentCourse course : courses) {
         if (course.getId() == courseId) {
            return course;
         }
      }
      return null;
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
