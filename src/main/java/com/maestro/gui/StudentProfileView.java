package com.maestro.gui;

import com.maestro.model.CourseNote;
import com.maestro.model.LessonStatus;
import com.maestro.model.Payment;
import com.maestro.model.Student;
import com.maestro.model.StudentCourse;
import com.maestro.model.StudentProject;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Button;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Label;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.Separator;
import javafx.scene.control.SplitPane;
import javafx.scene.control.TextArea;
import javafx.scene.control.TextField;
import javafx.scene.control.TextInputDialog;
import javafx.scene.layout.ColumnConstraints;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.Region;
import javafx.scene.layout.VBox;

public class StudentProfileView extends VBox {

   private static final double MIN_PROFILE_WIDTH = 520;
   private static final double MIN_COURSE_CARD_WIDTH = 520;
   private static final double PREFERRED_COURSE_CARD_WIDTH = 560;
   private static final double MIN_PROJECTS_HEIGHT = 260;
   private static final double MIN_PAYMENTS_HEIGHT = 120;

   public StudentProfileView(Student student, List<Payment> payments, Runnable addPaymentAction) {
      setSpacing(10);
      setPadding(new Insets(20));
      setFillWidth(true);
      setMinSize(MIN_PROFILE_WIDTH, 420);
      setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);

      Label title = new Label("Student Profile");
      title.setStyle("-fx-font-size: 18px; -fx-font-weight: bold;");

      GridPane studentInfo = createStudentInfoGrid(student, payments);

      VBox projectsBox = new VBox(12);
      projectsBox.setFillWidth(true);
      projectsBox.setPadding(new Insets(0, 8, 8, 0));

      ScrollPane projectsScroller = new ScrollPane(projectsBox);
      projectsScroller.setFitToWidth(true);
      projectsScroller.setMinViewportHeight(MIN_PROJECTS_HEIGHT);
      projectsScroller.setMinHeight(MIN_PROJECTS_HEIGHT);
      projectsScroller.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);
      projectsScroller.setHbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
      projectsScroller.setVbarPolicy(ScrollPane.ScrollBarPolicy.AS_NEEDED);
      projectsScroller.setPannable(true);

      Button newProjectButton = new Button("+ New Project");
      newProjectButton.setMinWidth(Region.USE_PREF_SIZE);

      Runnable[] refreshProjects = new Runnable[1];
      refreshProjects[0] = () -> {
         projectsBox.getChildren().clear();
         List<StudentProject> projects = student.getProjects();
         for (int index = 0; index < projects.size(); index++) {
            projectsBox.getChildren().add(createProjectSection(
                  student,
                  projects.get(index),
                  index,
                  payments,
                  refreshProjects[0]));
         }
      };

      newProjectButton.setOnAction(event -> {
         student.addProject();
         refreshProjects[0].run();
      });

      VBox paymentsSection = createPaymentsSection(payments, addPaymentAction);
      paymentsSection.setMinHeight(MIN_PAYMENTS_HEIGHT);

      VBox projectsSection = new VBox(8, projectsScroller, newProjectButton);
      projectsSection.setFillWidth(true);
      projectsSection.setMinHeight(MIN_PROJECTS_HEIGHT);
      projectsSection.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);
      VBox.setVgrow(projectsScroller, Priority.ALWAYS);

      SplitPane workArea = new SplitPane(projectsSection, paymentsSection);
      workArea.setOrientation(javafx.geometry.Orientation.VERTICAL);
      workArea.setDividerPositions(0.78);
      workArea.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);

      refreshProjects[0].run();
      getChildren().addAll(title, studentInfo, workArea);
      VBox.setVgrow(workArea, Priority.ALWAYS);
   }

   private GridPane createStudentInfoGrid(Student student, List<Payment> payments) {
      GridPane grid = new GridPane();
      grid.setHgap(14);
      grid.setVgap(6);
      grid.setMaxWidth(Double.MAX_VALUE);

      ColumnConstraints leftLabelColumn = new ColumnConstraints();
      leftLabelColumn.setMinWidth(90);
      leftLabelColumn.setPrefWidth(105);

      ColumnConstraints leftValueColumn = new ColumnConstraints();
      leftValueColumn.setMinWidth(100);
      leftValueColumn.setHgrow(Priority.ALWAYS);
      leftValueColumn.setFillWidth(true);

      ColumnConstraints rightLabelColumn = new ColumnConstraints();
      rightLabelColumn.setMinWidth(105);
      rightLabelColumn.setPrefWidth(120);

      ColumnConstraints rightValueColumn = new ColumnConstraints();
      rightValueColumn.setMinWidth(100);
      rightValueColumn.setHgrow(Priority.ALWAYS);
      rightValueColumn.setFillWidth(true);

      grid.getColumnConstraints().addAll(leftLabelColumn, leftValueColumn, rightLabelColumn, rightValueColumn);

      addInfoRow(grid, 0, 0, "First name:", student.getFirstName());
      addInfoRow(grid, 1, 0, "Family name:", student.getFamilyName());
      addInfoRow(grid, 2, 0, "Level:", student.getLevel().toString());
      addInfoRow(grid, 3, 0, "Instrument:", student.getInstrument().toString());
      addInfoRow(grid, 4, 0, "Student type:",
            student.hasTeacher() ? "Linked to teacher #" + student.getTeacherId() : "Standalone");
      addInfoRow(grid, 0, 2, "Course day:", student.getCourseDay() == null ? "Not set" : student.getCourseDay().toString());
      addInfoRow(grid, 1, 2, "Course hour:", student.getCourseHour() == null ? "Not set" : student.getCourseHour().toString());
      addInfoRow(grid, 2, 2, "Course price:", String.valueOf(student.getCoursePrice()));
      addInfoRow(grid, 3, 2, "Payment status:", isPaid(student, payments) ? "Paid" : "Not paid");

      return grid;
   }

   private void addInfoRow(GridPane grid, int row, int column, String labelText, String valueText) {
      Label label = new Label(labelText);
      label.setMinWidth(Region.USE_PREF_SIZE);

      Label value = new Label(valueText);
      value.setMaxWidth(Double.MAX_VALUE);
      value.setWrapText(true);

      grid.add(label, column, row);
      grid.add(value, column + 1, row);
      GridPane.setHgrow(value, Priority.ALWAYS);
   }

   private VBox createProjectSection(
         Student student,
         StudentProject project,
         int projectIndex,
         List<Payment> payments,
         Runnable refreshProjects) {
      VBox projectSection = new VBox(8);
      projectSection.setPadding(new Insets(10));
      projectSection.setMaxWidth(Double.MAX_VALUE);
      projectSection.setStyle("-fx-border-color: #b6b6b6; -fx-border-radius: 4; -fx-background-radius: 4;");

      Label projectTitle = new Label("Project " + (projectIndex + 1));
      projectTitle.setStyle("-fx-font-weight: bold;");
      projectTitle.setMinWidth(Region.USE_PREF_SIZE);

      Region spacer = new Region();
      HBox.setHgrow(spacer, Priority.ALWAYS);

      Button newCourseButton = new Button("New Course");
      Button deleteCourseButton = new Button("Delete Course");
      Button deleteProjectButton = new Button("Delete Project");
      deleteCourseButton.setDisable(project.getCourses().isEmpty() || student.getCourses().size() <= 1);
      deleteProjectButton.setDisable(student.getProjects().size() <= 1);

      HBox projectHeader = new HBox(10, projectTitle, spacer, newCourseButton, deleteCourseButton, deleteProjectButton);
      projectHeader.setAlignment(Pos.CENTER_LEFT);

      HBox courseRow = new HBox(10);
      courseRow.setPadding(new Insets(0, 0, 8, 0));

      List<StudentCourse> projectCourses = project.getCourses();
      for (int index = 0; index < projectCourses.size(); index++) {
         courseRow.getChildren().add(createCourseBox(student, project, projectCourses, projectCourses.get(index), index, payments));
      }

      ScrollPane coursesScroller = new ScrollPane(courseRow);
      coursesScroller.setFitToHeight(true);
      coursesScroller.setFitToWidth(false);
      coursesScroller.setMinViewportHeight(420);
      coursesScroller.setPrefViewportHeight(Region.USE_COMPUTED_SIZE);
      coursesScroller.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);
      coursesScroller.setHbarPolicy(ScrollPane.ScrollBarPolicy.AS_NEEDED);
      coursesScroller.setVbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
      coursesScroller.setPannable(true);

      newCourseButton.setOnAction(event -> {
         student.addCourseToProject(project);
         refreshProjects.run();
      });
      deleteCourseButton.setOnAction(event -> {
         if (!project.getCourses().isEmpty() && student.getCourses().size() > 1) {
            student.removeCourse(project.getCourses().get(project.getCourses().size() - 1));
            refreshProjects.run();
         }
      });
      deleteProjectButton.setOnAction(event -> {
         student.removeProject(project);
         refreshProjects.run();
      });

      projectSection.getChildren().addAll(projectHeader, createPiecesSection(project, refreshProjects), new Separator(), coursesScroller);
      VBox.setVgrow(coursesScroller, Priority.NEVER);
      return projectSection;
   }

   private VBox createPiecesSection(StudentProject project, Runnable refreshProjects) {
      VBox piecesSection = new VBox(6);
      piecesSection.setFillWidth(true);
      piecesSection.setMaxWidth(Double.MAX_VALUE);

      Label piecesTitle = new Label("Pieces:");
      piecesTitle.setStyle("-fx-font-weight: bold;");

      TextField newPieceField = new TextField();
      newPieceField.setPromptText("Piece title");
      newPieceField.setMaxWidth(Double.MAX_VALUE);

      Button addPieceButton = new Button("Add Piece");
      addPieceButton.setMinWidth(Region.USE_PREF_SIZE);

      HBox addPieceRow = new HBox(10, newPieceField, addPieceButton);
      addPieceRow.setAlignment(Pos.CENTER_LEFT);
      HBox.setHgrow(newPieceField, Priority.ALWAYS);

      addPieceButton.setOnAction(event -> {
         String pieceName = newPieceField.getText() == null ? "" : newPieceField.getText().trim();
         if (!pieceName.isEmpty()) {
            project.addPiece(pieceName);
            refreshProjects.run();
         }
      });
      newPieceField.setOnAction(event -> addPieceButton.fire());

      piecesSection.getChildren().addAll(piecesTitle, addPieceRow);

      List<String> pieces = project.getPieces();
      for (int index = 0; index < pieces.size(); index++) {
         piecesSection.getChildren().add(createPieceRow(project, index, refreshProjects));
      }

      return piecesSection;
   }

   private HBox createPieceRow(StudentProject project, int pieceIndex, Runnable refreshProjects) {
      Label pieceLabel = new Label(project.getPieces().get(pieceIndex));
      pieceLabel.setMaxWidth(Double.MAX_VALUE);
      pieceLabel.setWrapText(true);

      Button editButton = new Button("Edit");
      Button deleteButton = new Button("Delete");

      HBox pieceRow = new HBox(10, pieceLabel, editButton, deleteButton);
      pieceRow.setAlignment(Pos.CENTER_LEFT);
      HBox.setHgrow(pieceLabel, Priority.ALWAYS);

      editButton.setOnAction(event -> {
         TextInputDialog dialog = new TextInputDialog(project.getPieces().get(pieceIndex));
         dialog.setTitle("Edit Piece");
         dialog.setHeaderText(null);
         dialog.setContentText("Piece title:");
         dialog.showAndWait().ifPresent(pieceName -> {
            if (!pieceName.trim().isEmpty()) {
               project.setPiece(pieceIndex, pieceName.trim());
               refreshProjects.run();
            }
         });
      });
      deleteButton.setOnAction(event -> {
         project.removePiece(pieceIndex);
         refreshProjects.run();
      });

      return pieceRow;
   }

   private VBox createPaymentsSection(List<Payment> payments, Runnable addPaymentAction) {
      Label paymentsTitle = new Label("Payments");
      paymentsTitle.setStyle("-fx-font-weight: bold;");

      Button addPaymentButton = new Button("Add Payment");
      addPaymentButton.setOnAction(event -> addPaymentAction.run());

      HBox paymentHeader = new HBox(10, paymentsTitle, addPaymentButton);
      paymentHeader.setAlignment(Pos.CENTER_LEFT);

      VBox paymentRows = new VBox(6);
      paymentRows.setFillWidth(true);
      if (payments.isEmpty()) {
         paymentRows.getChildren().add(new Label("No payments yet."));
      } else {
         for (Payment payment : payments) {
            Label paymentText = new Label(
                  payment.getAmount() + " | " + payment.getPaymentDate() + " | " + payment.getMethod());
            paymentText.setMaxWidth(Double.MAX_VALUE);
            paymentText.setWrapText(true);
            paymentRows.getChildren().add(paymentText);
         }
      }

      ScrollPane paymentScroller = new ScrollPane(paymentRows);
      paymentScroller.setFitToWidth(true);
      paymentScroller.setMinViewportHeight(80);
      paymentScroller.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);
      paymentScroller.setHbarPolicy(ScrollPane.ScrollBarPolicy.AS_NEEDED);
      paymentScroller.setVbarPolicy(ScrollPane.ScrollBarPolicy.AS_NEEDED);

      VBox paymentsSection = new VBox(8, paymentHeader, paymentScroller);
      paymentsSection.setFillWidth(true);
      paymentsSection.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);
      VBox.setVgrow(paymentScroller, Priority.ALWAYS);
      return paymentsSection;
   }

   private VBox createCourseBox(
         Student student,
         StudentProject project,
         List<StudentCourse> projectCourses,
         StudentCourse course,
         int courseIndex,
         List<Payment> payments) {
      VBox courseBox = new VBox(10);
      courseBox.setPadding(new Insets(12));
      courseBox.setStyle("-fx-border-color: #999999; -fx-border-radius: 4; -fx-background-radius: 4;");
      courseBox.setMinWidth(MIN_COURSE_CARD_WIDTH);
      courseBox.setPrefWidth(PREFERRED_COURSE_CARD_WIDTH);
      courseBox.setMaxWidth(PREFERRED_COURSE_CARD_WIDTH);

      Label courseTitle = new Label("Course " + (courseIndex + 1));
      courseTitle.setStyle("-fx-font-weight: bold;");
      courseTitle.setMinWidth(Region.USE_PREF_SIZE);

      GridPane courseGrid = new GridPane();
      courseGrid.setHgap(10);
      courseGrid.setVgap(10);
      courseGrid.setMaxWidth(Double.MAX_VALUE);

      ColumnConstraints labelColumn = new ColumnConstraints();
      labelColumn.setMinWidth(170);
      labelColumn.setPrefWidth(175);

      ColumnConstraints fieldColumn = new ColumnConstraints();
      fieldColumn.setMinWidth(240);
      fieldColumn.setHgrow(Priority.ALWAYS);
      fieldColumn.setFillWidth(true);

      courseGrid.getColumnConstraints().addAll(labelColumn, fieldColumn);

      ComboBox<DayOfWeek> dayBox = new ComboBox<>();
      dayBox.getItems().addAll(DayOfWeek.values());
      dayBox.setValue(course.getDay());
      dayBox.setMaxWidth(Double.MAX_VALUE);

      Label dateValue = new Label(formatCourseDate(course.getDay()));
      dateValue.setMaxWidth(Double.MAX_VALUE);
      dateValue.setWrapText(true);

      dayBox.valueProperty().addListener((observable, oldValue, newValue) -> {
         course.setDay(newValue);
         dateValue.setText(formatCourseDate(newValue));
         updateNoteReviewDates(course);
      });

      TextField hourField = new TextField(course.getHour() == null ? "" : course.getHour().toString());
      hourField.setMaxWidth(Double.MAX_VALUE);
      hourField.textProperty().addListener((observable, oldValue, newValue) -> {
         try {
            course.setHour(newValue == null || newValue.isBlank() ? null : LocalTime.parse(newValue.trim()));
         } catch (DateTimeParseException exception) {
            // Keep the last valid value while the user is typing.
         }
      });

      TextField priceField = new TextField(String.valueOf(course.getPrice()));
      priceField.setMaxWidth(Double.MAX_VALUE);

      Label priceLeftValue = new Label(String.valueOf(getPriceLeft(projectCourses, payments, courseIndex)));
      priceLeftValue.setMaxWidth(Double.MAX_VALUE);

      priceField.textProperty().addListener((observable, oldValue, newValue) -> {
         try {
            course.setPrice(Double.parseDouble(newValue.trim()));
            priceLeftValue.setText(String.valueOf(getPriceLeft(projectCourses, payments, courseIndex)));
         } catch (NumberFormatException exception) {
            priceLeftValue.setText(String.valueOf(getPriceLeft(projectCourses, payments, courseIndex)));
         }
      });

      ComboBox<LessonStatus> statusBox = new ComboBox<>();
      statusBox.getItems().addAll(LessonStatus.values());
      statusBox.setValue(course.getStatus());
      statusBox.setMaxWidth(Double.MAX_VALUE);
      statusBox.valueProperty().addListener((observable, oldValue, newValue) -> {
         course.setStatus(newValue);
         priceLeftValue.setText(String.valueOf(getPriceLeft(projectCourses, payments, courseIndex)));
      });

      TextArea commentArea = new TextArea(course.getComment());
      commentArea.setPrefRowCount(3);
      commentArea.setMinHeight(70);
      commentArea.setMaxWidth(Double.MAX_VALUE);
      commentArea.setWrapText(true);
      commentArea.textProperty().addListener((observable, oldValue, newValue) ->
            course.setComment(newValue));

      TextArea homeworkArea = new TextArea(course.getHomeworkNextLesson());
      homeworkArea.setPrefRowCount(3);
      homeworkArea.setMinHeight(70);
      homeworkArea.setMaxWidth(Double.MAX_VALUE);
      homeworkArea.setWrapText(true);
      homeworkArea.textProperty().addListener((observable, oldValue, newValue) ->
            course.setHomeworkNextLesson(newValue));

      addCourseRow(courseGrid, 0, "Day:", dayBox);
      addCourseRow(courseGrid, 1, "Date:", dateValue);
      addCourseRow(courseGrid, 2, "Start Time:", hourField);
      addCourseRow(courseGrid, 3, "Price:", priceField);
      addCourseRow(courseGrid, 4, "Status:", statusBox);
      addCourseRow(courseGrid, 5, "Price left:", priceLeftValue);
      addCourseRow(courseGrid, 6, "Homework / Next Lesson:", homeworkArea);
      addCourseRow(courseGrid, 7, "Description:", commentArea);

      courseBox.getChildren().addAll(courseTitle, courseGrid, createNotesSection(project, course));
      return courseBox;
   }

   private VBox createNotesSection(StudentProject project, StudentCourse course) {
      VBox notesSection = new VBox(8);
      notesSection.setFillWidth(true);
      notesSection.setMaxWidth(Double.MAX_VALUE);

      Label notesTitle = new Label("Lesson Notes");
      notesTitle.setStyle("-fx-font-weight: bold;");

      VBox noteRows = new VBox(8);
      noteRows.setFillWidth(true);

      Runnable[] refreshNotes = new Runnable[1];
      refreshNotes[0] = () -> {
         noteRows.getChildren().clear();
         for (CourseNote note : course.getNotes()) {
            noteRows.getChildren().add(createNoteBox(project, course, note, refreshNotes[0]));
         }
      };

      Button addNoteButton = new Button("+ Add Note");
      addNoteButton.setDisable(project.getPieces().isEmpty());
      addNoteButton.setOnAction(event -> {
         String piece = project.getPieces().isEmpty() ? "" : project.getPieces().get(0);
         CourseNote note = course.addNote(piece);
         note.setReviewSchedule(1, getCourseDate(course));
         refreshNotes[0].run();
      });

      refreshNotes[0].run();
      notesSection.getChildren().addAll(new Separator(), notesTitle, noteRows, addNoteButton);
      return notesSection;
   }

   private VBox createNoteBox(
         StudentProject project,
         StudentCourse course,
         CourseNote note,
         Runnable refreshNotes) {
      VBox noteBox = new VBox(8);
      noteBox.setPadding(new Insets(8));
      noteBox.setMaxWidth(Double.MAX_VALUE);
      noteBox.setStyle("-fx-border-color: #cfcfcf; -fx-border-radius: 4; -fx-background-radius: 4;");

      GridPane noteGrid = new GridPane();
      noteGrid.setHgap(10);
      noteGrid.setVgap(8);
      noteGrid.setMaxWidth(Double.MAX_VALUE);

      ColumnConstraints labelColumn = new ColumnConstraints();
      labelColumn.setMinWidth(75);
      labelColumn.setPrefWidth(80);
      ColumnConstraints fieldColumn = new ColumnConstraints();
      fieldColumn.setMinWidth(260);
      fieldColumn.setHgrow(Priority.ALWAYS);
      fieldColumn.setFillWidth(true);
      noteGrid.getColumnConstraints().addAll(labelColumn, fieldColumn);

      ComboBox<String> pieceBox = new ComboBox<>();
      pieceBox.getItems().addAll(project.getPieces());
      pieceBox.setValue(note.getPiece().isEmpty() && !project.getPieces().isEmpty()
            ? project.getPieces().get(0)
            : note.getPiece());
      note.setPiece(pieceBox.getValue() == null ? "" : pieceBox.getValue());
      pieceBox.setMaxWidth(Double.MAX_VALUE);
      pieceBox.valueProperty().addListener((observable, oldValue, newValue) -> note.setPiece(newValue));

      TextArea commentArea = new TextArea(note.getComment());
      commentArea.setPrefRowCount(3);
      commentArea.setMinHeight(70);
      commentArea.setMaxWidth(Double.MAX_VALUE);
      commentArea.setWrapText(true);
      commentArea.textProperty().addListener((observable, oldValue, newValue) -> note.setComment(newValue));

      ComboBox<ReviewOption> reviewBox = new ComboBox<>();
      reviewBox.getItems().addAll(ReviewOption.values());
      reviewBox.setValue(ReviewOption.fromWeeks(note.getReviewWeeks()));
      reviewBox.setMaxWidth(Double.MAX_VALUE);

      Label reviewDateLabel = new Label(formatReviewDate(note.getReviewDate()));
      reviewDateLabel.setMaxWidth(Double.MAX_VALUE);
      reviewDateLabel.setWrapText(true);

      reviewBox.valueProperty().addListener((observable, oldValue, newValue) -> {
         ReviewOption selected = newValue == null ? ReviewOption.NO_REVIEW : newValue;
         note.setReviewSchedule(selected.weeks(), getCourseDate(course));
         reviewDateLabel.setText(formatReviewDate(note.getReviewDate()));
      });

      Button deleteButton = new Button("Delete Note");
      deleteButton.setOnAction(event -> {
         course.removeNote(note);
         refreshNotes.run();
      });

      addCourseRow(noteGrid, 0, "Piece:", pieceBox);
      addCourseRow(noteGrid, 1, "Comment:", commentArea);
      addCourseRow(noteGrid, 2, "Review:", reviewBox);
      addCourseRow(noteGrid, 3, "Review Date:", reviewDateLabel);

      HBox actions = new HBox(deleteButton);
      actions.setAlignment(Pos.CENTER_RIGHT);

      noteBox.getChildren().addAll(noteGrid, actions);
      return noteBox;
   }

   private void addCourseRow(GridPane grid, int row, String labelText, Region field) {
      Label label = new Label(labelText);
      label.setMinWidth(Region.USE_PREF_SIZE);
      field.setMaxWidth(Double.MAX_VALUE);

      grid.add(label, 0, row);
      grid.add(field, 1, row);
      GridPane.setHgrow(field, Priority.ALWAYS);
   }

   private boolean isPaid(Student student, List<Payment> payments) {
      return getTotalPaid(payments) >= student.getCoursePrice();
   }

   private double getPriceLeft(List<StudentCourse> courses, List<Payment> payments, int courseIndex) {
      double totalPaid = getTotalPaid(payments);
      int lastIndex = Math.min(courseIndex, courses.size() - 1);

      for (int index = 0; index <= lastIndex; index++) {
         StudentCourse course = courses.get(index);
         if (doesConsumeCourse(course.getStatus())) {
            totalPaid -= course.getPrice();
         }
      }

      return totalPaid;
   }

   private double getTotalPaid(List<Payment> payments) {
      double total = 0;
      for (Payment payment : payments) {
         total += payment.getAmount();
      }

      return total;
   }

   private boolean doesConsumeCourse(LessonStatus status) {
      return status == LessonStatus.PRESENT || status == LessonStatus.ABSENT;
   }

   private String formatCourseDate(DayOfWeek day) {
      if (day == null) {
         return "Not set";
      }

      return LocalDate.now().with(TemporalAdjusters.nextOrSame(day)).toString();
   }

   private LocalDate getCourseDate(StudentCourse course) {
      if (course.getDay() == null) {
         return null;
      }

      return LocalDate.now().with(TemporalAdjusters.nextOrSame(course.getDay()));
   }

   private void updateNoteReviewDates(StudentCourse course) {
      LocalDate courseDate = getCourseDate(course);
      for (CourseNote note : course.getNotes()) {
         note.setReviewSchedule(note.getReviewWeeks(), courseDate);
      }
   }

   private String formatReviewDate(LocalDate reviewDate) {
      return reviewDate == null ? "No review" : reviewDate.toString();
   }

   private enum ReviewOption {
      NEXT_WEEK("Next week", 1),
      IN_2_WEEKS("In 2 weeks", 2),
      IN_3_WEEKS("In 3 weeks", 3),
      IN_4_WEEKS("In 4 weeks", 4),
      NO_REVIEW("No review", null);

      private final String label;
      private final Integer weeks;

      ReviewOption(String label, Integer weeks) {
         this.label = label;
         this.weeks = weeks;
      }

      private Integer weeks() {
         return weeks;
      }

      private static ReviewOption fromWeeks(Integer weeks) {
         for (ReviewOption option : values()) {
            if (option.weeks == null && weeks == null) {
               return option;
            }
            if (option.weeks != null && option.weeks.equals(weeks)) {
               return option;
            }
         }

         return NO_REVIEW;
      }

      @Override
      public String toString() {
         return label;
      }
   }
}
