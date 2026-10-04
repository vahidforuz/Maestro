package com.maestro.gui;

import com.maestro.model.Teacher;
import javafx.geometry.Insets;
import javafx.scene.control.Label;
import javafx.scene.layout.GridPane;

public class TeacherProfileView extends GridPane {

   public TeacherProfileView(Teacher teacher) {
      setHgap(10);
      setVgap(10);
      setPadding(new Insets(20));

      Label title = new Label("Teacher Profile");
      title.setStyle("-fx-font-size: 18px; -fx-font-weight: bold;");

      add(title, 0, 0, 2, 1);

      add(new Label("Teacher ID:"), 0, 1);
      add(new Label(String.valueOf(teacher.getId())), 1, 1);

      add(new Label("Name:"), 0, 2);
      add(new Label(teacher.getName()), 1, 2);

      add(new Label("Phone:"), 0, 3);
      add(new Label(teacher.getTelephone()), 1, 3);

      add(new Label("Email:"), 0, 4);
      add(new Label(teacher.getEmail()), 1, 4);

      add(new Label("Address:"), 0, 5);
      add(new Label(teacher.getAddress()), 1, 5);

      add(new Label("Status:"), 0, 6);
      add(new Label(teacher.getStatus().toString()), 1, 6);
   }
}
