package com.maestro.model;

import java.io.Serializable;
import java.time.LocalDate;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class Student implements Serializable {
  private static final long serialVersionUID = 1L;

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
  private double paymentCreditBalance;
  private int nextProjectId = 1;
  private int nextCourseId = 1;
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
    ensureEntityIds();
    StudentCourse firstCourse = courses.get(0);
    LocalDate courseDate = findNextCourseDate(firstCourse.getDay());
    StudentCourse course = new StudentCourse(
        "Course " + (project.getCourses().size() + 1),
        firstCourse.getDay(),
        courseDate,
        firstCourse.getHour(),
        firstCourse.getPrice());
    course.setId(nextCourseId++);
    courses.add(course);
    project.getCourses().add(course);
    resolvePendingReviewTargets(project, course);
    return course;
  }

  public List<StudentCourse> addPaidCoursesToProject(StudentProject project, int numberOfCourses) {
    ensureFirstCourse();
    List<StudentCourse> addedCourses = new ArrayList<>();
    for (int index = 0; index < numberOfCourses; index++) {
      addedCourses.add(addCourseToProject(project));
    }
    return addedCourses;
  }

  public void removeCourse(StudentCourse course) {
    ensureFirstCourse();
    if (courses.size() > 1 || !getFirstProject().getCourses().contains(course)) {
      clearReviewReferencesToCourse(course);
      courses.remove(course);
      for (StudentProject project : projects) {
        project.getCourses().remove(course);
      }
    }
  }

  public StudentProject getProjectForCourse(StudentCourse course) {
    ensureFirstCourse();
    for (StudentProject project : projects) {
      if (project.getCourses().contains(course)) {
        return project;
      }
    }
    return null;
  }

  public StudentProject findProjectById(int projectId) {
    ensureFirstCourse();
    for (StudentProject project : projects) {
      if (project.getId() == projectId) {
        return project;
      }
    }
    return null;
  }

  public StudentCourse findCourseById(int courseId) {
    ensureFirstCourse();
    for (StudentCourse course : getCourses()) {
      if (course.getId() == courseId) {
        return course;
      }
    }
    return null;
  }

  public List<StudentProject> getProjects() {
    ensureFirstCourse();
    ensureEntityIds();
    return projects;
  }

  public void replaceProjects(List<StudentProject> loadedProjects) {
    projects.clear();
    courses.clear();
    projects.addAll(loadedProjects);
    for (StudentProject project : projects) {
      courses.addAll(project.getCourses());
    }
    ensureFirstCourse();
    ensureEntityIds();
  }

  public StudentProject getCurrentProject() {
    ensureFirstCourse();
    return projects.get(projects.size() - 1);
  }

  public double getPaymentCreditBalance() {
    return paymentCreditBalance;
  }

  public void setPaymentCreditBalance(double paymentCreditBalance) {
    this.paymentCreditBalance = paymentCreditBalance;
  }

  public int getNextProjectId() {
    return nextProjectId;
  }

  public void setNextProjectId(int nextProjectId) {
    this.nextProjectId = Math.max(1, nextProjectId);
  }

  public int getNextCourseId() {
    return nextCourseId;
  }

  public void setNextCourseId(int nextCourseId) {
    this.nextCourseId = Math.max(1, nextCourseId);
  }

  public StudentProject addProject() {
    ensureFirstProject();
    ensureEntityIds();
    StudentProject project = new StudentProject("Project " + (projects.size() + 1));
    project.setId(nextProjectId++);
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

    StudentCourse firstCourse = new StudentCourse(
        "First course",
        courseDay,
        firstDateForDay(courseDay),
        courseHour,
        coursePrice);
    firstCourse.setId(nextCourseId++);
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
    firstProject.setId(nextProjectId++);
    firstProject.getCourses().addAll(courses);
    projects.add(firstProject);
  }

  private void renumberProjects() {
    for (int index = 0; index < projects.size(); index++) {
      projects.get(index).setName("Project " + (index + 1));
    }
  }

  public void ensureEntityIds() {
    int highestProjectId = 0;
    int highestCourseId = 0;

    for (StudentProject project : projects) {
      if (project.getId() <= 0) {
        project.setId(nextProjectId++);
      }
      highestProjectId = Math.max(highestProjectId, project.getId());

      for (StudentCourse course : project.getCourses()) {
        if (course.getId() <= 0) {
          course.setId(nextCourseId++);
        }
        highestCourseId = Math.max(highestCourseId, course.getId());
      }
    }

    nextProjectId = Math.max(nextProjectId, highestProjectId + 1);
    nextCourseId = Math.max(nextCourseId, highestCourseId + 1);
  }

  private LocalDate findNextCourseDate(DayOfWeek day) {
    if (day == null) {
      return null;
    }

    Set<LocalDate> usedDates = new HashSet<>();
    LocalDate latestCourseDate = null;
    for (StudentCourse existingCourse : getCourses()) {
      LocalDate existingDate = existingCourse.getDate();
      if (existingDate == null && existingCourse.getDay() != null) {
        existingDate = firstDateForDay(existingCourse.getDay());
        existingCourse.setDate(existingDate);
      }

      if (existingDate != null) {
        usedDates.add(existingDate);
        if (existingDate.getDayOfWeek() == day
            && (latestCourseDate == null || existingDate.isAfter(latestCourseDate))) {
          latestCourseDate = existingDate;
        }
      }
    }

    LocalDate candidate = latestCourseDate == null ? firstDateForDay(day) : latestCourseDate.plusWeeks(1);
    while (usedDates.contains(candidate)) {
      candidate = candidate.plusWeeks(1);
    }
    return candidate;
  }

  private LocalDate firstDateForDay(DayOfWeek day) {
    if (day == null) {
      return null;
    }

    return LocalDate.now().with(TemporalAdjusters.nextOrSame(day));
  }

  private void clearReviewReferencesToCourse(StudentCourse removedCourse) {
    for (StudentCourse existingCourse : getCourses()) {
      for (CourseNote note : existingCourse.getNotes()) {
        if (note.getTargetCourseId() != null && note.getTargetCourseId() == removedCourse.getId()) {
          note.appendReviewHistory("Target course " + removedCourse.getId() + " was deleted");
          note.clearReviewSchedule();
        }
      }
    }
  }

  private void resolvePendingReviewTargets(StudentProject project, StudentCourse targetCourse) {
    if (targetCourse.getDate() == null) {
      return;
    }
    for (StudentCourse sourceCourse : project.getCourses()) {
      if (sourceCourse.getId() == targetCourse.getId()) {
        continue;
      }
      for (CourseNote note : sourceCourse.getNotes()) {
        if (note.getReviewStatus() == ReviewStatus.PENDING
            && note.getTargetCourseId() == null
            && note.getReviewDate() != null
            && !note.getReviewDate().isAfter(targetCourse.getDate())) {
          note.setReviewSchedule(note.getReviewWeeks(), targetCourse.getDate(), targetCourse.getId());
          note.appendReviewHistory("Resolved to Course " + targetCourse.getId());
        }
      }
    }
  }

  private String buildName() {
    String safeFirstName = firstName == null ? "" : firstName;
    String safeFamilyName = familyName == null ? "" : familyName;
    return (safeFirstName + " " + safeFamilyName).trim();
  }
}
