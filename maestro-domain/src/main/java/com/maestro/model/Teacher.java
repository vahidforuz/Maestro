package com.maestro.model;

public class Teacher {
   private String name;
   private String telephone;
   private String email;
   private String address;
   private int id;
   private Status status;

   public Teacher(int id, String name, String telephone, String email, String address) {
      this.name = name;
      this.telephone = telephone;
      this.email = email;
      this.address = address;
      this.id = id;
      this.status = Status.ACTIVE;
   }

   public Teacher(String name, String telephone, String email, String address) {
      this(0, name, telephone, email, address);
   }

   public int getId(){
      return id;
   }

   public Status getStatus(){
      return status;
   }

   public String getName() {
      return name;
   }

   public String getTelephone() {
      return telephone;
   }

   public String getEmail() {
      return email;
   }

   public String getAddress() {
      return address;
   }
    
   public void setName(String name) {
      this.name = name;   
   }
    
   public void setTelephone(String telephone) {
      this.telephone = telephone;
   }

   public void setEmail(String email) {
      this.email = email;
   }

   public void setAddress(String address) {
      this.address = address;
   }

   public void setStatus(Status status) {
      this.status = status;
   }
}
