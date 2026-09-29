package com.maestro.gui;

import javafx.geometry.Insets;
import javafx.scene.control.ButtonType;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Dialog;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;
import javafx.scene.layout.GridPane;

public class AddStudentDialog extends Dialog<Void> {

   public AddStudentDialog() {
      setTitle("Add New Student");
      setHeaderText(null);

      TextField firstNameField = new TextField();
      TextField lastNameField = new TextField();
      TextField phoneField = new TextField();
      TextField emailField = new TextField();

      ComboBox<String> instrumentBox = new ComboBox<>();
      instrumentBox.getItems().addAll("Piano", "Guitar", "Violin", "Drums", "Voice");
      instrumentBox.setValue("Piano");

      ComboBox<String> levelBox = new ComboBox<>();
      levelBox.getItems().addAll("Beginner", "Intermediate", "Advanced");
      levelBox.setValue("Beginner");

      GridPane grid = new GridPane();
      grid.setHgap(10);
      grid.setVgap(10);
      grid.setPadding(new Insets(20));

      grid.add(new Label("First name:"), 0, 0);
      grid.add(firstNameField, 1, 0);

      grid.add(new Label("Last name:"), 0, 1);
      grid.add(lastNameField, 1, 1);

      grid.add(new Label("Phone:"), 0, 2);
      grid.add(phoneField, 1, 2);

      grid.add(new Label("Email:"), 0, 3);
      grid.add(emailField, 1, 3);

      grid.add(new Label("Instrument:"), 0, 4);
      grid.add(instrumentBox, 1, 4);

      grid.add(new Label("Level:"), 0, 5);
      grid.add(levelBox, 1, 5);

      getDialogPane().setContent(grid);
      getDialogPane().getButtonTypes().addAll(ButtonType.CANCEL, ButtonType.OK);

      setResultConverter(button -> {
         if (button == ButtonType.OK) {
            String firstName = firstNameField.getText();
            String lastName = lastNameField.getText();
            String phone = phoneField.getText();
            String email = emailField.getText();
            String instrument = instrumentBox.getValue();
            String level = levelBox.getValue();

            System.out.println("Saving student: " + firstName + " " + lastName);
         }

         return null;
      });
   }
}
