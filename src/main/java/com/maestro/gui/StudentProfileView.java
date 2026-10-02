package com.maestro.gui;

import com.maestro.model.CourseNote;
import com.maestro.model.LessonStatus;
import com.maestro.model.Payment;
import com.maestro.model.Student;
import com.maestro.model.StudentCourse;
import com.maestro.model.StudentProject;
import com.maestro.service.ReviewService;
import com.maestro.service.ReviewService.DueReview;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;
import javafx.application.Platform;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Alert;
import javafx.scene.control.ButtonBar;
import javafx.scene.control.Button;
import javafx.scene.control.ButtonType;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Label;
import javafx.scene.control.ScrollBar;
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
   private static final String COURSE_CARD_STYLE =
         "-fx-border-color: #999999; -fx-border-radius: 4; -fx-background-radius: 4;";
   private static final String SELECTED_COURSE_CARD_STYLE =
         "-fx-border-color: #0f62fe; -fx-border-width: 3; -fx-border-radius: 4; "
               + "-fx-background-color: #eef5ff; -fx-background-radius: 4;";

   public StudentProfileView(
         Student student,
         List<Payment> payments,
         Consumer<StudentProject> addPaymentAction,
         Runnable saveStudentAction) {
      this(student, payments, addPaymentAction, saveStudentAction, null, 0, 0);
   }

   public StudentProfileView(
         Student student,
         List<Payment> payments,
         Consumer<StudentProject> addPaymentAction,
         Runnable saveStudentAction,
         ReviewService reviewService,
         int initialProjectId,
         int initialCourseId) {
      student.ensureEntityIds();
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
                  refreshProjects[0],
                  saveStudentAction,
                  reviewService,
                  initialProjectId,
                  initialCourseId));
         }
      };

      newProjectButton.setOnAction(event -> {
         student.addProject();
         saveStudentAction.run();
         refreshProjects[0].run();
      });

      VBox paymentsSection = createPaymentsSection(student, payments, addPaymentAction);
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
      addInfoRow(grid, 4, 2, "Credit balance:", String.valueOf(student.getPaymentCreditBalance()));

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
         Runnable refreshProjects,
         Runnable saveStudentAction,
         ReviewService reviewService,
         int initialProjectId,
         int initialCourseId) {
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
      List<Label> priceLeftLabels = new ArrayList<>();
      List<VBox> courseBoxes = new ArrayList<>();
      int[] selectedCourseId = {
            project.getId() == initialProjectId && project.findCourseById(initialCourseId) != null
                  ? initialCourseId
                  : 0
      };
      Runnable refreshPriceLeftValues = () -> refreshPriceLeftLabels(priceLeftLabels, projectCourses, payments);
      Runnable refreshSelection = () -> {
         for (int boxIndex = 0; boxIndex < courseBoxes.size(); boxIndex++) {
            StudentCourse rowCourse = projectCourses.get(boxIndex);
            setCourseBoxSelected(courseBoxes.get(boxIndex), rowCourse.getId() == selectedCourseId[0]);
         }
         deleteCourseButton.setDisable(selectedCourseId[0] == 0 || student.getCourses().size() <= 1);
      };
      int selectedCourseIndex = -1;
      for (int index = 0; index < projectCourses.size(); index++) {
         StudentCourse rowCourse = projectCourses.get(index);
         VBox courseBox = createCourseBox(
               student,
               project,
               projectCourses,
               rowCourse,
               index,
               payments,
               priceLeftLabels,
               refreshPriceLeftValues,
               reviewService,
               saveStudentAction);
         courseBox.setOnMouseClicked(event -> {
            selectedCourseId[0] = rowCourse.getId();
            refreshSelection.run();
         });
         courseBoxes.add(courseBox);
         courseRow.getChildren().add(courseBox);
         if (rowCourse.getId() == selectedCourseId[0]) {
            selectedCourseIndex = index;
         }
      }
      refreshPriceLeftValues.run();
      refreshSelection.run();

      ScrollPane coursesScroller = new ScrollPane(courseRow);
      coursesScroller.setFitToHeight(true);
      coursesScroller.setFitToWidth(false);
      coursesScroller.setMinViewportHeight(420);
      coursesScroller.setPrefViewportHeight(Region.USE_COMPUTED_SIZE);
      coursesScroller.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);
      coursesScroller.setHbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
      coursesScroller.setVbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
      coursesScroller.setPannable(true);

      ScrollBar topCourseScroll = new ScrollBar();
      topCourseScroll.setMin(0);
      topCourseScroll.setMax(1);
      topCourseScroll.setUnitIncrement(0.05);
      topCourseScroll.setBlockIncrement(0.2);
      topCourseScroll.valueProperty().bindBidirectional(coursesScroller.hvalueProperty());
      Runnable updateTopCourseScroll = () -> {
         double contentWidth = courseRow.getLayoutBounds().getWidth();
         double viewportWidth = coursesScroller.getViewportBounds().getWidth();
         boolean scrollNeeded = contentWidth > viewportWidth && viewportWidth > 0;
         topCourseScroll.setDisable(!scrollNeeded);
         topCourseScroll.setVisible(scrollNeeded);
         topCourseScroll.setManaged(scrollNeeded);
         topCourseScroll.setVisibleAmount(scrollNeeded ? viewportWidth / contentWidth : 1);
      };
      courseRow.layoutBoundsProperty().addListener((observable, oldValue, newValue) -> updateTopCourseScroll.run());
      coursesScroller.viewportBoundsProperty().addListener((observable, oldValue, newValue) -> updateTopCourseScroll.run());
      updateTopCourseScroll.run();
      if (selectedCourseIndex >= 0) {
         int courseIndexToShow = selectedCourseIndex;
         Platform.runLater(() -> {
            int lastCourseIndex = Math.max(1, projectCourses.size() - 1);
            coursesScroller.setHvalue((double) courseIndexToShow / lastCourseIndex);
         });
      }

      VBox coursesWithTopScroll = new VBox(4, topCourseScroll, coursesScroller);
      coursesWithTopScroll.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);

      newCourseButton.setOnAction(event -> {
         student.addCourseToProject(project);
         saveStudentAction.run();
         refreshProjects.run();
      });
      deleteCourseButton.setOnAction(event -> {
         StudentCourse selectedCourse = findCourseInProject(project, selectedCourseId[0]);
         if (selectedCourse != null && student.getCourses().size() > 1 && confirmDeleteCourse(project, selectedCourse)) {
            student.removeCourse(selectedCourse);
            saveStudentAction.run();
            refreshProjects.run();
         }
      });
      deleteProjectButton.setOnAction(event -> {
         student.removeProject(project);
         saveStudentAction.run();
         refreshProjects.run();
      });

      projectSection.getChildren().addAll(
            projectHeader,
            createPiecesSection(project, refreshProjects, saveStudentAction),
            new Separator(),
            coursesWithTopScroll);
      VBox.setVgrow(coursesWithTopScroll, Priority.NEVER);
      return projectSection;
   }

   private StudentCourse findCourseInProject(StudentProject project, int courseId) {
      for (StudentCourse course : project.getCourses()) {
         if (course.getId() == courseId) {
            return course;
         }
      }
      return null;
   }

   private boolean confirmDeleteCourse(StudentProject project, StudentCourse course) {
      int courseIndex = project.getCourses().indexOf(course) + 1;
      Alert alert = new Alert(Alert.AlertType.CONFIRMATION);
      alert.setTitle("Delete Course");
      alert.setHeaderText("Delete Course " + courseIndex + "?");
      alert.setContentText("Date: " + (course.getDate() == null ? "Not set" : course.getDate()));

      ButtonType deleteType = new ButtonType("Delete", ButtonBar.ButtonData.OK_DONE);
      alert.getButtonTypes().setAll(ButtonType.CANCEL, deleteType);
      return alert.showAndWait().orElse(ButtonType.CANCEL) == deleteType;
   }

   private void setCourseBoxSelected(VBox courseBox, boolean selected) {
      courseBox.setStyle(selected ? SELECTED_COURSE_CARD_STYLE : COURSE_CARD_STYLE);
   }

   private VBox createPiecesSection(StudentProject project, Runnable refreshProjects, Runnable saveStudentAction) {
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
            saveStudentAction.run();
            refreshProjects.run();
         }
      });
      newPieceField.setOnAction(event -> addPieceButton.fire());

      piecesSection.getChildren().addAll(piecesTitle, addPieceRow);

      List<String> pieces = project.getPieces();
      for (int index = 0; index < pieces.size(); index++) {
         piecesSection.getChildren().add(createPieceRow(project, index, refreshProjects, saveStudentAction));
      }

      return piecesSection;
   }

   private HBox createPieceRow(
         StudentProject project,
         int pieceIndex,
         Runnable refreshProjects,
         Runnable saveStudentAction) {
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
               saveStudentAction.run();
               refreshProjects.run();
            }
         });
      });
      deleteButton.setOnAction(event -> {
         project.removePiece(pieceIndex);
         saveStudentAction.run();
         refreshProjects.run();
      });

      return pieceRow;
   }

   private VBox createPaymentsSection(Student student, List<Payment> payments, Consumer<StudentProject> addPaymentAction) {
      Label paymentsTitle = new Label("Payments");
      paymentsTitle.setStyle("-fx-font-weight: bold;");

      Button addPaymentButton = new Button("Add Payment");
      addPaymentButton.setOnAction(event -> addPaymentAction.accept(student.getCurrentProject()));

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
         List<Payment> payments,
         List<Label> priceLeftLabels,
         Runnable refreshPriceLeftValues,
         ReviewService reviewService,
         Runnable saveStudentAction) {
      VBox courseBox = new VBox(10);
      courseBox.setPadding(new Insets(12));
      courseBox.setStyle(COURSE_CARD_STYLE);
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

      ensureCourseDate(course);
      Label dateValue = new Label(formatCourseDate(course));
      dateValue.setMaxWidth(Double.MAX_VALUE);
      dateValue.setWrapText(true);

      dayBox.valueProperty().addListener((observable, oldValue, newValue) -> {
         course.setDay(newValue);
         course.setDate(firstDateForDay(newValue));
         dateValue.setText(formatCourseDate(course));
         updateNoteReviewDates(course);
         saveStudentAction.run();
      });

      TextField hourField = new TextField(course.getHour() == null ? "" : course.getHour().toString());
      hourField.setMaxWidth(Double.MAX_VALUE);
      hourField.textProperty().addListener((observable, oldValue, newValue) -> {
         try {
            course.setHour(newValue == null || newValue.isBlank() ? null : LocalTime.parse(newValue.trim()));
            saveStudentAction.run();
         } catch (DateTimeParseException exception) {
            // Keep the last valid value while the user is typing.
         }
      });

      TextField priceField = new TextField(String.valueOf(course.getPrice()));
      priceField.setMaxWidth(Double.MAX_VALUE);

      Label priceLeftValue = new Label(String.valueOf(getPriceLeft(projectCourses, payments)));
      priceLeftValue.setMaxWidth(Double.MAX_VALUE);
      priceLeftLabels.add(priceLeftValue);

      priceField.textProperty().addListener((observable, oldValue, newValue) -> {
         try {
            course.setPrice(Double.parseDouble(newValue.trim()));
            refreshPriceLeftValues.run();
            saveStudentAction.run();
         } catch (NumberFormatException exception) {
            refreshPriceLeftValues.run();
         }
      });

      ComboBox<LessonStatus> statusBox = new ComboBox<>();
      statusBox.getItems().addAll(LessonStatus.values());
      statusBox.setValue(course.getStatus());
      statusBox.setMaxWidth(Double.MAX_VALUE);
      statusBox.valueProperty().addListener((observable, oldValue, newValue) -> {
         course.setStatus(newValue);
         refreshPriceLeftValues.run();
         saveStudentAction.run();
      });

      TextArea commentArea = new TextArea(course.getComment());
      commentArea.setPrefRowCount(3);
      commentArea.setMinHeight(70);
      commentArea.setMaxWidth(Double.MAX_VALUE);
      commentArea.setWrapText(true);
      commentArea.textProperty().addListener((observable, oldValue, newValue) ->
            {
               course.setComment(newValue);
               saveStudentAction.run();
            });

      TextArea homeworkArea = new TextArea(course.getHomeworkNextLesson());
      homeworkArea.setPrefRowCount(3);
      homeworkArea.setMinHeight(70);
      homeworkArea.setMaxWidth(Double.MAX_VALUE);
      homeworkArea.setWrapText(true);
      homeworkArea.textProperty().addListener((observable, oldValue, newValue) ->
            {
               course.setHomeworkNextLesson(newValue);
               saveStudentAction.run();
            });

      addCourseRow(courseGrid, 0, "Day:", dayBox);
      addCourseRow(courseGrid, 1, "Date:", dateValue);
      addCourseRow(courseGrid, 2, "Start Time:", hourField);
      addCourseRow(courseGrid, 3, "Price:", priceField);
      addCourseRow(courseGrid, 4, "Status:", statusBox);
      addCourseRow(courseGrid, 5, "Price left:", priceLeftValue);
      addCourseRow(courseGrid, 6, "Homework / Next Lesson:", homeworkArea);
      addCourseRow(courseGrid, 7, "Description:", commentArea);

      courseBox.getChildren().addAll(courseTitle, courseGrid, createNotesSection(student, project, course, reviewService, saveStudentAction));
      return courseBox;
   }

   private VBox createNotesSection(
         Student student,
         StudentProject project,
         StudentCourse course,
         ReviewService reviewService,
         Runnable saveStudentAction) {
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
            noteRows.getChildren().add(createNoteBox(project, course, note, refreshNotes[0], saveStudentAction));
         }
      };

      Button addNoteButton = new Button("+ Add Note");
      addNoteButton.setDisable(project.getPieces().isEmpty());
      addNoteButton.setOnAction(event -> {
         String piece = project.getPieces().isEmpty() ? "" : project.getPieces().get(0);
         CourseNote note = course.addNote(piece);
         note.setSourceCourseId(course.getId());
         saveStudentAction.run();
         refreshNotes[0].run();
      });

      VBox dueReviewsSection = createDueReviewsSection(student, course, reviewService, refreshNotes[0]);

      refreshNotes[0].run();
      notesSection.getChildren().addAll(dueReviewsSection, new Separator(), notesTitle, noteRows, addNoteButton);
      return notesSection;
   }

   private VBox createDueReviewsSection(
         Student student,
         StudentCourse course,
         ReviewService reviewService,
         Runnable refreshNotes) {
      VBox reviewSection = new VBox(8);
      reviewSection.setFillWidth(true);
      reviewSection.setMaxWidth(Double.MAX_VALUE);

      Label reviewTitle = new Label("Notes to Review");
      reviewTitle.setStyle("-fx-font-weight: bold;");

      VBox reviewRows = new VBox(8);
      reviewRows.setFillWidth(true);

      Runnable[] refreshReviews = new Runnable[1];
      refreshReviews[0] = () -> {
         reviewRows.getChildren().clear();
         if (reviewService == null) {
            return;
         }

         for (DueReview dueReview : reviewService.getDueReviews(student, course)) {
            reviewRows.getChildren().add(createDueReviewBox(
                  student,
                  course,
                  dueReview,
                  reviewService,
                  refreshReviews[0],
                  refreshNotes));
         }
      };

      refreshReviews[0].run();
      reviewSection.getChildren().addAll(new Separator(), reviewTitle, reviewRows);
      return reviewSection;
   }

   private VBox createDueReviewBox(
         Student student,
         StudentCourse course,
         DueReview dueReview,
         ReviewService reviewService,
         Runnable refreshReviews,
         Runnable refreshNotes) {
      CourseNote note = dueReview.note();
      VBox reviewBox = new VBox(6);
      reviewBox.setPadding(new Insets(8));
      reviewBox.setMaxWidth(Double.MAX_VALUE);
      reviewBox.setStyle("-fx-border-color: #9a9a9a; -fx-border-radius: 4; -fx-background-radius: 4;");

      Label fromLabel = new Label("From: " + formatReviewDate(dueReview.sourceCourseDate()));
      Label pieceLabel = new Label("Piece: " + note.getPiece());
      Label commentLabel = new Label("Comment: " + note.getComment());
      fromLabel.setWrapText(true);
      pieceLabel.setWrapText(true);
      commentLabel.setWrapText(true);

      Button addButton = new Button("Add to This Course");
      addButton.setOnAction(event -> {
         reviewService.acceptReview(student, course, note);
         refreshNotes.run();
         refreshReviews.run();
      });

      Button dismissButton = new Button("Dismiss");
      dismissButton.setOnAction(event -> {
         reviewService.dismissReview(student, note);
         refreshReviews.run();
      });

      HBox actions = new HBox(8, addButton, dismissButton);
      actions.setAlignment(Pos.CENTER_LEFT);
      reviewBox.getChildren().addAll(fromLabel, pieceLabel, commentLabel, actions);
      return reviewBox;
   }

   private VBox createNoteBox(
         StudentProject project,
         StudentCourse course,
         CourseNote note,
         Runnable refreshNotes,
         Runnable saveStudentAction) {
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
      pieceBox.valueProperty().addListener((observable, oldValue, newValue) -> {
         note.setPiece(newValue);
         saveStudentAction.run();
      });

      TextArea commentArea = new TextArea(note.getComment());
      commentArea.setPrefRowCount(3);
      commentArea.setMinHeight(70);
      commentArea.setMaxWidth(Double.MAX_VALUE);
      commentArea.setWrapText(true);
      commentArea.textProperty().addListener((observable, oldValue, newValue) -> {
         note.setComment(newValue);
         saveStudentAction.run();
      });

      ComboBox<ReviewOption> reviewBox = new ComboBox<>();
      reviewBox.getItems().addAll(ReviewOption.values());
      reviewBox.setValue(ReviewOption.fromWeeks(note.getReviewWeeks()));
      reviewBox.setMaxWidth(Double.MAX_VALUE);

      Label reviewDateLabel = new Label(formatReviewDate(note.getReviewDate()));
      reviewDateLabel.setMaxWidth(Double.MAX_VALUE);
      reviewDateLabel.setWrapText(true);

      Button showInReviewWeekButton = new Button("Show in Review Week");
      showInReviewWeekButton.setDisable(reviewBox.getValue() == ReviewOption.NO_REVIEW);

      reviewBox.valueProperty().addListener((observable, oldValue, newValue) -> {
         ReviewOption selected = newValue == null ? ReviewOption.NO_REVIEW : newValue;
         note.setSourceCourseId(course.getId());
         note.setReviewData(
               selected.weeks(),
               selected.weeks() == null || getCourseDate(course) == null
                     ? null
                     : getCourseDate(course).plusWeeks(selected.weeks()),
               note.getReviewStatus(),
               note.getSourceCourseId(),
               note.getAcceptedCourseId());
         reviewDateLabel.setText(formatReviewDate(note.getReviewDate()));
         showInReviewWeekButton.setDisable(selected == ReviewOption.NO_REVIEW);
         saveStudentAction.run();
      });

      showInReviewWeekButton.setOnAction(event -> {
         ReviewOption selected = reviewBox.getValue() == null ? ReviewOption.NO_REVIEW : reviewBox.getValue();
         if (selected != ReviewOption.NO_REVIEW) {
            note.setSourceCourseId(course.getId());
            note.setReviewSchedule(selected.weeks(), getCourseDate(course));
            reviewDateLabel.setText(formatReviewDate(note.getReviewDate()));
            saveStudentAction.run();
         }
      });

      Button deleteButton = new Button("Delete Note");
      deleteButton.setOnAction(event -> {
         course.removeNote(note);
         saveStudentAction.run();
         refreshNotes.run();
      });

      addCourseRow(noteGrid, 0, "Piece:", pieceBox);
      addCourseRow(noteGrid, 1, "Comment:", commentArea);
      addCourseRow(noteGrid, 2, "Review:", reviewBox);
      addCourseRow(noteGrid, 3, "Review Date:", reviewDateLabel);

      HBox actions = new HBox(8, showInReviewWeekButton, deleteButton);
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

   private void refreshPriceLeftLabels(List<Label> priceLeftLabels, List<StudentCourse> courses, List<Payment> payments) {
      String priceLeft = String.valueOf(getPriceLeft(courses, payments));
      for (Label priceLeftLabel : priceLeftLabels) {
         priceLeftLabel.setText(priceLeft);
      }
   }

   private double getPriceLeft(List<StudentCourse> courses, List<Payment> payments) {
      double totalPaid = getTotalPaid(payments);
      for (StudentCourse course : courses) {
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

   private String formatCourseDate(StudentCourse course) {
      if (course.getDate() == null) {
         return "Not set";
      }

      return course.getDate().toString();
   }

   private LocalDate getCourseDate(StudentCourse course) {
      ensureCourseDate(course);
      return course.getDate();
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

   private void ensureCourseDate(StudentCourse course) {
      if (course.getDate() == null && course.getDay() != null) {
         course.setDate(firstDateForDay(course.getDay()));
      }
   }

   private LocalDate firstDateForDay(DayOfWeek day) {
      if (day == null) {
         return null;
      }

      return LocalDate.now().with(TemporalAdjusters.nextOrSame(day));
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
