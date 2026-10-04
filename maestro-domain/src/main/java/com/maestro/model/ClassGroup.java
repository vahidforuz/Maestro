
package com.maestro.model;

import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.List;

public class ClassGroup {
   private Course course;
   private Teacher teacher;
   private DayOfWeek date;
   private LocalTime hour;
   private int credits;
   private List<Student> students;
   private int capacity;

   public ClassGroup(Course course, Teacher teacher, DayOfWeek date, LocalTime hour,
                    int credits, List<Student> students, int capacity) {
      this.course = course;
      this.teacher = teacher;
      this.date = date;
      this.hour = hour;
      this.credits = credits;
      this.students = students;
      this.capacity = capacity;
   }

   public Course getCourse() {
      return course;
   }

   public void setCourse(Course course) {
      this.course = course;
   }

   public Teacher getTeacher() {
      return teacher;
   }

   public void setTeacher(Teacher teacher) {
      this.teacher = teacher;
   }

   public DayOfWeek getDate() {
      return date;
   }
   public void setDate(DayOfWeek date) {
      this.date = date;
   }

   public LocalTime getHour() {
      return hour;
   }

   public void setHour(LocalTime hour) {
      this.hour = hour;
   }
   public int getCredits() {
      return credits;
   }

   public void setCredits(int credits) {
      this.credits = credits;
   }

   public List<Student> getStudents() {
      return students;
   }

   public void setStudents(List<Student> students) {
      this.students = students;
   }

   public int getCapacity() {
      return capacity;
   }

   public void setCapacity(int capacity) {
      this.capacity = capacity;
   }
   
   
}
