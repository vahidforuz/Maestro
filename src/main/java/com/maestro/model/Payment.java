package com.maestro.model;

import java.io.Serializable;
import java.time.LocalDate;

public class Payment implements Serializable {
   private static final long serialVersionUID = 1L;

   private int id;
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

    public int getId() {
      return id;
    }

    public void setId(int id) {
      this.id = id;
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
