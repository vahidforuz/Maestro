package com.maestro.gui;

import com.calendarfx.model.Calendar;
import com.calendarfx.model.CalendarSource;
import com.calendarfx.model.Entry;
import com.calendarfx.view.CalendarView;
import com.maestro.model.Student;
import com.maestro.model.Teacher;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import javafx.scene.layout.BorderPane;

public class MaestroCalendarView extends BorderPane {

   public MaestroCalendarView(Teacher teacher, List<Student> students) {
      CalendarView calendarView = new CalendarView();
      calendarView.setShowAddCalendarButton(false);
      calendarView.setShowPrintButton(false);
      calendarView.setShowDeveloperConsole(false);

      Calendar<String> lessons = new Calendar<>("Lessons");
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

   private void addLessonEntries(Calendar<String> lessons, Teacher teacher, List<Student> students) {
      LocalDate firstLessonDate = LocalDate.now().plusDays(1);
      LocalTime firstLessonTime = LocalTime.of(16, 0);
      int lessonIndex = 0;

      for (Student student : students) {
         if (!isVisibleForTeacher(student, teacher)) {
            continue;
         }

         LocalDate lessonDate = firstLessonDate.plusDays(lessonIndex);
         LocalTime lessonStart = firstLessonTime.plusHours(lessonIndex % 3);
         LocalTime lessonEnd = lessonStart.plusMinutes(45);

         Entry<String> lesson = new Entry<>("Lesson - " + student.getName());
         lesson.setInterval(lessonDate, lessonStart, lessonDate, lessonEnd);
         lesson.setLocation("Maestro");
         lesson.setUserObject("student:" + student.getId());
         lessons.addEntry(lesson);

         lessonIndex++;
      }
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
}
