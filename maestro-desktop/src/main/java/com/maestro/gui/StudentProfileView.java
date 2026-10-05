package com.maestro.gui;

import com.maestro.model.CourseNote;
import com.maestro.model.Instrument;
import com.maestro.model.LessonStatus;
import com.maestro.model.Level;
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
import javafx.beans.property.ObjectProperty;
import javafx.beans.property.SimpleObjectProperty;
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
   private static final double MIN_PROJECTS_HEIGHT = 260;
   private static final double MIN_PAYMENTS_HEIGHT = 120;

   public StudentProfileView(
         Student student,
         List<Payment> payments,
         Consumer<StudentProject> addPaymentAction,
         Runnable saveStudentAction) {
      this(
            student,
            payments,
            addPaymentAction,
            saveStudentAction,
            null,
            0,
            0,
            new SimpleObjectProperty<>(CourseTitleMode.NUMBER));
   }

   public StudentProfileView(
         Student student,
         List<Payment> payments,
         Consumer<StudentProject> addPaymentAction,
         Runnable saveStudentAction,
         ReviewService reviewService,
         int initialProjectId,
         int initialCourseId) {
      this(
            student,
            payments,
            addPaymentAction,
            saveStudentAction,
            reviewService,
            initialProjectId,
            initialCourseId,
            new SimpleObjectProperty<>(CourseTitleMode.NUMBER));
   }

   public StudentProfileView(
         Student student,
         List<Payment> payments,
         Consumer<StudentProject> addPaymentAction,
         Runnable saveStudentAction,
         ReviewService reviewService,
         int initialProjectId,
         int initialCourseId,
         ObjectProperty<CourseTitleMode> courseTitleMode) {
      this(
            student,
            payments,
            addPaymentAction,
            saveStudentAction,
            reviewService,
            initialProjectId,
            initialCourseId,
            courseTitleMode,
            ProfileSection.OVERVIEW);
   }

   public StudentProfileView(
         Student student,
         List<Payment> payments,
         Consumer<StudentProject> addPaymentAction,
         Runnable saveStudentAction,
         ReviewService reviewService,
         int initialProjectId,
         int initialCourseId,
         ObjectProperty<CourseTitleMode> courseTitleMode,
         ProfileSection initialSection) {
      student.ensureEntityIds();
      setSpacing(18);
      setPadding(new Insets(0));
      setFillWidth(true);
      setMinSize(MIN_PROFILE_WIDTH, 420);
      setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);

      VBox projectsBox = new VBox(12);
      projectsBox.setFillWidth(true);

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

      VBox courseHistoryRows = new VBox(10);
      courseHistoryRows.setFillWidth(true);
      VBox courseHistorySection = createCourseHistorySection(courseHistoryRows);
      Runnable[] refreshCourseHistory = new Runnable[1];
      refreshCourseHistory[0] = () -> refreshCourseHistoryRows(student, courseHistoryRows, courseTitleMode.get());

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
                  refreshCourseHistory[0],
                  courseTitleMode.get(),
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

      Runnable[] startInfoEdit = new Runnable[1];
      VBox infoSection = createStudentInfoSection(student, payments, saveStudentAction, refreshProjects[0], startInfoEdit);
      VBox paymentsSection = createPaymentsSection(student, payments, addPaymentAction);
      paymentsSection.setMinHeight(MIN_PAYMENTS_HEIGHT);

      VBox projectsSection = new VBox(8, projectsScroller, newProjectButton);
      projectsSection.setFillWidth(true);
      projectsSection.setMinHeight(MIN_PROJECTS_HEIGHT);
      projectsSection.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);
      VBox.setVgrow(projectsScroller, Priority.ALWAYS);

      HBox sectionTabs = new HBox(8);
      sectionTabs.setAlignment(Pos.CENTER_LEFT);

      Button infoTab = new Button("Overview");
      Button coursesTab = new Button("Courses");
      Button courseHistoryTab = new Button("Course History");
      Button paymentsTab = new Button("Payments");
      infoTab.setMinWidth(Region.USE_PREF_SIZE);
      coursesTab.setMinWidth(Region.USE_PREF_SIZE);
      courseHistoryTab.setMinWidth(Region.USE_PREF_SIZE);
      paymentsTab.setMinWidth(Region.USE_PREF_SIZE);
      sectionTabs.getChildren().addAll(infoTab, coursesTab, courseHistoryTab, paymentsTab);
      applyTabClass(infoTab);
      applyTabClass(coursesTab);
      applyTabClass(courseHistoryTab);
      applyTabClass(paymentsTab);

      VBox contentContainer = new VBox();
      contentContainer.setFillWidth(true);
      contentContainer.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);

      refreshProjects[0].run();
      refreshCourseHistory[0].run();
      courseTitleMode.addListener((observable, oldValue, newValue) -> {
         refreshProjects[0].run();
         refreshCourseHistory[0].run();
      });
      infoTab.setOnAction(event -> showProfileSection(
            contentContainer, infoSection, infoTab, coursesTab, courseHistoryTab, paymentsTab));
      coursesTab.setOnAction(event -> showProfileSection(
            contentContainer, projectsSection, coursesTab, infoTab, courseHistoryTab, paymentsTab));
      courseHistoryTab.setOnAction(event -> showProfileSection(
            contentContainer, courseHistorySection, courseHistoryTab, infoTab, coursesTab, paymentsTab));
      paymentsTab.setOnAction(event -> showProfileSection(
            contentContainer, paymentsSection, paymentsTab, infoTab, coursesTab, courseHistoryTab));
      if (initialSection == ProfileSection.PAYMENTS) {
         showProfileSection(contentContainer, paymentsSection, paymentsTab, infoTab, coursesTab, courseHistoryTab);
      } else if (initialSection == ProfileSection.COURSES) {
         showProfileSection(contentContainer, projectsSection, coursesTab, infoTab, courseHistoryTab, paymentsTab);
      } else if (initialSection == ProfileSection.COURSE_HISTORY) {
         showProfileSection(contentContainer, courseHistorySection, courseHistoryTab, infoTab, coursesTab, paymentsTab);
      } else {
         showProfileSection(contentContainer, infoSection, infoTab, coursesTab, courseHistoryTab, paymentsTab);
      }

      getChildren().addAll(createStudentProfileHeader(student, infoTab, startInfoEdit), sectionTabs, contentContainer);
      VBox.setVgrow(contentContainer, Priority.ALWAYS);
   }

   private HBox createStudentProfileHeader(Student student, Button infoTab, Runnable[] startInfoEdit) {
      VBox titleBlock = new VBox(4);
      Label pageTitle = new Label("Student Profile");
      pageTitle.getStyleClass().add("page-title");
      Label studentName = new Label(student.getName());
      studentName.getStyleClass().add("card-title");
      Label meta = new Label(
            student.getInstrument() + " - " + student.getLevel() + " - "
                  + (student.getCourseDay() == null ? "No day" : student.getCourseDay())
                  + " " + (student.getCourseHour() == null ? "No time" : student.getCourseHour()));
      meta.getStyleClass().add("muted-text");
      titleBlock.getChildren().addAll(pageTitle, studentName, meta);

      Region spacer = new Region();
      HBox.setHgrow(spacer, Priority.ALWAYS);

      Button editButton = secondaryButton("Edit Student");
      editButton.setOnAction(event -> {
         infoTab.fire();
         if (startInfoEdit[0] != null) {
            startInfoEdit[0].run();
         }
      });

      HBox header = new HBox(16, titleBlock, spacer, editButton);
      header.getStyleClass().add("card");
      header.setAlignment(Pos.CENTER_LEFT);
      return header;
   }

   private void showProfileSection(
         VBox contentContainer,
         Region selectedSection,
         Button selectedTab,
         Button... otherTabs) {
      selectedTab.getStyleClass().remove("tab-button");
      if (!selectedTab.getStyleClass().contains("tab-button-active")) {
         selectedTab.getStyleClass().add("tab-button-active");
      }
      for (Button otherTab : otherTabs) {
         otherTab.getStyleClass().remove("tab-button-active");
         if (!otherTab.getStyleClass().contains("tab-button")) {
            otherTab.getStyleClass().add("tab-button");
         }
      }

      contentContainer.getChildren().setAll(selectedSection);
      VBox.setVgrow(selectedSection, Priority.ALWAYS);
   }

   private VBox createStudentInfoSection(
         Student student,
         List<Payment> payments,
         Runnable saveStudentAction,
         Runnable refreshProjects,
         Runnable[] startInfoEdit) {
      VBox infoSection = new VBox(10);
      infoSection.setFillWidth(true);
      infoSection.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);

      VBox infoContent = new VBox();
      infoContent.setFillWidth(true);
      infoContent.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);

      Button editButton = new Button("Edit");
      Button saveButton = new Button("Save");
      editButton.getStyleClass().add("secondary-button");
      saveButton.getStyleClass().add("primary-button");
      saveButton.setDisable(true);

      Runnable showReadOnlyInfo = () -> infoContent.getChildren().setAll(createStudentInfoGrid(student, payments));
      editButton.setOnAction(event -> {
         infoContent.getChildren().setAll(createEditableStudentInfoGrid(
               student,
               payments,
               saveStudentAction,
               refreshProjects,
               editButton,
               saveButton,
               showReadOnlyInfo));
         editButton.setDisable(true);
         saveButton.setDisable(false);
      });
      startInfoEdit[0] = () -> {
         if (!editButton.isDisabled()) {
            editButton.fire();
         }
      };

      HBox infoActions = new HBox(8, editButton, saveButton);
      infoActions.setAlignment(Pos.CENTER_RIGHT);

      showReadOnlyInfo.run();
      infoSection.getChildren().addAll(infoContent, infoActions);
      VBox.setVgrow(infoContent, Priority.ALWAYS);
      return infoSection;
   }

   private VBox createStudentInfoGrid(Student student, List<Payment> payments) {
      VBox overview = new VBox(14);
      overview.setFillWidth(true);

      VBox personalCard = infoCard("Personal Information");
      personalCard.getChildren().addAll(
            infoLine("First name", student.getFirstName()),
            infoLine("Family name", student.getFamilyName()),
            infoLine("Instrument", student.getInstrument().toString()),
            infoLine("Level", student.getLevel().toString()),
            infoLine("Student type", student.hasTeacher() ? "Linked to teacher #" + student.getTeacherId() : "Standalone"));

      VBox lessonCard = infoCard("Lesson Information");
      lessonCard.getChildren().addAll(
            infoLine("Course day", student.getCourseDay() == null ? "Not set" : student.getCourseDay().toString()),
            infoLine("Course time", student.getCourseHour() == null ? "Not set" : student.getCourseHour().toString()),
            infoLine("Course price", formatMoney(student.getCoursePrice())));

      VBox paymentCard = infoCard("Payment Summary");
      Label statusBadge = statusBadge(isPaid(student, payments) ? "Paid" : "Not paid", isPaid(student, payments) ? "success" : "danger");
      paymentCard.getChildren().addAll(
            infoLine("Balance", formatMoney(student.getPaymentCreditBalance())),
            infoLine("Lessons remaining", String.valueOf(getLessonsRemaining(student, payments))),
            infoLine("Payment status", statusBadge));

      overview.getChildren().addAll(personalCard, lessonCard, paymentCard);
      return overview;
   }

   private GridPane createEditableStudentInfoGrid(
         Student student,
         List<Payment> payments,
         Runnable saveStudentAction,
         Runnable refreshProjects,
         Button editButton,
         Button saveButton,
         Runnable showReadOnlyInfo) {
      GridPane grid = createInfoGrid();

      TextField firstNameField = new TextField(student.getFirstName());
      TextField familyNameField = new TextField(student.getFamilyName());

      ComboBox<Level> levelBox = new ComboBox<>();
      levelBox.getItems().addAll(Level.values());
      levelBox.setValue(student.getLevel());

      ComboBox<Instrument> instrumentBox = new ComboBox<>();
      instrumentBox.getItems().addAll(Instrument.values());
      instrumentBox.setValue(student.getInstrument());

      ComboBox<DayOfWeek> courseDayBox = new ComboBox<>();
      courseDayBox.getItems().addAll(DayOfWeek.values());
      courseDayBox.setValue(student.getCourseDay());

      TextField courseHourField = new TextField(student.getCourseHour() == null ? "" : student.getCourseHour().toString());
      TextField coursePriceField = new TextField(String.valueOf(student.getCoursePrice()));

      addInfoEditRow(grid, 0, 0, "First name:", firstNameField);
      addInfoEditRow(grid, 1, 0, "Family name:", familyNameField);
      addInfoEditRow(grid, 2, 0, "Level:", levelBox);
      addInfoEditRow(grid, 3, 0, "Instrument:", instrumentBox);
      addInfoRow(grid, 4, 0, "Student type:",
            student.hasTeacher() ? "Linked to teacher #" + student.getTeacherId() : "Standalone");
      addInfoEditRow(grid, 0, 2, "Course day:", courseDayBox);
      addInfoEditRow(grid, 1, 2, "Course hour:", courseHourField);
      addInfoEditRow(grid, 2, 2, "Course price:", coursePriceField);
      addInfoRow(grid, 3, 2, "Payment status:", isPaid(student, payments) ? "Paid" : "Not paid");
      addInfoRow(grid, 4, 2, "Credit balance:", String.valueOf(student.getPaymentCreditBalance()));

      saveButton.setOnAction(event -> {
         try {
            student.setFirstName(safeText(firstNameField));
            student.setFamilyName(safeText(familyNameField));
            student.setLevel(levelBox.getValue());
            student.setInstrument(instrumentBox.getValue());
            student.setCourseDay(courseDayBox.getValue());
            student.setCourseHour(parseOptionalTime(courseHourField.getText()));
            student.setCoursePrice(Double.parseDouble(safeText(coursePriceField)));
            saveStudentAction.run();
            refreshProjects.run();
            showReadOnlyInfo.run();
            editButton.setDisable(false);
            saveButton.setDisable(true);
         } catch (DateTimeParseException exception) {
            showInvalidInfoAlert("Course hour must use HH:mm format.");
         } catch (NumberFormatException exception) {
            showInvalidInfoAlert("Course price must be a number.");
         }
      });

      return grid;
   }

   private GridPane createInfoGrid() {
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
      return grid;
   }

   private void addInfoEditRow(GridPane grid, int row, int column, String labelText, Region field) {
      Label label = new Label(labelText);
      label.setMinWidth(Region.USE_PREF_SIZE);
      field.setMaxWidth(Double.MAX_VALUE);

      grid.add(label, column, row);
      grid.add(field, column + 1, row);
      GridPane.setHgrow(field, Priority.ALWAYS);
   }

   private String safeText(TextField field) {
      return field.getText() == null ? "" : field.getText().trim();
   }

   private LocalTime parseOptionalTime(String text) {
      String safeText = text == null ? "" : text.trim();
      return safeText.isEmpty() ? null : LocalTime.parse(safeText);
   }

   private void showInvalidInfoAlert(String message) {
      Alert alert = new Alert(Alert.AlertType.ERROR);
      alert.setTitle("Invalid Student Info");
      alert.setHeaderText(null);
      alert.setContentText(message);
      alert.showAndWait();
   }

   private void addInfoRow(GridPane grid, int row, int column, String labelText, String valueText) {
      Label label = new Label(labelText);
      label.setMinWidth(Region.USE_PREF_SIZE);
      label.getStyleClass().add("field-label");

      Label value = new Label(valueText);
      value.getStyleClass().add("field-value");
      value.setMaxWidth(Double.MAX_VALUE);
      value.setWrapText(true);

      grid.add(label, column, row);
      grid.add(value, column + 1, row);
      GridPane.setHgrow(value, Priority.ALWAYS);
   }

   private void applyTabClass(Button button) {
      button.getStyleClass().add("tab-button");
   }

   private Button primaryButton(String text) {
      Button button = new Button(text);
      button.getStyleClass().add("primary-button");
      return button;
   }

   private Button secondaryButton(String text) {
      Button button = new Button(text);
      button.getStyleClass().add("secondary-button");
      return button;
   }

   private Button dangerButton(String text) {
      Button button = new Button(text);
      button.getStyleClass().add("danger-button");
      return button;
   }

   private VBox infoCard(String titleText) {
      VBox card = new VBox(10);
      card.getStyleClass().add("card");
      card.setMaxWidth(Double.MAX_VALUE);
      Label title = new Label(titleText);
      title.getStyleClass().add("card-title");
      card.getChildren().add(title);
      return card;
   }

   private HBox infoLine(String labelText, String valueText) {
      return infoLine(labelText, createValueLabel(valueText));
   }

   private HBox infoLine(String labelText, Region valueNode) {
      Label label = new Label(labelText);
      label.getStyleClass().add("field-label");
      label.setMinWidth(140);

      HBox row = new HBox(12, label, valueNode);
      row.setAlignment(Pos.CENTER_LEFT);
      HBox.setHgrow(valueNode, Priority.ALWAYS);
      return row;
   }

   private Label createValueLabel(String text) {
      Label label = new Label(text);
      label.getStyleClass().add("field-value");
      label.setWrapText(true);
      label.setMaxWidth(Double.MAX_VALUE);
      return label;
   }

   private Label mutedLabel(String text) {
      Label label = new Label(text);
      label.getStyleClass().add("muted-text");
      label.setWrapText(true);
      return label;
   }

   private Label statusBadge(String text, String status) {
      Label label = new Label(text);
      label.getStyleClass().add(statusClass(status));
      return label;
   }

   private String statusClass(String status) {
      return "success".equals(status) ? "status-success"
            : "danger".equals(status) ? "status-danger"
            : "warning".equals(status) ? "status-warning"
            : "status-neutral";
   }

   private String statusStyle(LessonStatus status) {
      if (status == LessonStatus.PRESENT) {
         return "success";
      }
      if (status == LessonStatus.ABSENT || status == LessonStatus.CANCELED) {
         return "danger";
      }
      if (status == LessonStatus.MOVED) {
         return "warning";
      }
      return "neutral";
   }

   private String formatMoney(double amount) {
      return "$" + String.format("%.2f", amount);
   }

   private int getLessonsRemaining(Student student, List<Payment> payments) {
      double price = student.getCoursePrice();
      return price <= 0 ? 0 : (int) Math.floor(Math.max(0, getTotalPaid(payments)) / price);
   }

   private VBox createCourseHistorySection(VBox courseHistoryRows) {
      Label historyTitle = new Label("Course History");
      historyTitle.getStyleClass().add("card-title");

      ScrollPane historyScroller = new ScrollPane(courseHistoryRows);
      historyScroller.setFitToWidth(true);
      historyScroller.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);
      historyScroller.setHbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
      historyScroller.setVbarPolicy(ScrollPane.ScrollBarPolicy.AS_NEEDED);
      historyScroller.setPannable(true);

      VBox courseHistorySection = new VBox(8, historyTitle, historyScroller);
      courseHistorySection.setFillWidth(true);
      courseHistorySection.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);
      VBox.setVgrow(historyScroller, Priority.ALWAYS);
      return courseHistorySection;
   }

   private void refreshCourseHistoryRows(Student student, VBox courseHistoryRows, CourseTitleMode courseTitleMode) {
      courseHistoryRows.getChildren().clear();

      List<CourseHistoryItem> historyItems = new ArrayList<>();
      for (StudentProject project : student.getProjects()) {
         List<StudentCourse> projectCourses = project.getCourses();
         for (int courseIndex = 0; courseIndex < projectCourses.size(); courseIndex++) {
            StudentCourse course = projectCourses.get(courseIndex);
            if (course.getStatus() == LessonStatus.PRESENT) {
               historyItems.add(new CourseHistoryItem(project, course, courseIndex));
            }
         }
      }

      historyItems.sort((first, second) -> {
         LocalDate firstDate = first.course.getDate();
         LocalDate secondDate = second.course.getDate();
         if (firstDate == null && secondDate == null) {
            return 0;
         }
         if (firstDate == null) {
            return 1;
         }
         if (secondDate == null) {
            return -1;
         }
         return secondDate.compareTo(firstDate);
      });

      for (CourseHistoryItem item : historyItems) {
         courseHistoryRows.getChildren().add(createCourseHistoryCard(
               item.project,
               item.course,
               item.courseIndex,
               courseTitleMode));
      }

      if (historyItems.isEmpty()) {
         courseHistoryRows.getChildren().add(new Label("No passed courses yet."));
      }
   }

   private VBox createCourseHistoryCard(
         StudentProject project,
         StudentCourse course,
         int courseIndex,
         CourseTitleMode courseTitleMode) {
      VBox historyCard = new VBox(8);
      historyCard.setMaxWidth(Double.MAX_VALUE);
      historyCard.getStyleClass().add("compact-card");

      Label date = new Label(formatCourseDate(course));
      date.getStyleClass().add("section-title");

      Label title = new Label(project.getName() + " - " + formatCourseTitle(course, courseIndex, courseTitleMode));
      title.getStyleClass().add("card-title");

      Label status = statusBadge(course.getStatus().toString(), statusStyle(course.getStatus()));
      Label meta = createValueLabel(
            (course.getHour() == null ? "No time" : course.getHour().toString())
                  + " - " + formatMoney(course.getPrice()));
      HBox metaRow = new HBox(8, status, meta);
      metaRow.setAlignment(Pos.CENTER_LEFT);

      Label homeworkTitle = new Label("Homework");
      homeworkTitle.getStyleClass().add("section-title");
      Label homework = createValueLabel(course.getHomeworkNextLesson().isBlank() ? "None" : course.getHomeworkNextLesson());

      Label notesTitle = new Label("Notes");
      notesTitle.getStyleClass().add("section-title");
      Label noteSummary = createValueLabel(summarizeCourseNotes(course));

      historyCard.getChildren().addAll(date, title, metaRow, homeworkTitle, homework, notesTitle, noteSummary);

      VBox marker = new VBox();
      marker.getStyleClass().add("timeline-dot");
      HBox timelineRow = new HBox(12, marker, historyCard);
      HBox.setHgrow(historyCard, Priority.ALWAYS);

      VBox wrapper = new VBox(timelineRow);
      wrapper.setFillWidth(true);
      return wrapper;
   }

   private String summarizeCourseNotes(StudentCourse course) {
      for (CourseNote note : course.getNotes()) {
         String piece = note.getPiece() == null ? "" : note.getPiece().trim();
         String comment = note.getComment() == null ? "" : note.getComment().trim();
         String summary = comment.isEmpty() ? piece : piece.isEmpty() ? comment : piece + ": " + comment;
         if (!summary.isEmpty()) {
            return truncateSummary(summary);
         }
      }

      return "No notes";
   }

   private String truncateSummary(String summary) {
      int maxLength = 120;
      return summary.length() <= maxLength ? summary : summary.substring(0, maxLength - 3) + "...";
   }

   private VBox createProjectSection(
         Student student,
         StudentProject project,
         int projectIndex,
         List<Payment> payments,
         Runnable refreshProjects,
         Runnable saveStudentAction,
         Runnable refreshCourseHistory,
         CourseTitleMode courseTitleMode,
         ReviewService reviewService,
         int initialProjectId,
         int initialCourseId) {
      VBox projectSection = new VBox(8);
      projectSection.setMaxWidth(Double.MAX_VALUE);
      projectSection.getStyleClass().add("card");

      Label projectTitle = new Label("Project " + (projectIndex + 1));
      projectTitle.getStyleClass().add("card-title");
      projectTitle.setMinWidth(Region.USE_PREF_SIZE);

      Region spacer = new Region();
      HBox.setHgrow(spacer, Priority.ALWAYS);

      Button newCourseButton = primaryButton("+ New Course");
      Button deleteCourseButton = dangerButton("Delete Course");
      Button deleteProjectButton = dangerButton("Delete Project");
      deleteCourseButton.setDisable(project.getCourses().isEmpty() || student.getCourses().size() <= 1);
      deleteProjectButton.setDisable(student.getProjects().size() <= 1);

      HBox projectHeader = new HBox(10, projectTitle, spacer, newCourseButton, deleteCourseButton, deleteProjectButton);
      projectHeader.setAlignment(Pos.CENTER_LEFT);

      VBox courseList = new VBox(10);
      courseList.setFillWidth(true);

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
               refreshProjects,
               refreshCourseHistory,
               courseTitleMode,
               reviewService,
               saveStudentAction);
         courseBox.setOnMouseClicked(event -> {
            selectedCourseId[0] = rowCourse.getId();
            refreshSelection.run();
         });
         courseBoxes.add(courseBox);
         courseList.getChildren().add(courseBox);
         if (rowCourse.getId() == selectedCourseId[0]) {
            selectedCourseIndex = index;
         }
      }
      refreshPriceLeftValues.run();
      refreshSelection.run();

      if (selectedCourseIndex >= 0) {
         selectedCourseId[0] = projectCourses.get(selectedCourseIndex).getId();
      }

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
            courseList);
      VBox.setVgrow(courseList, Priority.NEVER);
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
      courseBox.getStyleClass().remove("course-card-selected");
      if (selected) {
         courseBox.getStyleClass().add("course-card-selected");
      }
   }

   private VBox createPiecesSection(StudentProject project, Runnable refreshProjects, Runnable saveStudentAction) {
      VBox piecesSection = new VBox(6);
      piecesSection.setFillWidth(true);
      piecesSection.setMaxWidth(Double.MAX_VALUE);

      Label piecesTitle = new Label("Pieces:");
      piecesTitle.getStyleClass().add("section-title");

      TextField newPieceField = new TextField();
      newPieceField.setPromptText("Piece title");
      newPieceField.setMaxWidth(Double.MAX_VALUE);

      Button addPieceButton = secondaryButton("Add Piece");
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

      Button editButton = secondaryButton("Edit");
      Button deleteButton = dangerButton("Delete");

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
      paymentsTitle.getStyleClass().add("card-title");

      Button addPaymentButton = primaryButton("+ Add Payment");
      addPaymentButton.setOnAction(event -> addPaymentAction.accept(student.getCurrentProject()));

      HBox paymentHeader = new HBox(10, paymentsTitle, addPaymentButton);
      paymentHeader.setAlignment(Pos.CENTER_LEFT);

      HBox summaryCards = new HBox(12);
      summaryCards.getChildren().addAll(
            paymentSummaryCard("Total Credit", formatMoney(getTotalPaid(payments))),
            paymentSummaryCard("Lessons Remaining", String.valueOf(getLessonsRemaining(student, payments))),
            paymentSummaryCard("Last Payment", formatLastPayment(payments)));

      VBox paymentRows = new VBox(8);
      paymentRows.setFillWidth(true);
      if (payments.isEmpty()) {
         paymentRows.getChildren().add(mutedLabel("No payments yet."));
      } else {
         for (Payment payment : payments) {
            paymentRows.getChildren().add(createPaymentRow(student, payment));
         }
      }

      ScrollPane paymentScroller = new ScrollPane(paymentRows);
      paymentScroller.setFitToWidth(true);
      paymentScroller.setMinViewportHeight(80);
      paymentScroller.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);
      paymentScroller.setHbarPolicy(ScrollPane.ScrollBarPolicy.AS_NEEDED);
      paymentScroller.setVbarPolicy(ScrollPane.ScrollBarPolicy.AS_NEEDED);

      VBox paymentsSection = new VBox(12, paymentHeader, summaryCards, paymentScroller);
      paymentsSection.setFillWidth(true);
      paymentsSection.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);
      VBox.setVgrow(paymentScroller, Priority.ALWAYS);
      return paymentsSection;
   }

   private VBox paymentSummaryCard(String title, String value) {
      VBox card = new VBox(6);
      card.getStyleClass().add("compact-card");
      card.setMinWidth(170);
      HBox.setHgrow(card, Priority.ALWAYS);

      Label titleLabel = new Label(title);
      titleLabel.getStyleClass().add("field-label");
      Label valueLabel = new Label(value);
      valueLabel.getStyleClass().add("card-title");

      card.getChildren().addAll(titleLabel, valueLabel);
      return card;
   }

   private HBox createPaymentRow(Student student, Payment payment) {
      HBox row = new HBox(14);
      row.getStyleClass().add("compact-card");
      row.setAlignment(Pos.CENTER_LEFT);
      row.setMaxWidth(Double.MAX_VALUE);

      Label date = createValueLabel(String.valueOf(payment.getPaymentDate()));
      Label amount = createValueLabel(formatMoney(payment.getAmount()));
      Label method = createValueLabel(payment.getMethod() == null || payment.getMethod().isBlank() ? "No method" : payment.getMethod());
      Label coursesAdded = createValueLabel(student.getCoursePrice() <= 0
            ? "Courses added: n/a"
            : "Courses added: handled by credit");
      Label status = statusBadge("Recorded", "success");

      row.getChildren().addAll(date, amount, method, coursesAdded, status);
      HBox.setHgrow(coursesAdded, Priority.ALWAYS);
      return row;
   }

   private String formatLastPayment(List<Payment> payments) {
      Payment lastPayment = null;
      for (Payment payment : payments) {
         if (lastPayment == null
               || (payment.getPaymentDate() != null
               && (lastPayment.getPaymentDate() == null || payment.getPaymentDate().isAfter(lastPayment.getPaymentDate())))) {
            lastPayment = payment;
         }
      }

      return lastPayment == null ? "None" : formatMoney(lastPayment.getAmount()) + " on " + lastPayment.getPaymentDate();
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
         Runnable refreshProjects,
         Runnable refreshCourseHistory,
         CourseTitleMode courseTitleMode,
         ReviewService reviewService,
         Runnable saveStudentAction) {
      VBox courseBox = new VBox(10);
      courseBox.getStyleClass().add("compact-card");
      courseBox.setMaxWidth(Double.MAX_VALUE);

      Label courseTitle = new Label(formatCourseTitle(course, courseIndex, courseTitleMode));
      courseTitle.getStyleClass().add("card-title");
      courseTitle.setMinWidth(Region.USE_PREF_SIZE);

      Button openLessonButton = secondaryButton("Open Lesson");
      openLessonButton.setMinWidth(Region.USE_PREF_SIZE);

      Button changeDateButton = secondaryButton("Change Date");
      changeDateButton.setMinWidth(Region.USE_PREF_SIZE);

      Button passCourseButton = primaryButton("Pass Course");
      passCourseButton.setMinWidth(Region.USE_PREF_SIZE);

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
         courseTitle.setText(formatCourseTitle(course, courseIndex, courseTitleMode));
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
      Label compactStatus = statusBadge(course.getStatus().toString(), statusStyle(course.getStatus()));
      statusBox.valueProperty().addListener((observable, oldValue, newValue) -> {
         course.setStatus(newValue);
         compactStatus.setText(course.getStatus().toString());
         compactStatus.getStyleClass().setAll(statusClass(statusStyle(course.getStatus())));
         refreshPriceLeftValues.run();
         refreshCourseHistory.run();
         passCourseButton.setDisable(course.getStatus() == LessonStatus.PRESENT);
         saveStudentAction.run();
      });
      passCourseButton.setDisable(course.getStatus() == LessonStatus.PRESENT);
      passCourseButton.setOnAction(event -> statusBox.setValue(LessonStatus.PRESENT));
      changeDateButton.setOnAction(event -> changeCourseDate(course, saveStudentAction, refreshProjects, refreshCourseHistory));

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

      Region titleSpacer = new Region();
      HBox.setHgrow(titleSpacer, Priority.ALWAYS);
      HBox courseHeader = new HBox(8, courseTitle, titleSpacer, compactStatus, openLessonButton);
      courseHeader.setAlignment(Pos.CENTER_LEFT);

      Label dateSummary = createValueLabel(formatCourseDate(course) + " - " + (course.getHour() == null ? "No time" : course.getHour()));
      Label priceSummary = createValueLabel("Price: " + formatMoney(course.getPrice()));
      Label homeworkSummary = createValueLabel("Homework: "
            + (course.getHomeworkNextLesson().isBlank() ? "None" : course.getHomeworkNextLesson()));
      HBox compactDetails = new HBox(18, dateSummary, priceSummary);
      compactDetails.setAlignment(Pos.CENTER_LEFT);

      VBox lessonEditor = new VBox(12);
      lessonEditor.setFillWidth(true);
      lessonEditor.setVisible(false);
      lessonEditor.setManaged(false);
      HBox editorActions = new HBox(8, changeDateButton, passCourseButton);
      editorActions.setAlignment(Pos.CENTER_RIGHT);
      lessonEditor.getChildren().addAll(editorActions, courseGrid, createNotesSection(student, project, course, reviewService, saveStudentAction));

      openLessonButton.setOnAction(event -> {
         boolean open = !lessonEditor.isVisible();
         lessonEditor.setVisible(open);
         lessonEditor.setManaged(open);
         openLessonButton.setText(open ? "Close Lesson" : "Open Lesson");
      });

      courseBox.getChildren().addAll(courseHeader, compactDetails, homeworkSummary, lessonEditor);
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
      notesTitle.getStyleClass().add("section-title");

      VBox noteRows = new VBox(8);
      noteRows.setFillWidth(true);

      Runnable[] refreshNotes = new Runnable[1];
      refreshNotes[0] = () -> {
         noteRows.getChildren().clear();
         for (CourseNote note : course.getNotes()) {
            noteRows.getChildren().add(createNoteBox(project, course, note, refreshNotes[0], saveStudentAction));
         }
      };

      Button addNoteButton = primaryButton("+ Add Note");
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
      reviewTitle.getStyleClass().add("section-title");

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
      reviewBox.setMaxWidth(Double.MAX_VALUE);
      reviewBox.getStyleClass().add("compact-card");

      Label fromLabel = new Label("From: " + formatReviewDate(dueReview.sourceCourseDate()));
      Label pieceLabel = new Label("Piece: " + note.getPiece());
      Label commentLabel = new Label("Comment: " + note.getComment());
      fromLabel.setWrapText(true);
      pieceLabel.setWrapText(true);
      commentLabel.setWrapText(true);

      Button addButton = secondaryButton("Add to This Course");
      addButton.setOnAction(event -> {
         reviewService.acceptReview(student, course, note);
         refreshNotes.run();
         refreshReviews.run();
      });

      Button dismissButton = secondaryButton("Dismiss");
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
      noteBox.setMaxWidth(Double.MAX_VALUE);
      noteBox.getStyleClass().add("compact-card");

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

      Button showInReviewWeekButton = secondaryButton("Show in Review Week");
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

      Button deleteButton = dangerButton("Delete Note");
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

   private String formatCourseTitle(StudentCourse course, int courseIndex, CourseTitleMode courseTitleMode) {
      CourseTitleMode safeMode = courseTitleMode == null ? CourseTitleMode.NUMBER : courseTitleMode;
      switch (safeMode) {
         case COURSE_AND_DATE:
            return "Course - " + formatCourseDate(course);
         case COURSE_ONLY:
            return "Course";
         case NUMBER:
         default:
            return "Course " + (courseIndex + 1);
      }
   }

   private void changeCourseDate(
         StudentCourse course,
         Runnable saveStudentAction,
         Runnable refreshProjects,
         Runnable refreshCourseHistory) {
      TextInputDialog dialog = new TextInputDialog(course.getDate() == null ? "" : course.getDate().toString());
      dialog.setTitle("Change Course Date");
      dialog.setHeaderText(null);
      dialog.setContentText("Course date (yyyy-MM-dd):");
      dialog.showAndWait().ifPresent(dateText -> {
         try {
            String safeDateText = dateText == null ? "" : dateText.trim();
            course.setDate(safeDateText.isEmpty() ? null : LocalDate.parse(safeDateText));
            updateNoteReviewDates(course);
            saveStudentAction.run();
            refreshProjects.run();
            refreshCourseHistory.run();
         } catch (DateTimeParseException exception) {
            showInvalidInfoAlert("Course date must use yyyy-MM-dd format.");
         }
      });
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

   public enum CourseTitleMode {
      NUMBER("Course 1, 2, 3"),
      COURSE_AND_DATE("Course + Date"),
      COURSE_ONLY("Course Only");

      private final String label;

      CourseTitleMode(String label) {
         this.label = label;
      }

      @Override
      public String toString() {
         return label;
      }
   }

   public enum ProfileSection {
      OVERVIEW,
      COURSES,
      COURSE_HISTORY,
      PAYMENTS
   }

   private static class CourseHistoryItem {
      private final StudentProject project;
      private final StudentCourse course;
      private final int courseIndex;

      private CourseHistoryItem(StudentProject project, StudentCourse course, int courseIndex) {
         this.project = project;
         this.course = course;
         this.courseIndex = courseIndex;
      }
   }
}
