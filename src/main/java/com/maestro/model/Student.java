package com.maestro.model;

import java.time.LocalDate;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

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
  private Integer teacherId;
  private DayOfWeek courseDay;
  private LocalTime courseHour;
  private double coursePrice;
  private boolean present;
  private LessonStatus firstCourseStatus = LessonStatus.NOTHING;
  private String nextWeekAssignment = "";
  private String thisWeekComment = "";
  private final List<StudentCourse> courses = new ArrayList<>();
  private final List<StudentProject> projects = new ArrayList<>();

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

  public Student(
      String firstName,
      String familyName,
      String phone,
      String email,
      Instrument instrument,
      Level level,
      Integer teacherId) {
    this(firstName, familyName, phone, email, instrument, level);
    this.teacherId = teacherId;
  }

  public Student(
      String firstName,
      String familyName,
      String phone,
      String email,
      Instrument instrument,
      Level level,
      Integer teacherId,
      DayOfWeek courseDay) {
    this(firstName, familyName, phone, email, instrument, level, teacherId);
    this.courseDay = courseDay;
  }

  public Student(
      String firstName,
      String familyName,
      String phone,
      String email,
      Instrument instrument,
      Level level,
      Integer teacherId,
      DayOfWeek courseDay,
      LocalTime courseHour,
      double coursePrice) {
    this(firstName, familyName, phone, email, instrument, level, teacherId, courseDay);
    this.courseHour = courseHour;
    this.coursePrice = coursePrice;
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

  public Integer getTeacherId() {
    return teacherId;
  }

  public void setTeacherId(Integer teacherId) {
    this.teacherId = teacherId;
  }

  public boolean hasTeacher() {
    return teacherId != null;
  }

  public DayOfWeek getCourseDay() {
    return getFirstCourse().getDay();
  }

  public void setCourseDay(DayOfWeek courseDay) {
    this.courseDay = courseDay;
    getFirstCourse().setDay(courseDay);
  }

  public LocalTime getCourseHour() {
    return getFirstCourse().getHour();
  }

  public void setCourseHour(LocalTime courseHour) {
    this.courseHour = courseHour;
    getFirstCourse().setHour(courseHour);
  }

  public double getCoursePrice() {
    return getFirstCourse().getPrice();
  }

  public void setCoursePrice(double coursePrice) {
    this.coursePrice = coursePrice;
    getFirstCourse().setPrice(coursePrice);
  }

  public boolean isPresent() {
    return present;
  }

  public void setPresent(boolean present) {
    this.present = present;
    this.firstCourseStatus = present ? LessonStatus.PRESENT : LessonStatus.NOTHING;
    getFirstCourse().setStatus(this.firstCourseStatus);
  }

  public LessonStatus getFirstCourseStatus() {
    return getFirstCourse().getStatus();
  }

  public void setFirstCourseStatus(LessonStatus firstCourseStatus) {
    this.firstCourseStatus = firstCourseStatus == null ? LessonStatus.NOTHING : firstCourseStatus;
    this.present = this.firstCourseStatus == LessonStatus.PRESENT;
    getFirstCourse().setStatus(this.firstCourseStatus);
  }

  public String getNextWeekAssignment() {
    return getFirstCourse().getAssignment();
  }

  public void setNextWeekAssignment(String nextWeekAssignment) {
    this.nextWeekAssignment = nextWeekAssignment == null ? "" : nextWeekAssignment;
    getFirstCourse().setAssignment(this.nextWeekAssignment);
  }

  public String getThisWeekComment() {
    return getFirstCourse().getComment();
  }

  public void setThisWeekComment(String thisWeekComment) {
    this.thisWeekComment = thisWeekComment == null ? "" : thisWeekComment;
    getFirstCourse().setComment(this.thisWeekComment);
  }

  public List<StudentCourse> getCourses() {
    ensureFirstCourse();
    List<StudentCourse> allCourses = new ArrayList<>();
    for (StudentProject project : projects) {
      allCourses.addAll(project.getCourses());
    }
    return allCourses;
  }

  public StudentCourse addCourse() {
    return addCourseToProject(getFirstProject());
  }

  public StudentCourse addCourseToProject(StudentProject project) {
    ensureFirstCourse();
    StudentCourse firstCourse = courses.get(0);
    StudentCourse course = new StudentCourse(
        "Course " + (project.getCourses().size() + 1),
        firstCourse.getDay(),
        firstCourse.getHour(),
        firstCourse.getPrice());
    courses.add(course);
    project.getCourses().add(course);
    return course;
  }

  public void removeCourse(StudentCourse course) {
    ensureFirstCourse();
    if (courses.size() > 1 || !getFirstProject().getCourses().contains(course)) {
      courses.remove(course);
      for (StudentProject project : projects) {
        project.getCourses().remove(course);
      }
    }
  }

  public List<StudentProject> getProjects() {
    ensureFirstCourse();
    return projects;
  }

  public StudentProject addProject() {
    ensureFirstProject();
    StudentProject project = new StudentProject("Project " + (projects.size() + 1));
    projects.add(project);
    return project;
  }

  public void removeProject(StudentProject project) {
    ensureFirstProject();
    if (projects.size() <= 1) {
      return;
    }

    courses.removeAll(project.getCourses());
    projects.remove(project);
    renumberProjects();
  }

  private StudentCourse getFirstCourse() {
    ensureFirstCourse();
    return courses.get(0);
  }

  private StudentProject getFirstProject() {
    ensureFirstCourse();
    return projects.get(0);
  }

  private void ensureFirstCourse() {
    ensureFirstProject();
    if (!courses.isEmpty()) {
      return;
    }

    StudentCourse firstCourse = new StudentCourse("First course", courseDay, courseHour, coursePrice);
    firstCourse.setStatus(firstCourseStatus);
    firstCourse.setAssignment(nextWeekAssignment);
    firstCourse.setComment(thisWeekComment);
    courses.add(firstCourse);
    projects.get(0).getCourses().add(firstCourse);
  }

  private void ensureFirstProject() {
    if (!projects.isEmpty()) {
      return;
    }

    StudentProject firstProject = new StudentProject("Project 1");
    firstProject.getCourses().addAll(courses);
    projects.add(firstProject);
  }

  private void renumberProjects() {
    for (int index = 0; index < projects.size(); index++) {
      projects.get(index).setName("Project " + (index + 1));
    }
  }

  private String buildName() {
    String safeFirstName = firstName == null ? "" : firstName;
    String safeFamilyName = familyName == null ? "" : familyName;
    return (safeFirstName + " " + safeFamilyName).trim();
  }
}
