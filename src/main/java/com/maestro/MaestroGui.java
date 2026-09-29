package com.maestro;

import com.maestro.gui.AddStudentDialog;
import javafx.application.Application;
import javafx.application.Platform;
import javafx.scene.Scene;
import javafx.scene.control.Label;
import javafx.scene.control.Menu;
import javafx.scene.control.MenuBar;
import javafx.scene.control.MenuItem;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

public class MaestroGui extends Application {

   @Override
   public void start(Stage stage) {

      VBox root = new VBox();

      MenuBar menuBar = createMenuBar();

      Label title = new Label("Maestro");

      root.getChildren().addAll(menuBar, title);

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
         dialog.showAndWait();
      });

      file.getItems().addAll(newTeacher, newStudent, open, save, exit);

      menuBar.getMenus().addAll(file, option);

      return menuBar;
   }

   public static void main(String[] args) {
        launch(args);
   }
}
