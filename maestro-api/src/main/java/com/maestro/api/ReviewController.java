package com.maestro.api;

import com.maestro.model.CourseNote;
import com.maestro.model.Student;
import com.maestro.model.StudentCourse;
import com.maestro.repository.StudentRepository;
import com.maestro.service.ReviewService;
import com.maestro.service.StudentService;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/students/{studentId}/reviews")
public class ReviewController {
   private final ReviewService reviewService;
   private final StudentService studentService;
   private final StudentRepository studentRepository;

   public ReviewController(
         ReviewService reviewService,
         StudentService studentService,
         StudentRepository studentRepository) {
      this.reviewService = reviewService;
      this.studentService = studentService;
      this.studentRepository = studentRepository;
   }

   @GetMapping("/due/{courseId}")
   public List<ReviewService.DueReview> dueReviews(
         @PathVariable("studentId") int studentId,
         @PathVariable("courseId") int courseId) {
      Student student = requireStudent(studentId);
      return reviewService.getDueReviews(student, requireCourse(student, courseId));
   }

   @PostMapping("/{noteId}/accept/{courseId}")
   public Student accept(
         @PathVariable("studentId") int studentId,
         @PathVariable("noteId") int noteId,
         @PathVariable("courseId") int courseId) {
      Student student = requireStudent(studentId);
      CourseNote note = requireNote(student, noteId);
      reviewService.acceptReview(student, requireCourse(student, courseId), note);
      studentRepository.update(student);
      return student;
   }

   @PostMapping("/{noteId}/dismiss")
   public Student dismiss(@PathVariable("studentId") int studentId, @PathVariable("noteId") int noteId) {
      Student student = requireStudent(studentId);
      reviewService.dismissReview(student, requireNote(student, noteId));
      studentRepository.update(student);
      return student;
   }

   @PostMapping("/{noteId}/reschedule/{courseId}")
   public Student reschedule(
         @PathVariable("studentId") int studentId,
         @PathVariable("noteId") int noteId,
         @PathVariable("courseId") int courseId) {
      Student student = requireStudent(studentId);
      reviewService.rescheduleReview(student, requireCourse(student, courseId), requireNote(student, noteId));
      studentRepository.update(student);
      return student;
   }

   private Student requireStudent(int studentId) {
      Student student = studentService.findStudentById(studentId);
      if (student == null) {
         throw new ResponseStatusException(HttpStatus.NOT_FOUND);
      }
      return student;
   }

   private StudentCourse requireCourse(Student student, int courseId) {
      StudentCourse course = student.findCourseById(courseId);
      if (course == null) {
         throw new ResponseStatusException(HttpStatus.NOT_FOUND);
      }
      return course;
   }

   private CourseNote requireNote(Student student, int noteId) {
      for (StudentCourse course : student.getCourses()) {
         for (CourseNote note : course.getNotes()) {
            if (note.getId() == noteId) {
               return note;
            }
         }
      }
      throw new ResponseStatusException(HttpStatus.NOT_FOUND);
   }
}
