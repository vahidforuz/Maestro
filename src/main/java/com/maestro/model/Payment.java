package com.maestro.model;

import java.time.LocalDate;

public class Payment {
   private Student student;
   private double amount;
   private LocalDate paymentDate;
   private String method;
   private String note; 

   public Payment(Student student, double amount, LocalDate paymentDate,
    String method, String note) {
      this.student = student;
      this.amount = amount;
      this.paymentDate = paymentDate;
      this.method = method;
      this.note = note;
    }

    public Student getStudent() {
      return student;
    }

    public void setStudent(Student student) {
      this.student = student;
    }

    public double getAmount() {
      return amount;
    }

    public void setAmount(double amount) {
      this.amount = amount;
    }

    public LocalDate getPaymentDate() {
      return paymentDate;
    }

    public void setPaymentDate(LocalDate paymentDate) {
      this.paymentDate = paymentDate;
    }

    public String getMethod() {
      return method;
    }

    public void setMethod(String method) {
      this.method = method;
    }

    public String getNote() {
      return note;
    }

    public void setNote(String note) {
      this.note = note;
    }

}
