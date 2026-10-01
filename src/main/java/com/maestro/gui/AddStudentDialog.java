package com.maestro.gui;

import com.maestro.model.Instrument;
import com.maestro.model.Level;
import com.maestro.model.Student;
import com.maestro.model.Teacher;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import javafx.geometry.Insets;
import javafx.scene.control.Alert;
import javafx.scene.control.ButtonType;
import javafx.scene.control.CheckBox;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Dialog;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;
import javafx.scene.layout.GridPane;

public class AddStudentDialog extends Dialog<Student> {

   public AddStudentDialog() {
      this(null);
   }

   public AddStudentDialog(Teacher currentTeacher) {
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

      ComboBox<DayOfWeek> courseDayBox = new ComboBox<>();
      courseDayBox.getItems().addAll(DayOfWeek.values());
      courseDayBox.setValue(DayOfWeek.MONDAY);

      TextField courseHourField = new TextField("16:00");
      TextField coursePriceField = new TextField("0");

      CheckBox linkedToTeacherBox = new CheckBox("Link to current teacher");
      linkedToTeacherBox.setSelected(currentTeacher != null);
      linkedToTeacherBox.setDisable(currentTeacher == null);

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

      grid.add(new Label("Course day:"), 0, 6);
      grid.add(courseDayBox, 1, 6);

      grid.add(new Label("Course hour:"), 0, 7);
      grid.add(courseHourField, 1, 7);

      grid.add(new Label("Course price:"), 0, 8);
      grid.add(coursePriceField, 1, 8);

      grid.add(new Label("Student type:"), 0, 9);
      grid.add(linkedToTeacherBox, 1, 9);

      getDialogPane().setContent(grid);
      getDialogPane().getButtonTypes().addAll(ButtonType.CANCEL, ButtonType.OK);

      setResultConverter(button -> {
         if (button == ButtonType.OK) {
            LocalTime courseHour;
            double coursePrice;

            try {
               courseHour = LocalTime.parse(courseHourField.getText().trim());
               coursePrice = Double.parseDouble(coursePriceField.getText().trim());
            } catch (DateTimeParseException exception) {
               showError("Course hour must use HH:mm format, for example 16:00.");
               return null;
            } catch (NumberFormatException exception) {
               showError("Course price must be a number.");
               return null;
            }

            return new Student(
                  firstNameField.getText(),
                  lastNameField.getText(),
                  phoneField.getText(),
                  emailField.getText(),
                  instrumentBox.getValue(),
                  levelBox.getValue(),
                  linkedToTeacherBox.isSelected() && currentTeacher != null
                        ? currentTeacher.getId()
                        : null,
                  courseDayBox.getValue(),
                  courseHour,
                  coursePrice);
         }

         return null;
      });
   }

   private void showError(String message) {
      Alert alert = new Alert(Alert.AlertType.ERROR);
      alert.setTitle("Maestro");
      alert.setHeaderText(null);
      alert.setContentText(message);
      alert.showAndWait();
   }
}
