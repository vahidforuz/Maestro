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
   public Teacher findById(@PathVariable("id") int id) {
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
   public Teacher update(@PathVariable("id") int id, @RequestBody TeacherRequest request) {
      if (teacherRepository.findById(id).isEmpty()) {
         throw new ResponseStatusException(HttpStatus.NOT_FOUND);
      }
      Teacher teacher = request.toTeacher(id);
      teacherRepository.update(teacher);
      return teacher;
   }

   @DeleteMapping("/{id}")
   @ResponseStatus(HttpStatus.NO_CONTENT)
   public void delete(@PathVariable("id") int id) {
      teacherRepository.deleteById(id);
   }

   private int nextTeacherId() {
      return teacherRepository.findAll().stream().mapToInt(Teacher::getId).max().orElse(0) + 1;
   }

   public record TeacherRequest(
         Integer id,
         String name,
         String telephone,
         String email,
         String address,
         String firstName,
         String lastName,
         String studioName,
         String city,
         String postalCode,
         String mainInstrument,
         String otherInstruments,
         Integer defaultLessonDuration,
         Double defaultLessonPrice,
         String currency,
         String profileImagePath) {
      Teacher toTeacher(int teacherId) {
         Teacher teacher = new Teacher(teacherId, name, telephone, email, address);
         if (firstName != null) {
            teacher.setFirstName(firstName);
         }
         if (lastName != null) {
            teacher.setLastName(lastName);
         }
         if (studioName != null) {
            teacher.setStudioName(studioName);
         }
         if (city != null) {
            teacher.setCity(city);
         }
         if (postalCode != null) {
            teacher.setPostalCode(postalCode);
         }
         if (mainInstrument != null) {
            teacher.setMainInstrument(mainInstrument);
         }
         if (otherInstruments != null) {
            teacher.setOtherInstruments(otherInstruments);
         }
         if (defaultLessonDuration != null) {
            teacher.setDefaultLessonDuration(defaultLessonDuration);
         }
         if (defaultLessonPrice != null) {
            teacher.setDefaultLessonPrice(defaultLessonPrice);
         }
         if (currency != null) {
            teacher.setCurrency(currency);
         }
         if (profileImagePath != null) {
            teacher.setProfileImagePath(profileImagePath);
         }
         return teacher;
      }
   }
}
