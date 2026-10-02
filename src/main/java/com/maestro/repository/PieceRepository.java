package com.maestro.repository;

import java.util.List;

public interface PieceRepository {
   void replacePieces(int studentId, int projectId, List<String> pieces);

   List<String> findByProjectId(int studentId, int projectId);
}
