package com.maestro.api;

import com.maestro.model.Teacher;
import com.maestro.repository.TeacherRepository;
import com.maestro.service.TeacherService;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/teachers")
public class TeacherController {
   private final TeacherService teacherService;
   private final TeacherRepository teacherRepository;

   public TeacherController(TeacherService teacherService, TeacherRepository teacherRepository) {
      this.teacherService = teacherService;
      this.teacherRepository = teacherRepository;
   }

   @GetMapping
   public List<Teacher> findAll() {
      return teacherService.getAllTeachers();
   }

   @GetMapping("/{id}")
   public Teacher findById(@PathVariable int id) {
      Teacher teacher = teacherService.findTeacherById(id);
      if (teacher == null) {
         throw new ResponseStatusException(HttpStatus.NOT_FOUND);
      }
      return teacher;
   }

   @PostMapping
   @ResponseStatus(HttpStatus.CREATED)
   public Teacher create(@RequestBody TeacherRequest request) {
      Teacher teacher = request.toTeacher(request.id() == null || request.id() <= 0 ? nextTeacherId() : request.id());
      teacherService.addTeacher(teacher);
      return teacher;
   }

   @PutMapping("/{id}")
   public Teacher update(@PathVariable int id, @RequestBody TeacherRequest request) {
      if (teacherRepository.findById(id).isEmpty()) {
         throw new ResponseStatusException(HttpStatus.NOT_FOUND);
      }
      Teacher teacher = request.toTeacher(id);
      teacherRepository.update(teacher);
      return teacher;
   }

   @DeleteMapping("/{id}")
   @ResponseStatus(HttpStatus.NO_CONTENT)
   public void delete(@PathVariable int id) {
      teacherRepository.deleteById(id);
   }

   private int nextTeacherId() {
      return teacherRepository.findAll().stream().mapToInt(Teacher::getId).max().orElse(0) + 1;
   }

   public record TeacherRequest(Integer id, String name, String telephone, String email, String address) {
      Teacher toTeacher(int teacherId) {
         return new Teacher(teacherId, name, telephone, email, address);
      }
   }
}
