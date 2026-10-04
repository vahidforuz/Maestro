package com.maestro.gui;

import com.maestro.model.Teacher;
import javafx.geometry.Insets;
import javafx.scene.control.ButtonType;
import javafx.scene.control.Dialog;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;
import javafx.scene.layout.GridPane;

public class TeacherAccountDialog extends Dialog<Teacher> {

   public TeacherAccountDialog(int nextTeacherId) {
      setTitle("Create Teacher Account");
      setHeaderText(null);

      TextField nameField = new TextField();
      TextField phoneField = new TextField();
      TextField emailField = new TextField();
      TextField addressField = new TextField();

      GridPane grid = new GridPane();
      grid.setHgap(10);
      grid.setVgap(10);
      grid.setPadding(new Insets(20));

      grid.add(new Label("Name:"), 0, 0);
      grid.add(nameField, 1, 0);

      grid.add(new Label("Phone:"), 0, 1);
      grid.add(phoneField, 1, 1);

      grid.add(new Label("Email:"), 0, 2);
      grid.add(emailField, 1, 2);

      grid.add(new Label("Address:"), 0, 3);
      grid.add(addressField, 1, 3);

      getDialogPane().setContent(grid);
      getDialogPane().getButtonTypes().addAll(ButtonType.CANCEL, ButtonType.OK);

      setResultConverter(button -> {
         if (button == ButtonType.OK) {
            return new Teacher(
                  nextTeacherId,
                  nameField.getText(),
                  phoneField.getText(),
                  emailField.getText(),
                  addressField.getText());
         }

         return null;
      });
   }
}
