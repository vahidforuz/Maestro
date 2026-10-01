package com.maestro.gui;

import com.maestro.model.Instrument;
import com.maestro.model.Level;
import com.maestro.model.Student;
import javafx.geometry.Insets;
import javafx.scene.control.ButtonType;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Dialog;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;
import javafx.scene.layout.GridPane;

public class AddStudentDialog extends Dialog<Student> {

   public AddStudentDialog() {
      setTitle("Add New Student");
      setHeaderText(null);

      TextField firstNameField = new TextField();
      TextField lastNameField = new TextField();
      TextField phoneField = new TextField();
      TextField emailField = new TextField();

      ComboBox<Instrument> instrumentBox = new ComboBox<>();
      instrumentBox.getItems().addAll(Instrument.values());
      instrumentBox.setValue(Instrument.PIANO);

      ComboBox<Level> levelBox = new ComboBox<>();
      levelBox.getItems().addAll(Level.values());
      levelBox.setValue(Level.BEGINNER);

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
            return new Student(
                  firstNameField.getText(),
                  lastNameField.getText(),
                  phoneField.getText(),
                  emailField.getText(),
                  instrumentBox.getValue(),
                  levelBox.getValue());
         }

         return null;
      });
   }
}
