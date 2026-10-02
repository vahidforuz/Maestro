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
            if (isDue(note, currentCourseDate)) {
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
      CourseNote copiedNote = currentCourse.addNote(reviewNote.getPiece());
      copiedNote.setComment(reviewNote.getComment());
      copiedNote.setSourceCourseId(currentCourse.getId());

      reviewNote.setReviewStatus(ReviewStatus.ACCEPTED);
      reviewNote.setAcceptedCourseId(currentCourse.getId());
      studentRepository.update(student);
      return copiedNote;
   }

   @Override
   public void dismissReview(Student student, CourseNote reviewNote) {
      reviewNote.setReviewStatus(ReviewStatus.DISMISSED);
      studentRepository.update(student);
   }

   private boolean isDue(CourseNote note, LocalDate currentCourseDate) {
      return note.getReviewDate() != null
            && note.getReviewStatus() == ReviewStatus.PENDING
            && !note.getReviewDate().isAfter(currentCourseDate);
   }
}
