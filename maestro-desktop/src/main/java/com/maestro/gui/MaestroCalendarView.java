package com.maestro.gui;

import com.calendarfx.model.Calendar;
import com.calendarfx.model.CalendarSource;
import com.calendarfx.model.Entry;
import com.calendarfx.view.CalendarView;
import com.maestro.model.LessonStatus;
import com.maestro.model.Student;
import com.maestro.model.StudentCourse;
import com.maestro.model.StudentProject;
import com.maestro.model.Teacher;
import com.maestro.service.PaymentService;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import java.util.function.Consumer;
import javafx.scene.layout.BorderPane;

public class MaestroCalendarView extends BorderPane {

   private final PaymentService paymentService;
   private final Consumer<CourseSelection> openCourseAction;
   private final Runnable saveStudentsAction;

   public MaestroCalendarView(
         Teacher teacher,
         List<Student> students,
         PaymentService paymentService,
         Consumer<CourseSelection> openCourseAction,
         Runnable saveStudentsAction) {
      this.paymentService = paymentService;
      this.openCourseAction = openCourseAction;
      this.saveStudentsAction = saveStudentsAction;

      CalendarView calendarView = new CalendarView();
      calendarView.setShowAddCalendarButton(false);
      calendarView.setShowPrintButton(false);
      calendarView.setShowDeveloperConsole(false);
      calendarView.setEntryDetailsCallback(parameter -> {
         Entry<?> entry = parameter.getEntry();
         Object userObject = entry.getUserObject();

         if (userObject instanceof CourseEntry courseEntry) {
            openCourseAction.accept(new CourseSelection(
                  courseEntry.student(),
                  courseEntry.project().getId(),
                  courseEntry.course().getId()));
            return true;
         }

         return false;
      });

      Calendar<CourseEntry> lessons = new Calendar<>("Lessons");
      lessons.setStyle(Calendar.Style.STYLE1);

      Calendar<String> reminders = new Calendar<>("Reminders");
      reminders.setStyle(Calendar.Style.STYLE2);

      addLessonEntries(lessons, teacher, students);
      addReminderEntries(reminders);

      CalendarSource source = new CalendarSource("Maestro");
      source.getCalendars().addAll(lessons, reminders);
      calendarView.getCalendarSources().add(source);
      calendarView.showWeekPage();
      calendarView.showDate(LocalDate.now());
      calendarView.setRequestedTime(LocalTime.now());

      setCenter(calendarView);
   }

   private void addLessonEntries(Calendar<CourseEntry> lessons, Teacher teacher, List<Student> students) {
      int lessonIndex = 0;

      for (Student student : students) {
         if (!isVisibleForTeacher(student, teacher)) {
            continue;
         }

         student.ensureEntityIds();
         for (StudentProject project : student.getProjects()) {
            for (StudentCourse course : project.getCourses()) {
               LocalDate lessonDate = getNextLessonDate(course, lessonIndex);
               LocalTime lessonStart = course.getHour() == null
                     ? LocalTime.of(16, 0).plusHours(lessonIndex % 3)
                     : course.getHour();
               LocalTime lessonEnd = lessonStart.plusMinutes(45);
               CourseEntry courseEntry = new CourseEntry(student, project, course);

               Entry<CourseEntry> lesson = new Entry<>(buildLessonTitle(courseEntry));
               lesson.setInterval(lessonDate, lessonStart, lessonDate, lessonEnd);
               lesson.setLocation(buildLessonLocation(courseEntry));
               lesson.setUserObject(courseEntry);
               lesson.startDateProperty().addListener((observable, oldValue, newValue) -> {
                  course.setDate(newValue);
                  saveStudentsAction.run();
               });
               lesson.startTimeProperty().addListener((observable, oldValue, newValue) -> {
                  course.setHour(newValue);
                  saveStudentsAction.run();
               });
               lessons.addEntry(lesson);

               lessonIndex++;
            }
         }
      }
   }

   private LocalDate getNextLessonDate(StudentCourse course, int lessonIndex) {
      if (course.getDate() != null) {
         return course.getDate();
      }

      if (course.getDay() == null) {
         return LocalDate.now().plusDays(lessonIndex + 1L);
      }

      LocalDate lessonDate = LocalDate.now().with(TemporalAdjusters.nextOrSame(course.getDay()));
      course.setDate(lessonDate);
      return lessonDate;
   }

   private String buildLessonTitle(CourseEntry courseEntry) {
      Student student = courseEntry.student();
      StudentCourse course = courseEntry.course();
      String paidPrefix = isPaid(courseEntry) ? "\u2713 " : "";
      String courseHour = course.getHour() == null ? "" : " " + course.getHour();

      if (course.getDay() == null) {
         return paidPrefix + course.getTitle() + courseHour + " - " + student.getName();
      }

      return paidPrefix + course.getDay() + courseHour + " " + course.getTitle() + " - " + student.getName()
            + " [" + course.getStatus() + "]";
   }

   private String buildLessonLocation(CourseEntry courseEntry) {
      String paymentStatus = isPaid(courseEntry) ? "Paid" : "Not paid";
      return "Maestro - " + paymentStatus + " - " + courseEntry.course().getStatus();
   }

   private boolean isPaid(CourseEntry courseEntry) {
      return courseEntry.course().getPrice() > 0
            && paymentService.getTotalPaidByStudent(courseEntry.student()) >= courseEntry.course().getPrice();
   }

   private boolean isVisibleForTeacher(Student student, Teacher teacher) {
      return student.getTeacherId() == null || student.getTeacherId().equals(teacher.getId());
   }

   private void addReminderEntries(Calendar<String> reminders) {
      Entry<String> planning = new Entry<>("Weekly planning");
      LocalDate date = LocalDate.now();
      planning.setInterval(date, LocalTime.of(9, 0), date, LocalTime.of(9, 30));
      reminders.addEntry(planning);
   }

   public record CourseSelection(Student student, int projectId, int courseId) {
   }

   private record CourseEntry(Student student, StudentProject project, StudentCourse course) {
   }
}
