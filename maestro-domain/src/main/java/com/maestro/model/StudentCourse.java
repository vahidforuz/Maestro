package com.maestro.model;

import java.io.Serializable;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

public class StudentCourse implements Serializable {
   private static final long serialVersionUID = 1L;

   private int id;
   private String title;
   private DayOfWeek day;
   private LocalDate date;
   private LocalTime hour;
   private double price;
   private LessonStatus status = LessonStatus.NOTHING;
   private String assignment = "";
   private String comment = "";
   private String homeworkNextLesson = "";
   private final List<CourseNote> notes = new ArrayList<>();

   public StudentCourse(String title, DayOfWeek day, LocalTime hour, double price) {
      this.title = title;
      this.day = day;
      this.hour = hour;
      this.price = price;
   }

   public StudentCourse(String title, DayOfWeek day, LocalDate date, LocalTime hour, double price) {
      this(title, day, hour, price);
      setDate(date);
   }

   public String getTitle() {
      return title;
   }

   public int getId() {
      return id;
   }

   public void setId(int id) {
      this.id = id;
   }

   public void setTitle(String title) {
      this.title = title;
   }

   public DayOfWeek getDay() {
      return day;
   }

   public void setDay(DayOfWeek day) {
      this.day = day;
   }

   public LocalDate getDate() {
      return date;
   }

   public void setDate(LocalDate date) {
      this.date = date;
      if (date != null) {
         this.day = date.getDayOfWeek();
      }
   }

   public LocalTime getHour() {
      return hour;
   }

   public void setHour(LocalTime hour) {
      this.hour = hour;
   }

   public double getPrice() {
      return price;
   }

   public void setPrice(double price) {
      this.price = price;
   }

   public LessonStatus getStatus() {
      return status;
   }

   public void setStatus(LessonStatus status) {
      this.status = status == null ? LessonStatus.NOTHING : status;
   }

   public String getAssignment() {
      return assignment;
   }

   public void setAssignment(String assignment) {
      this.assignment = assignment == null ? "" : assignment;
   }

   public String getComment() {
      return comment;
   }

   public void setComment(String comment) {
      this.comment = comment == null ? "" : comment;
   }

   public String getHomeworkNextLesson() {
      return homeworkNextLesson;
   }

   public void setHomeworkNextLesson(String homeworkNextLesson) {
      this.homeworkNextLesson = homeworkNextLesson == null ? "" : homeworkNextLesson;
   }

   public List<CourseNote> getNotes() {
      return notes;
   }

   public CourseNote addNote(String piece) {
      CourseNote note = new CourseNote(piece);
      note.setSourceCourseId(id);
      note.setCreatedDate(date);
      notes.add(note);
      return note;
   }

   public void removeNote(CourseNote note) {
      notes.remove(note);
   }
}
