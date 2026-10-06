package com.maestro.service;

import com.maestro.model.CourseNote;
import com.maestro.model.LessonStatus;
import com.maestro.model.ReviewStatus;
import com.maestro.model.Student;
import com.maestro.model.StudentCourse;
import com.maestro.repository.StudentRepository;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public class ReviewServiceImpl implements ReviewService {
   private final StudentRepository studentRepository;

   public ReviewServiceImpl(StudentRepository studentRepository) {
      this.studentRepository = studentRepository;
   }

   @Override
   public List<DueReview> getDueReviews(Student student, StudentCourse currentCourse) {
      LocalDate currentCourseDate = currentCourse.getDate();
      if (currentCourseDate == null || currentCourse.getStatus() == LessonStatus.CANCELED) {
         return List.of();
      }

      List<DueReview> dueReviews = new ArrayList<>();
      for (StudentCourse sourceCourse : student.getCourses()) {
         if (sourceCourse.getId() == currentCourse.getId()) {
            continue;
         }

         for (CourseNote note : sourceCourse.getNotes()) {
            if (isDue(note, currentCourse, currentCourseDate)) {
               dueReviews.add(new DueReview(note, sourceCourse, sourceCourse.getDate()));
            }
         }
      }

      dueReviews.sort(Comparator
            .comparing((DueReview review) -> review.note().getReviewDate())
            .thenComparing(review -> review.sourceCourseDate() == null ? LocalDate.MIN : review.sourceCourseDate()));
      return dueReviews;
   }

   @Override
   public CourseNote acceptReview(Student student, StudentCourse currentCourse, CourseNote reviewNote) {
      reviewNote.markReviewed(currentCourse.getId(), currentCourse.getDate());
      studentRepository.update(student);
      return reviewNote;
   }

   @Override
   public void dismissReview(Student student, CourseNote reviewNote) {
      reviewNote.setReviewStatus(ReviewStatus.DISMISSED);
      studentRepository.update(student);
   }

   @Override
   public void rescheduleReview(Student student, StudentCourse currentCourse, CourseNote reviewNote) {
      StudentCourse nextCourse = findNextCourse(student, currentCourse);
      if (nextCourse == null) {
         LocalDate currentDate = currentCourse.getDate();
         reviewNote.setReviewSchedule(1, currentDate);
      } else {
         reviewNote.setReviewSchedule(1, nextCourse.getDate(), nextCourse.getId());
      }
      reviewNote.appendReviewHistory("Course " + currentCourse.getId() + " - Rescheduled");
      studentRepository.update(student);
   }

   private boolean isDue(CourseNote note, StudentCourse currentCourse, LocalDate currentCourseDate) {
      if (note.getReviewStatus() != ReviewStatus.PENDING) {
         return false;
      }
      if (note.getTargetCourseId() != null) {
         return note.getTargetCourseId() == currentCourse.getId();
      }
      return note.getReviewDate() != null
            && !note.getReviewDate().isAfter(currentCourseDate);
   }

   private StudentCourse findNextCourse(Student student, StudentCourse currentCourse) {
      return student.getCourses().stream()
            .filter(course -> course.getId() != currentCourse.getId())
            .filter(course -> course.getDate() != null && currentCourse.getDate() != null
                  && course.getDate().isAfter(currentCourse.getDate()))
            .min(Comparator.comparing(StudentCourse::getDate))
            .orElse(null);
   }
}
