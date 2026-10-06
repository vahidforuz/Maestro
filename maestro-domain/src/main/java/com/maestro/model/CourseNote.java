package com.maestro.model;

import java.io.Serializable;
import java.time.LocalDate;

public class CourseNote implements Serializable {
   private static final long serialVersionUID = 1L;

   private int id;
   private String piece;
   private String comment = "";
   private LocalDate createdDate = LocalDate.now();
   private Integer reviewWeeks;
   private LocalDate reviewDate;
   private ReviewStatus reviewStatus;
   private int sourceCourseId;
   private Integer acceptedCourseId;
   private Integer targetCourseId;
   private LocalDate reviewedDate;
   private String reviewHistory = "";

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

   public LocalDate getCreatedDate() {
      return createdDate;
   }

   public void setCreatedDate(LocalDate createdDate) {
      this.createdDate = createdDate == null ? LocalDate.now() : createdDate;
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
      setReviewData(reviewWeeks, reviewDate, reviewStatus, sourceCourseId, acceptedCourseId, null, null, null, "");
   }

   public void setReviewData(
         Integer reviewWeeks,
         LocalDate reviewDate,
         ReviewStatus reviewStatus,
         int sourceCourseId,
         Integer acceptedCourseId,
         LocalDate createdDate,
         Integer targetCourseId,
         LocalDate reviewedDate,
         String reviewHistory) {
      this.reviewWeeks = reviewWeeks;
      this.reviewDate = reviewDate;
      this.reviewStatus = reviewStatus;
      this.sourceCourseId = sourceCourseId;
      this.acceptedCourseId = acceptedCourseId;
      setCreatedDate(createdDate);
      this.targetCourseId = targetCourseId;
      this.reviewedDate = reviewedDate;
      this.reviewHistory = reviewHistory == null ? "" : reviewHistory;
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

   public Integer getTargetCourseId() {
      return targetCourseId;
   }

   public LocalDate getReviewedDate() {
      return reviewedDate;
   }

   public String getReviewHistory() {
      return reviewHistory;
   }

   public void setReviewHistory(String reviewHistory) {
      this.reviewHistory = reviewHistory == null ? "" : reviewHistory;
   }

   public void setReviewSchedule(Integer reviewWeeks, LocalDate courseDate) {
      setReviewSchedule(reviewWeeks, courseDate, null);
   }

   public void setReviewSchedule(Integer reviewWeeks, LocalDate courseDate, Integer targetCourseId) {
      this.reviewWeeks = reviewWeeks;
      this.reviewDate = reviewWeeks == null || courseDate == null ? null : courseDate.plusWeeks(reviewWeeks);
      if (targetCourseId != null && courseDate != null) {
         this.reviewDate = courseDate;
      }
      this.reviewStatus = this.reviewDate == null ? null : ReviewStatus.PENDING;
      this.acceptedCourseId = null;
      this.targetCourseId = this.reviewDate == null ? null : targetCourseId;
      this.reviewedDate = null;
   }

   public void markReviewed(int courseId, LocalDate reviewedDate) {
      this.reviewStatus = ReviewStatus.ACCEPTED;
      this.acceptedCourseId = courseId;
      this.reviewedDate = reviewedDate == null ? LocalDate.now() : reviewedDate;
      appendReviewHistory("Course " + courseId + " - Reviewed " + this.reviewedDate);
   }

   public void clearReviewSchedule() {
      this.reviewWeeks = null;
      this.reviewDate = null;
      this.reviewStatus = null;
      this.acceptedCourseId = null;
      this.targetCourseId = null;
      this.reviewedDate = null;
   }

   public void appendReviewHistory(String entry) {
      if (entry == null || entry.isBlank()) {
         return;
      }
      this.reviewHistory = this.reviewHistory == null || this.reviewHistory.isBlank()
            ? entry
            : this.reviewHistory + "\n" + entry;
   }
}
