package com.maestro;

import com.maestro.gui.AddStudentDialog;
import com.maestro.gui.MaestroCalendarView;
import com.maestro.gui.StudentProfileView;
import com.maestro.gui.TeacherAccountDialog;
import com.maestro.gui.TeacherProfileView;
import com.maestro.model.Payment;
import com.maestro.model.Student;
import com.maestro.model.Teacher;
import com.maestro.service.StudentService;
import com.maestro.service.StudentServiceImpl;
import com.maestro.service.TeacherService;
import com.maestro.service.TeacherServiceImpl;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import javafx.application.Application;
import javafx.application.Platform;
import javafx.scene.Scene;
import javafx.scene.control.Alert;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.Menu;
import javafx.scene.control.MenuBar;
import javafx.scene.control.MenuItem;
import javafx.scene.control.Separator;
import javafx.scene.control.TextInputDialog;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Pane;
import javafx.scene.layout.Priority;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

public class MaestroGui extends Application {

   private VBox mainContent;
   private final TeacherService teacherService = new TeacherServiceImpl();
   private final StudentService studentService = new StudentServiceImpl();
   private Teacher currentTeacher;
   private int nextTeacherId = 1;
   private int nextStudentId = 1;

   @Override
   public void start(Stage stage) {

      VBox root = new VBox();

      MenuBar menuBar = createMenuBar();

      mainContent = new VBox();
      mainContent.setSpacing(10);

      root.getChildren().addAll(menuBar, mainContent);

      VBox.setVgrow(mainContent, Priority.ALWAYS);

      Scene scene = new Scene(root, 1000, 700);

      stage.setTitle("Maestro");
      stage.setScene(scene);
      stage.show();

      updateNextTeacherId();
      showWelcomeView();
   }


   private MenuBar createMenuBar() {

      MenuBar menuBar = new MenuBar();

      Menu file = new Menu("File");
      Menu account = new Menu("Account");
      Menu students = new Menu("Students");
      MenuItem signIn = new MenuItem("Sign In");
      MenuItem createTeacherAccount = new MenuItem("Create Teacher Account");
      MenuItem teacherProfile = new MenuItem("Teacher Profile");
      MenuItem addStudent = new MenuItem("Add Student");
      MenuItem calendar = new MenuItem("Calendar");
      MenuItem exit = new MenuItem("Exit");

      exit.setOnAction(event-> {
         Platform.exit();
      });

      signIn.setOnAction(event -> signInTeacher());
      createTeacherAccount.setOnAction(event -> createTeacherAccount());
      teacherProfile.setOnAction(event -> showCurrentTeacherProfile());
      addStudent.setOnAction(event -> addStudentForCurrentTeacher());
      calendar.setOnAction(event -> showTeacherCalendar());

      file.getItems().addAll(exit);
      account.getItems().addAll(signIn, createTeacherAccount, teacherProfile);
      students.getItems().addAll(addStudent, calendar);

      menuBar.getMenus().addAll(file, account, students);

      return menuBar;
   }

   private void showWelcomeView() {
      Label title = new Label("Maestro");
      title.setStyle("-fx-font-size: 24px; -fx-font-weight: bold;");

      Label prompt = new Label("Sign in or create a teacher account to manage students.");

      Button signInButton = new Button("Sign In");
      signInButton.setOnAction(event -> signInTeacher());

      Button createAccountButton = new Button("Create Teacher Account");
      createAccountButton.setOnAction(event -> createTeacherAccount());

      HBox actions = new HBox(10, signInButton, createAccountButton);
      mainContent.getChildren().setAll(title, prompt, actions);
   }

   private void createTeacherAccount() {
      TeacherAccountDialog dialog = new TeacherAccountDialog(nextTeacherId);
      Optional<Teacher> teacher = dialog.showAndWait();

      teacher.ifPresent(createdTeacher -> {
         teacherService.addTeacher(createdTeacher);
         nextTeacherId++;
         currentTeacher = createdTeacher;
         showInfo("Teacher account created. Your teacher ID is: " + createdTeacher.getId());
         showTeacherDashboard();
      });
   }

   private void updateNextTeacherId() {
      int highestTeacherId = 0;
      for (Teacher teacher : teacherService.getAllTeachers()) {
         if (teacher.getId() > highestTeacherId) {
            highestTeacherId = teacher.getId();
         }
      }

      nextTeacherId = highestTeacherId + 1;
   }

   private void signInTeacher() {
      TextInputDialog dialog = new TextInputDialog();
      dialog.setTitle("Teacher Sign In");
      dialog.setHeaderText(null);
      dialog.setContentText("Teacher ID:");

      Optional<String> teacherId = dialog.showAndWait();
      teacherId.ifPresent(this::signInTeacherById);
   }

   private void signInTeacherById(String teacherIdText) {
      try {
         int teacherId = Integer.parseInt(teacherIdText.trim());
         Teacher teacher = teacherService.findTeacherById(teacherId);

         if (teacher == null) {
            showError("Teacher not found.");
            return;
         }

         currentTeacher = teacher;
         showTeacherDashboard();
      } catch (NumberFormatException exception) {
         showError("Teacher ID must be a number.");
      }
   }

   private void showTeacherDashboard() {
      Label title = new Label("Teacher Dashboard");
      title.setStyle("-fx-font-size: 20px; -fx-font-weight: bold;");

      Label signedInTeacher = new Label("Signed in as: " + currentTeacher.getName());
      Label teacherId = new Label("Teacher ID: " + currentTeacher.getId());

      Button addStudentButton = new Button("Add Student");
      addStudentButton.setOnAction(event -> addStudentForCurrentTeacher());

      Button profileButton = new Button("Teacher Profile");
      profileButton.setOnAction(event -> showCurrentTeacherProfile());

      Button calendarButton = new Button("Calendar");
      calendarButton.setOnAction(event -> showTeacherCalendar());

      HBox actions = new HBox(10, addStudentButton, profileButton, calendarButton);
      VBox students = createStudentListView();

      mainContent.getChildren().setAll(title, signedInTeacher, teacherId, actions, new Separator(), students);
   }

   private VBox createStudentListView() {
      VBox students = new VBox(8);
      students.getChildren().add(new Label("Students"));

      List<Student> allStudents = studentService.getAllStudents();
      boolean hasVisibleStudent = false;

      for (Student student : allStudents) {
         if (student.getTeacherId() == null || student.getTeacherId().equals(currentTeacher.getId())) {
            hasVisibleStudent = true;
            Button studentButton = new Button(student.getName());
            studentButton.setOnAction(event -> showStudentProfile(student));
            students.getChildren().add(studentButton);
         }
      }

      if (!hasVisibleStudent) {
         students.getChildren().add(new Label("No students yet."));
      }

      return students;
   }

   private void addStudentForCurrentTeacher() {
      if (currentTeacher == null) {
         showError("Please sign in or create a teacher account first.");
         showWelcomeView();
         return;
      }

      AddStudentDialog dialog = new AddStudentDialog(currentTeacher);
      Optional<Student> student = dialog.showAndWait();

      student.ifPresent(createdStudent -> {
         createdStudent.setId(nextStudentId);
         nextStudentId++;
         studentService.addStudent(createdStudent);
         showStudentProfile(createdStudent);
      });
   }

   private void showCurrentTeacherProfile() {
      if (currentTeacher == null) {
         showError("Please sign in or create a teacher account first.");
         showWelcomeView();
         return;
      }

      Pane profileView = new TeacherProfileView(currentTeacher);
      Button backButton = new Button("Back to Dashboard");
      backButton.setOnAction(event -> showTeacherDashboard());

      mainContent.getChildren().setAll(profileView, backButton);
   }

   private void showTeacherCalendar() {
      if (currentTeacher == null) {
         showError("Please sign in or create a teacher account first.");
         showWelcomeView();
         return;
      }

      Pane calendarView = new MaestroCalendarView(currentTeacher, studentService.getAllStudents());
      VBox.setVgrow(calendarView, Priority.ALWAYS);
      Button backButton = new Button("Back to Dashboard");
      backButton.setOnAction(event -> showTeacherDashboard());

      mainContent.getChildren().setAll(calendarView, backButton);
   }

   private void showStudentProfile(Student student) {
      List<Payment> payments = Collections.emptyList();
      Pane profileView = new StudentProfileView(student, payments);
      Button backButton = new Button("Back to Dashboard");
      backButton.setOnAction(event -> showTeacherDashboard());

      mainContent.getChildren().setAll(profileView, backButton);
   }

   private void showError(String message) {
      Alert alert = new Alert(Alert.AlertType.ERROR);
      alert.setTitle("Maestro");
      alert.setHeaderText(null);
      alert.setContentText(message);
      alert.showAndWait();
   }

   private void showInfo(String message) {
      Alert alert = new Alert(Alert.AlertType.INFORMATION);
      alert.setTitle("Maestro");
      alert.setHeaderText(null);
      alert.setContentText(message);
      alert.showAndWait();
   }

   public static void main(String[] args) {
        launch(args);
   }
}
