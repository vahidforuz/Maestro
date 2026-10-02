package com.maestro.repository;

import com.maestro.model.StudentCourse;
import java.util.List;

public interface CourseRepository {
   StudentCourse save(int studentId, int projectId, StudentCourse course, int sortOrder);

   List<StudentCourse> findByProjectId(int studentId, int projectId);

   void deleteById(int studentId, int courseId);
}
