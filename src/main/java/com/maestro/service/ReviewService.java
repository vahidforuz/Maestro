package com.maestro.service;

import com.maestro.model.CourseNote;
import com.maestro.model.Student;
import com.maestro.model.StudentCourse;
import java.time.LocalDate;
import java.util.List;

public interface ReviewService {
   List<DueReview> getDueReviews(Student student, StudentCourse currentCourse);

   CourseNote acceptReview(Student student, StudentCourse currentCourse, CourseNote reviewNote);

   void dismissReview(Student student, CourseNote reviewNote);

   record DueReview(CourseNote note, StudentCourse sourceCourse, LocalDate sourceCourseDate) {
   }
}
