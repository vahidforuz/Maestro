package com.maestro.model;

import java.time.LocalDate;

public class Student {
  private int id;
  private String name;
  private String firstName;
  private String familyName;
  private String email;
  private String phone;
  private LocalDate birthday;
  private Status status;
  private Instrument instrument;
  private Level level;

  public Student(String name, LocalDate birthday) {
    this.name = name;
    this.birthday = birthday;
  }

  public Student(
      String firstName,
      String familyName,
      String phone,
      String email,
      Instrument instrument,
      Level level) {
    this.firstName = firstName;
    this.familyName = familyName;
    this.name = (firstName + " " + familyName).trim();
    this.phone = phone;
    this.email = email;
    this.instrument = instrument;
    this.level = level;
  }

  public int getId() {
    return id;
  }

  public void setId(int id) {
    this.id = id;
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public String getFirstName() {
    return firstName;
  }

  public void setFirstName(String firstName) {
    this.firstName = firstName;
    this.name = buildName();
  }

  public String getFamilyName() {
    return familyName;
  }

  public void setFamilyName(String familyName) {
    this.familyName = familyName;
    this.name = buildName();
  }

  public String getEmail() {
    return email;
  }

  public void setEmail(String email) {
    this.email = email;
  }

  public String getPhone() {
    return phone;
  }

  public void setPhone(String phone) {
    this.phone = phone;
  }

  public LocalDate getBirthday() {
    return birthday;
  }

  public void setBirthday(LocalDate birthday) {
    this.birthday = birthday;
  }

  public Status getStatus() {
    return status;
  }

  public void setStatus(Status status) {
    this.status = status;
  }

  public Instrument getInstrument() {
    return instrument;
  }

  public void setInstrument(Instrument instrument) {
    this.instrument = instrument;
  }

  public Level getLevel() {
    return level;
  }

  public void setLevel(Level level) {
    this.level = level;
  }

  private String buildName() {
    String safeFirstName = firstName == null ? "" : firstName;
    String safeFamilyName = familyName == null ? "" : familyName;
    return (safeFirstName + " " + safeFamilyName).trim();
  }
}
