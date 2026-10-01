package com.maestro.model;

import java.time.LocalDate;

public class CourseNote {
   private String piece;
   private String comment = "";
   private Integer reviewWeeks;
   private LocalDate reviewDate;

   public CourseNote(String piece) {
      this.piece = piece == null ? "" : piece;
   }

   public String getPiece() {
      return piece;
   }

   public void setPiece(String piece) {
      this.piece = piece == null ? "" : piece;
   }

   public String getComment() {
      return comment;
   }

   public void setComment(String comment) {
      this.comment = comment == null ? "" : comment;
   }

   public Integer getReviewWeeks() {
      return reviewWeeks;
   }

   public LocalDate getReviewDate() {
      return reviewDate;
   }

   public void setReviewSchedule(Integer reviewWeeks, LocalDate courseDate) {
      this.reviewWeeks = reviewWeeks;
      this.reviewDate = reviewWeeks == null || courseDate == null ? null : courseDate.plusWeeks(reviewWeeks);
   }
}
