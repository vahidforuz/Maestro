package com.maestro.gui;

import com.calendarfx.model.Calendar;
import com.calendarfx.model.CalendarSource;
import com.calendarfx.model.Entry;
import com.calendarfx.view.CalendarView;
import com.maestro.model.LessonStatus;
import com.maestro.model.Student;
import com.maestro.model.StudentCourse;
import com.maestro.model.Teacher;
import com.maestro.service.PaymentService;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import javafx.geometry.Insets;
import javafx.scene.control.ButtonType;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Dialog;
import javafx.scene.control.Label;
import javafx.scene.control.TextArea;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.BorderPane;

public class MaestroCalendarView extends BorderPane {

   private final PaymentService paymentService;

   public MaestroCalendarView(Teacher teacher, List<Student> students, PaymentService paymentService) {
      this.paymentService = paymentService;

      CalendarView calendarView = new CalendarView();
      calendarView.setShowAddCalendarButton(false);
      calendarView.setShowPrintButton(false);
      calendarView.setShowDeveloperConsole(false);
      calendarView.setEntryDetailsCallback(parameter -> {
         Entry<?> entry = parameter.getEntry();
         Object userObject = entry.getUserObject();

         if (userObject instanceof CourseEntry courseEntry) {
            showCourseDialog(courseEntry, entry);
            calendarView.refreshData();
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

         for (StudentCourse course : student.getCourses()) {
            LocalDate lessonDate = getNextLessonDate(course, lessonIndex);
            LocalTime lessonStart = course.getHour() == null
                  ? LocalTime.of(16, 0).plusHours(lessonIndex % 3)
                  : course.getHour();
            LocalTime lessonEnd = lessonStart.plusMinutes(45);
            CourseEntry courseEntry = new CourseEntry(student, course);

            Entry<CourseEntry> lesson = new Entry<>(buildLessonTitle(courseEntry));
            lesson.setInterval(lessonDate, lessonStart, lessonDate, lessonEnd);
            lesson.setLocation(buildLessonLocation(courseEntry));
            lesson.setUserObject(courseEntry);
            lesson.startDateProperty().addListener((observable, oldValue, newValue) ->
                  course.setDay(newValue.getDayOfWeek()));
            lesson.startTimeProperty().addListener((observable, oldValue, newValue) ->
                  course.setHour(newValue));
            lessons.addEntry(lesson);

            lessonIndex++;
         }
      }
   }

   private LocalDate getNextLessonDate(StudentCourse course, int lessonIndex) {
      if (course.getDay() == null) {
         return LocalDate.now().plusDays(lessonIndex + 1L);
      }

      return LocalDate.now().with(TemporalAdjusters.nextOrSame(course.getDay()));
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

   private void showCourseDialog(CourseEntry courseEntry, Entry<?> entry) {
      Student student = courseEntry.student();
      StudentCourse course = courseEntry.course();
      Dialog<Boolean> dialog = new Dialog<>();
      dialog.setTitle(course.getTitle());
      dialog.setHeaderText(student.getName());

      ComboBox<LessonStatus> statusBox = new ComboBox<>();
      statusBox.getItems().addAll(LessonStatus.values());
      statusBox.setValue(course.getStatus());

      TextArea assignmentArea = new TextArea(course.getAssignment());
      assignmentArea.setPrefRowCount(3);
      assignmentArea.setWrapText(true);

      TextArea commentArea = new TextArea(course.getComment());
      commentArea.setPrefRowCount(3);
      commentArea.setWrapText(true);

      GridPane grid = new GridPane();
      grid.setHgap(10);
      grid.setVgap(10);
      grid.setPadding(new Insets(20));

      grid.add(new Label("Status:"), 0, 0);
      grid.add(statusBox, 1, 0);
      grid.add(new Label("Assignment:"), 0, 1);
      grid.add(assignmentArea, 1, 1);
      grid.add(new Label("Comment:"), 0, 2);
      grid.add(commentArea, 1, 2);

      dialog.getDialogPane().setContent(grid);
      dialog.getDialogPane().getButtonTypes().addAll(ButtonType.CANCEL, ButtonType.OK);
      dialog.setResultConverter(button -> button == ButtonType.OK);

      dialog.showAndWait().ifPresent(confirmed -> {
         if (confirmed) {
            course.setStatus(statusBox.getValue());
            course.setAssignment(assignmentArea.getText());
            course.setComment(commentArea.getText());
            entry.setTitle(buildLessonTitle(courseEntry));
            entry.setLocation(buildLessonLocation(courseEntry));
         }
      });
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

   private record CourseEntry(Student student, StudentCourse course) {
   }
}
