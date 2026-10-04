package com.maestro.repository;

import com.maestro.model.CourseNote;
import java.util.List;

public interface NoteRepository {
   CourseNote save(int studentId, int courseId, CourseNote note, int sortOrder);

   List<CourseNote> findByCourseId(int studentId, int courseId);

   void deleteById(int noteId);
}
