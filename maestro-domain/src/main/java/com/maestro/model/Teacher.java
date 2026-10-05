package com.maestro.model;

public class Teacher {
   private String name;
   private String telephone;
   private String email;
   private String address;
   private int id;
   private Status status;
   private String firstName = "";
   private String lastName = "";
   private String studioName = "";
   private String city = "";
   private String postalCode = "";
   private String mainInstrument = "";
   private String otherInstruments = "";
   private int defaultLessonDuration = 60;
   private double defaultLessonPrice = 0;
   private String currency = "CAD";
   private String profileImagePath = "";

   public Teacher(int id, String name, String telephone, String email, String address) {
      this.name = name;
      this.telephone = telephone;
      this.email = email;
      this.address = address;
      this.id = id;
      this.status = Status.ACTIVE;
      setNamePartsFromName(name);
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
      setNamePartsFromName(name);
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

   public String getFirstName() {
      return firstName;
   }

   public void setFirstName(String firstName) {
      this.firstName = safe(firstName);
      rebuildName();
   }

   public String getLastName() {
      return lastName;
   }

   public void setLastName(String lastName) {
      this.lastName = safe(lastName);
      rebuildName();
   }

   public String getStudioName() {
      return studioName;
   }

   public void setStudioName(String studioName) {
      this.studioName = safe(studioName);
   }

   public String getCity() {
      return city;
   }

   public void setCity(String city) {
      this.city = safe(city);
   }

   public String getPostalCode() {
      return postalCode;
   }

   public void setPostalCode(String postalCode) {
      this.postalCode = safe(postalCode);
   }

   public String getMainInstrument() {
      return mainInstrument;
   }

   public void setMainInstrument(String mainInstrument) {
      this.mainInstrument = safe(mainInstrument);
   }

   public String getOtherInstruments() {
      return otherInstruments;
   }

   public void setOtherInstruments(String otherInstruments) {
      this.otherInstruments = safe(otherInstruments);
   }

   public int getDefaultLessonDuration() {
      return defaultLessonDuration;
   }

   public void setDefaultLessonDuration(int defaultLessonDuration) {
      this.defaultLessonDuration = Math.max(0, defaultLessonDuration);
   }

   public double getDefaultLessonPrice() {
      return defaultLessonPrice;
   }

   public void setDefaultLessonPrice(double defaultLessonPrice) {
      this.defaultLessonPrice = Math.max(0, defaultLessonPrice);
   }

   public String getCurrency() {
      return currency;
   }

   public void setCurrency(String currency) {
      this.currency = safe(currency).isEmpty() ? "CAD" : safe(currency);
   }

   public String getProfileImagePath() {
      return profileImagePath;
   }

   public void setProfileImagePath(String profileImagePath) {
      this.profileImagePath = safe(profileImagePath);
   }

   private void setNamePartsFromName(String name) {
      if ((firstName != null && !firstName.isBlank()) || (lastName != null && !lastName.isBlank())) {
         return;
      }

      String safeName = safe(name);
      int splitIndex = safeName.indexOf(' ');
      if (splitIndex < 0) {
         firstName = safeName;
         lastName = "";
      } else {
         firstName = safeName.substring(0, splitIndex).trim();
         lastName = safeName.substring(splitIndex + 1).trim();
      }
   }

   private void rebuildName() {
      this.name = (safe(firstName) + " " + safe(lastName)).trim();
   }

   private String safe(String value) {
      return value == null ? "" : value.trim();
   }
}
