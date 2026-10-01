package com.maestro.gui;

import com.maestro.model.Payment;
import com.maestro.model.Student;
import javafx.geometry.Insets;
import javafx.scene.control.Label;
import javafx.scene.layout.GridPane;

import java.util.List;

public class StudentProfileView extends GridPane {

   public StudentProfileView(Student student, List<Payment> payments) {
      add(new Label("Payments:"), 0, 6);
      int row = 7;


      setHgap(10);
      setVgap(10);
      setPadding(new Insets(20));

      Label title = new Label("Student Profile");
      title.setStyle("-fx-font-size: 18px; -fx-font-weight: bold;");

      add(title, 0, 0, 2, 1);

      add(new Label("First name:"), 0, 1);
      add(new Label(student.getFirstName()), 1, 1);

      add(new Label("Family name:"), 0, 2);
      add(new Label(student.getFamilyName()), 1, 2);

      add(new Label("Level:"), 0, 3);
      add(new Label(student.getLevel().toString()), 1, 3);

      add(new Label("Instrument:"), 0, 4);
      add(new Label(student.getInstrument().toString()), 1, 4);
      
      for (Payment payment : payments) {
         String paymentText = payment.getAmount()
            + " | "
            + payment.getPaymentDate()
            + " | "
            + payment.getMethod();

         add(new Label(paymentText), 1, row);
         row++;
      }

   }
}
