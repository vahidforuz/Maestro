package com.maestro.api;

import com.maestro.model.Instrument;
import com.maestro.model.CourseNote;
import com.maestro.model.LessonStatus;
import com.maestro.model.Level;
import com.maestro.model.Student;
import com.maestro.model.StudentCourse;
import com.maestro.model.StudentProject;
import com.maestro.repository.StudentRepository;
import com.maestro.service.StudentService;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/students")
public class StudentController {
   private final StudentService studentService;
   private final StudentRepository studentRepository;

   public StudentController(StudentService studentService, StudentRepository studentRepository) {
      this.studentService = studentService;
      this.studentRepository = studentRepository;
   }

   @GetMapping
   public List<Student> findAll() {
      return studentService.getAllStudents();
   }

   @GetMapping("/{id}")
   public Student findById(@PathVariable("id") int id) {
      Student student = studentService.findStudentById(id);
      if (student == null) {
         throw new ResponseStatusException(HttpStatus.NOT_FOUND);
      }
      return student;
   }

   @PostMapping
   @ResponseStatus(HttpStatus.CREATED)
   public Student create(@RequestBody StudentRequest request) {
      Student student = request.toStudent();
      student.setId(request.id() == null || request.id() <= 0 ? nextStudentId() : request.id());
      studentService.addStudent(student);
      return student;
   }

   @PutMapping("/{id}")
   public Student update(@PathVariable("id") int id, @RequestBody StudentRequest request) {
      if (studentRepository.findById(id).isEmpty()) {
         throw new ResponseStatusException(HttpStatus.NOT_FOUND);
      }
      Student student = request.toStudent();
      student.setId(id);
      studentRepository.update(student);
      return student;
   }

   @DeleteMapping("/{id}")
   @ResponseStatus(HttpStatus.NO_CONTENT)
   public void delete(@PathVariable("id") int id) {
      studentRepository.deleteById(id);
   }

   @PostMapping("/{id}/projects")
   @ResponseStatus(HttpStatus.CREATED)
   public Student addProject(@PathVariable("id") int id, @RequestBody ProjectRequest request) {
      Student student = requireStudent(id);
      StudentProject project = student.addProject();
      if (request.name() != null && !request.name().isBlank()) {
         project.setName(request.name().trim());
      }
      return save(student);
   }

   @PutMapping("/{id}/projects/{projectId}")
   public Student updateProject(
         @PathVariable("id") int id,
         @PathVariable("projectId") int projectId,
         @RequestBody ProjectRequest request) {
      Student student = requireStudent(id);
      StudentProject project = requireProject(student, projectId);
      if (request.name() != null && !request.name().isBlank()) {
         project.setName(request.name().trim());
      }
      return save(student);
   }

   @DeleteMapping("/{id}/projects/{projectId}")
   public Student deleteProject(@PathVariable("id") int id, @PathVariable("projectId") int projectId) {
      Student student = requireStudent(id);
      student.removeProject(requireProject(student, projectId));
      return save(student);
   }

   @PostMapping("/{id}/projects/{projectId}/pieces")
   @ResponseStatus(HttpStatus.CREATED)
   public Student addPiece(
         @PathVariable("id") int id,
         @PathVariable("projectId") int projectId,
         @RequestBody PieceRequest request) {
      Student student = requireStudent(id);
      requireProject(student, projectId).addPiece(request.title());
      return save(student);
   }

   @PutMapping("/{id}/projects/{projectId}/pieces/{pieceIndex}")
   public Student updatePiece(
         @PathVariable("id") int id,
         @PathVariable("projectId") int projectId,
         @PathVariable("pieceIndex") int pieceIndex,
         @RequestBody PieceRequest request) {
      Student student = requireStudent(id);
      StudentProject project = requireProject(student, projectId);
      requirePiece(project, pieceIndex);
      project.setPiece(pieceIndex, request.title());
      return save(student);
   }

   @DeleteMapping("/{id}/projects/{projectId}/pieces/{pieceIndex}")
   public Student deletePiece(
         @PathVariable("id") int id,
         @PathVariable("projectId") int projectId,
         @PathVariable("pieceIndex") int pieceIndex) {
      Student student = requireStudent(id);
      StudentProject project = requireProject(student, projectId);
      requirePiece(project, pieceIndex);
      project.removePiece(pieceIndex);
      return save(student);
   }

   @PostMapping("/{id}/projects/{projectId}/courses")
   @ResponseStatus(HttpStatus.CREATED)
   public Student addCourse(@PathVariable("id") int id, @PathVariable("projectId") int projectId) {
      Student student = requireStudent(id);
      student.addCourseToProject(requireProject(student, projectId));
      return save(student);
   }

   @PutMapping("/{id}/projects/{projectId}/courses/{courseId}")
   public Student updateCourse(
         @PathVariable("id") int id,
         @PathVariable("projectId") int projectId,
         @PathVariable("courseId") int courseId,
         @RequestBody CourseRequest request) {
      Student student = requireStudent(id);
      StudentProject project = requireProject(student, projectId);
      StudentCourse course = requireCourse(project, courseId);
      if (request.title() != null && !request.title().isBlank()) {
         course.setTitle(request.title().trim());
      }
      course.setDay(request.day());
      course.setDate(request.date());
      course.setHour(request.hour());
      course.setPrice(request.price());
      course.setStatus(request.status());
      course.setAssignment(request.assignment());
      course.setComment(request.comment());
      course.setHomeworkNextLesson(request.homeworkNextLesson());
      updateNoteReviewDates(course);
      return save(student);
   }

   @DeleteMapping("/{id}/projects/{projectId}/courses/{courseId}")
   public Student deleteCourse(
         @PathVariable("id") int id,
         @PathVariable("projectId") int projectId,
         @PathVariable("courseId") int courseId) {
      Student student = requireStudent(id);
      StudentCourse course = requireCourse(requireProject(student, projectId), courseId);
      student.removeCourse(course);
      return save(student);
   }

   @PostMapping("/{id}/projects/{projectId}/courses/{courseId}/notes")
   @ResponseStatus(HttpStatus.CREATED)
   public Student addNote(
         @PathVariable("id") int id,
         @PathVariable("projectId") int projectId,
         @PathVariable("courseId") int courseId,
         @RequestBody NoteRequest request) {
      Student student = requireStudent(id);
      StudentCourse course = requireCourse(requireProject(student, projectId), courseId);
      CourseNote note = course.addNote(request.piece());
      applyNoteRequest(course, note, request);
      return save(student);
   }

   @PutMapping("/{id}/projects/{projectId}/courses/{courseId}/notes/{noteId}")
   public Student updateNote(
         @PathVariable("id") int id,
         @PathVariable("projectId") int projectId,
         @PathVariable("courseId") int courseId,
         @PathVariable("noteId") int noteId,
         @RequestBody NoteRequest request) {
      Student student = requireStudent(id);
      StudentCourse course = requireCourse(requireProject(student, projectId), courseId);
      CourseNote note = requireNote(course, noteId);
      applyNoteRequest(course, note, request);
      return save(student);
   }

   @DeleteMapping("/{id}/projects/{projectId}/courses/{courseId}/notes/{noteId}")
   public Student deleteNote(
         @PathVariable("id") int id,
         @PathVariable("projectId") int projectId,
         @PathVariable("courseId") int courseId,
         @PathVariable("noteId") int noteId) {
      Student student = requireStudent(id);
      StudentCourse course = requireCourse(requireProject(student, projectId), courseId);
      course.removeNote(requireNote(course, noteId));
      return save(student);
   }

   private int nextStudentId() {
      return studentRepository.findAll().stream().mapToInt(Student::getId).max().orElse(0) + 1;
   }

   private Student requireStudent(int id) {
      Student student = studentService.findStudentById(id);
      if (student == null) {
         throw new ResponseStatusException(HttpStatus.NOT_FOUND);
      }
      return student;
   }

   private StudentProject requireProject(Student student, int projectId) {
      StudentProject project = student.findProjectById(projectId);
      if (project == null) {
         throw new ResponseStatusException(HttpStatus.NOT_FOUND);
      }
      return project;
   }

   private StudentCourse requireCourse(StudentProject project, int courseId) {
      StudentCourse course = project.findCourseById(courseId);
      if (course == null) {
         throw new ResponseStatusException(HttpStatus.NOT_FOUND);
      }
      return course;
   }

   private String requirePiece(StudentProject project, int pieceIndex) {
      if (pieceIndex < 0 || pieceIndex >= project.getPieces().size()) {
         throw new ResponseStatusException(HttpStatus.NOT_FOUND);
      }
      return project.getPieces().get(pieceIndex);
   }

   private CourseNote requireNote(StudentCourse course, int noteId) {
      for (CourseNote note : course.getNotes()) {
         if (note.getId() == noteId) {
            return note;
         }
      }
      throw new ResponseStatusException(HttpStatus.NOT_FOUND);
   }

   private void applyNoteRequest(StudentCourse course, CourseNote note, NoteRequest request) {
      note.setPiece(request.piece());
      note.setComment(request.comment());
      note.setSourceCourseId(course.getId());
      note.setReviewSchedule(request.reviewWeeks(), course.getDate());
   }

   private void updateNoteReviewDates(StudentCourse course) {
      for (CourseNote note : course.getNotes()) {
         note.setReviewSchedule(note.getReviewWeeks(), course.getDate());
      }
   }

   private Student save(Student student) {
      studentRepository.update(student);
      return student;
   }

   public record StudentRequest( Integer id, String firstName, String familyName, 
         String phone, String email, Instrument instrument, Level level, Integer teacherId,
         DayOfWeek courseDay, LocalTime courseHour, double coursePrice) { 
            Student toStudent() {
         return new Student( firstName, familyName, phone, email, instrument, 
               level, teacherId, courseDay, courseHour, coursePrice);
            }
   }

   public record ProjectRequest(String name) {
   }

   public record PieceRequest(String title) {
   }

   public record CourseRequest(
         String title,
         DayOfWeek day,
         LocalDate date,
         LocalTime hour,
         double price,
         LessonStatus status,
         String assignment,
         String comment,
         String homeworkNextLesson) {
   }

   public record NoteRequest(String piece, String comment, Integer reviewWeeks) {
   }
}
