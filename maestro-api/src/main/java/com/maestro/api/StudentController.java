package com.maestro.api;

import com.maestro.model.Instrument;
import com.maestro.model.Level;
import com.maestro.model.Student;
import com.maestro.repository.StudentRepository;
import com.maestro.service.StudentService;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
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
   public Student findById(@PathVariable int id) {
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
   public Student update(@PathVariable int id, @RequestBody StudentRequest request) {
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
   public void delete(@PathVariable int id) {
      studentRepository.deleteById(id);
   }

   private int nextStudentId() {
      return studentRepository.findAll().stream().mapToInt(Student::getId).max().orElse(0) + 1;
   }

   public record StudentRequest( Integer id, String firstName, String familyName, 
         String phone, String email, Instrument instrument, Level level, Integer teacherId,
         DayOfWeek courseDay, LocalTime courseHour, double coursePrice) { 
            Student toStudent() {
         return new Student( firstName, familyName, phone, email, instrument, 
               level, teacherId, courseDay, courseHour, coursePrice);
            }
   }
}
