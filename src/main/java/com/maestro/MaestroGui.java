package com.maestro;

import com.maestro.gui.AddStudentDialog;
import com.maestro.gui.StudentProfileView;
import com.maestro.model.Payment;
import com.maestro.model.Student;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import javafx.application.Application;
import javafx.application.Platform;
import javafx.scene.Scene;
import javafx.scene.control.Label;
import javafx.scene.control.Menu;
import javafx.scene.control.MenuBar;
import javafx.scene.control.MenuItem;
import javafx.scene.layout.Pane;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

public class MaestroGui extends Application {

   private VBox mainContent;

   @Override
   public void start(Stage stage) {

      VBox root = new VBox();

      MenuBar menuBar = createMenuBar();

      Label title = new Label("Maestro");

      mainContent = new VBox(title);
      mainContent.setSpacing(10);

      root.getChildren().addAll(menuBar, mainContent);

      Scene scene = new Scene(root, 600, 400);

      stage.setTitle("Maestro");
      stage.setScene(scene);
      stage.show();
   }


   private MenuBar createMenuBar() {

      MenuBar menuBar = new MenuBar();

      Menu file = new Menu("File");
      Menu option = new Menu("Option");
      MenuItem newStudent = new MenuItem("New Student");
      MenuItem newTeacher = new MenuItem("New Teacher");
      MenuItem open = new MenuItem("Open");
      MenuItem save = new MenuItem("Save");
      MenuItem exit = new MenuItem("Exit");

      exit.setOnAction(event-> {
         Platform.exit();
      });

      newStudent.setOnAction(event -> {
         AddStudentDialog dialog = new AddStudentDialog();
         Optional<Student> student = dialog.showAndWait();

         student.ifPresent(this::showStudentProfile);
      });

      file.getItems().addAll(newTeacher, newStudent, open, save, exit);

      menuBar.getMenus().addAll(file, option);

      return menuBar;
   }

   private void showStudentProfile(Student student) {
      List<Payment> payments = Collections.emptyList();
      Pane profileView = new StudentProfileView(student, payments);
      mainContent.getChildren().setAll(profileView);
   }

   public static void main(String[] args) {
        launch(args);
   }
}
