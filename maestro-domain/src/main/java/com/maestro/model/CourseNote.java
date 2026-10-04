package com.maestro.model;

import java.io.Serializable;
import java.time.LocalDate;

public class CourseNote implements Serializable {
   private static final long serialVersionUID = 1L;

   private int id;
   private String piece;
   private String comment = "";
   private Integer reviewWeeks;
   private LocalDate reviewDate;
   private ReviewStatus reviewStatus;
   private int sourceCourseId;
   private Integer acceptedCourseId;

   public CourseNote(String piece) {
      this.piece = piece == null ? "" : piece;
   }

   public String getPiece() {
      return piece;
   }

   public int getId() {
      return id;
   }

   public void setId(int id) {
      this.id = id;
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

   public void setReviewData(Integer reviewWeeks, LocalDate reviewDate) {
      this.reviewWeeks = reviewWeeks;
      this.reviewDate = reviewDate;
      this.reviewStatus = reviewDate == null ? null : ReviewStatus.PENDING;
   }

   public void setReviewData(
         Integer reviewWeeks,
         LocalDate reviewDate,
         ReviewStatus reviewStatus,
         int sourceCourseId,
         Integer acceptedCourseId) {
      this.reviewWeeks = reviewWeeks;
      this.reviewDate = reviewDate;
      this.reviewStatus = reviewStatus;
      this.sourceCourseId = sourceCourseId;
      this.acceptedCourseId = acceptedCourseId;
   }

   public ReviewStatus getReviewStatus() {
      return reviewStatus;
   }

   public void setReviewStatus(ReviewStatus reviewStatus) {
      this.reviewStatus = reviewStatus;
   }

   public int getSourceCourseId() {
      return sourceCourseId;
   }

   public void setSourceCourseId(int sourceCourseId) {
      this.sourceCourseId = sourceCourseId;
   }

   public Integer getAcceptedCourseId() {
      return acceptedCourseId;
   }

   public void setAcceptedCourseId(Integer acceptedCourseId) {
      this.acceptedCourseId = acceptedCourseId;
   }

   public void setReviewSchedule(Integer reviewWeeks, LocalDate courseDate) {
      this.reviewWeeks = reviewWeeks;
      this.reviewDate = reviewWeeks == null || courseDate == null ? null : courseDate.plusWeeks(reviewWeeks);
      this.reviewStatus = this.reviewDate == null ? null : ReviewStatus.PENDING;
      this.acceptedCourseId = null;
   }
}
