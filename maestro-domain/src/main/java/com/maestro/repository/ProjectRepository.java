package com.maestro.repository;

import com.maestro.model.StudentProject;
import java.util.List;

public interface ProjectRepository {
   StudentProject save(int studentId, StudentProject project, int sortOrder);

   List<StudentProject> findByStudentId(int studentId);

   void deleteById(int studentId, int projectId);
}
