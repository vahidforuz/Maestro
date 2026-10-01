package com.maestro;

import com.maestro.gui.AddStudentDialog;
import com.maestro.gui.MaestroCalendarView;
import com.maestro.gui.StudentProfileView;
import com.maestro.gui.TeacherAccountDialog;
import com.maestro.gui.TeacherProfileView;
import com.maestro.model.LessonStatus;
import com.maestro.model.Payment;
import com.maestro.model.Student;
import com.maestro.model.StudentCourse;
import com.maestro.model.Teacher;
import com.maestro.service.StudentService;
import com.maestro.service.StudentServiceImpl;
import com.maestro.service.PaymentService;
import com.maestro.service.PaymentServiceImpl;
import com.maestro.service.TeacherService;
import com.maestro.service.TeacherServiceImpl;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import javafx.application.Application;
import javafx.application.Platform;
import javafx.geometry.Insets;
import javafx.scene.Scene;
import javafx.scene.control.Alert;
import javafx.scene.control.Button;
import javafx.scene.control.ButtonType;
import javafx.scene.control.DatePicker;
import javafx.scene.control.Dialog;
import javafx.scene.control.Label;
import javafx.scene.control.Menu;
import javafx.scene.control.MenuBar;
import javafx.scene.control.MenuItem;
import javafx.scene.control.Separator;
import javafx.scene.control.TextArea;
import javafx.scene.control.TextField;
import javafx.scene.layout.GridPane;
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
   private final PaymentService paymentService = new PaymentServiceImpl();
   private Teacher currentTeacher;
   private int nextTeacherId = 1;
   private int nextStudentId = 1;

   @Override
   public void start(Stage stage) {

      VBox root = new VBox();

      MenuBar menuBar = createMenuBar();

      mainContent = new VBox();
      mainContent.setSpacing(10);
      mainContent.setFillWidth(true);
      mainContent.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);

      root.getChildren().addAll(menuBar, mainContent);

      VBox.setVgrow(mainContent, Priority.ALWAYS);

      Scene scene = new Scene(root, 1000, 700);

      stage.setTitle("Maestro");
      stage.setScene(scene);
      stage.setMinWidth(760);
      stage.setMinHeight(560);
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

            Label classTime = new Label("Class: " + formatClassTime(student));
            Label paymentLeft = new Label("Payment left: " + getPaymentLeft(student));

            HBox studentRow = new HBox(10, studentButton, classTime, paymentLeft);
            students.getChildren().add(studentRow);
         }
      }

      if (!hasVisibleStudent) {
         students.getChildren().add(new Label("No students yet."));
      }

      return students;
   }

   private String formatClassTime(Student student) {
      String day = student.getCourseDay() == null ? "Not set" : student.getCourseDay().toString();
      String hour = student.getCourseHour() == null ? "Not set" : student.getCourseHour().toString();
      return day + " " + hour;
   }

   private double getPaymentLeft(Student student) {
      double totalPaid = paymentService.getTotalPaidByStudent(student);
      for (StudentCourse course : student.getCourses()) {
         if (course.getStatus() == LessonStatus.PRESENT || course.getStatus() == LessonStatus.ABSENT) {
            totalPaid -= course.getPrice();
         }
      }

      return totalPaid;
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

      Pane calendarView = new MaestroCalendarView(currentTeacher, studentService.getAllStudents(), paymentService);
      VBox.setVgrow(calendarView, Priority.ALWAYS);
      Button backButton = new Button("Back to Dashboard");
      backButton.setOnAction(event -> showTeacherDashboard());

      mainContent.getChildren().setAll(calendarView, backButton);
   }

   private void showStudentProfile(Student student) {
      List<Payment> payments = paymentService.getPaymentsByStudent(student);
      Pane profileView = new StudentProfileView(student, payments, () -> addPaymentForStudent(student));
      VBox.setVgrow(profileView, Priority.ALWAYS);
      Button backButton = new Button("Back to Dashboard");
      backButton.setOnAction(event -> showTeacherDashboard());

      mainContent.getChildren().setAll(profileView, backButton);
   }

   private void addPaymentForStudent(Student student) {
      Dialog<Payment> dialog = new Dialog<>();
      dialog.setTitle("Add Payment");
      dialog.setHeaderText(null);

      TextField amountField = new TextField();
      amountField.setPromptText("Amount");

      DatePicker paymentDatePicker = new DatePicker(LocalDate.now());

      TextField methodField = new TextField();
      methodField.setPromptText("Cash, card, transfer...");

      TextArea noteArea = new TextArea();
      noteArea.setPrefRowCount(3);
      noteArea.setWrapText(true);

      GridPane grid = new GridPane();
      grid.setHgap(10);
      grid.setVgap(10);
      grid.setPadding(new Insets(20));

      grid.add(new Label("Amount:"), 0, 0);
      grid.add(amountField, 1, 0);
      grid.add(new Label("Date:"), 0, 1);
      grid.add(paymentDatePicker, 1, 1);
      grid.add(new Label("Method:"), 0, 2);
      grid.add(methodField, 1, 2);
      grid.add(new Label("Note:"), 0, 3);
      grid.add(noteArea, 1, 3);

      dialog.getDialogPane().setContent(grid);
      dialog.getDialogPane().getButtonTypes().addAll(ButtonType.CANCEL, ButtonType.OK);

      dialog.setResultConverter(button -> {
         if (button != ButtonType.OK) {
            return null;
         }

         try {
            double amount = Double.parseDouble(amountField.getText().trim());
            return new Payment(
                  student,
                  amount,
                  paymentDatePicker.getValue(),
                  methodField.getText(),
                  noteArea.getText());
         } catch (NumberFormatException exception) {
            showError("Payment amount must be a number.");
            return null;
         }
      });

      Optional<Payment> payment = dialog.showAndWait();
      payment.ifPresent(createdPayment -> {
         paymentService.addPayment(createdPayment);
         showStudentProfile(student);
      });
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
