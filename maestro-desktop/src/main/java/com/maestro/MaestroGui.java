package com.maestro;

import com.maestro.gui.AddStudentDialog;
import com.maestro.gui.MaestroCalendarView;
import com.maestro.gui.StudentProfileView;
import com.maestro.gui.StudentProfileView.CourseTitleMode;
import com.maestro.gui.TeacherAccountDialog;
import com.maestro.gui.TeacherProfileView;
import com.maestro.database.DatabaseInitializer;
import com.maestro.database.LegacyDataMigrator;
import com.maestro.database.SQLiteDatabaseProvider;
import com.maestro.model.CourseNote;
import com.maestro.model.LessonStatus;
import com.maestro.model.Payment;
import com.maestro.model.ReviewStatus;
import com.maestro.model.Student;
import com.maestro.model.StudentCourse;
import com.maestro.model.StudentProject;
import com.maestro.model.Teacher;
import com.maestro.service.StudentService;
import com.maestro.service.StudentServiceImpl;
import com.maestro.service.PaymentService;
import com.maestro.service.PaymentServiceImpl;
import com.maestro.service.ReviewService;
import com.maestro.service.ReviewServiceImpl;
import com.maestro.service.TeacherService;
import com.maestro.service.TeacherServiceImpl;
import com.maestro.repository.RepositoryFactory;
import com.maestro.repository.sqlite.SQLiteRepositoryFactory;
import java.io.InputStream;
import java.net.URL;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.Month;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.time.format.TextStyle;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import javafx.application.Application;
import javafx.application.Platform;
import javafx.beans.property.ReadOnlyStringWrapper;
import javafx.beans.property.ObjectProperty;
import javafx.beans.property.SimpleObjectProperty;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.geometry.Insets;
import javafx.scene.Scene;
import javafx.scene.control.Alert;
import javafx.scene.control.Button;
import javafx.scene.control.ButtonType;
import javafx.scene.control.ComboBox;
import javafx.scene.control.DatePicker;
import javafx.scene.control.Dialog;
import javafx.scene.control.Label;
import javafx.scene.control.TableColumn;
import javafx.scene.control.TableRow;
import javafx.scene.control.TableView;
import javafx.scene.control.TextArea;
import javafx.scene.control.TextField;
import javafx.scene.control.RadioButton;
import javafx.scene.control.ScrollPane;
import javafx.scene.layout.GridPane;
import javafx.scene.control.TextInputDialog;
import javafx.scene.control.ToggleGroup;
import javafx.scene.image.Image;
import javafx.scene.image.ImageView;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.FlowPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Pane;
import javafx.scene.layout.Priority;
import javafx.scene.layout.Region;
import javafx.scene.layout.TilePane;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

public class MaestroGui extends Application {

   private static final String APPLICATION_ICON_PATH = "/images/maestro-icon.png";
   private static final String[] WINDOW_ICON_PATHS = {
         "/images/window-icons/maestro-icon-16.png",
         "/images/window-icons/maestro-icon-24.png",
         "/images/window-icons/maestro-icon-32.png",
         "/images/window-icons/maestro-icon-48.png",
         "/images/window-icons/maestro-icon-64.png",
         "/images/window-icons/maestro-icon-128.png"
   };
   private static final double SIDEBAR_LOGO_SIZE = 36;

   private VBox mainContent;
   private final List<Button> navigationButtons = new java.util.ArrayList<>();
   private final SQLiteDatabaseProvider databaseProvider = new SQLiteDatabaseProvider(Path.of("data", "music_school.db"));
   private final RepositoryFactory repositoryFactory = createRepositoryFactory();
   private final TeacherService teacherService = new TeacherServiceImpl(repositoryFactory.teachers());
   private final StudentService studentService = new StudentServiceImpl(repositoryFactory.students());
   private final PaymentService paymentService = new PaymentServiceImpl(
         repositoryFactory.payments(),
         repositoryFactory.students(),
         repositoryFactory.transactionManager());
   private final ReviewService reviewService = new ReviewServiceImpl(repositoryFactory.students());
   private final ObjectProperty<CourseTitleMode> courseTitleMode =
         new SimpleObjectProperty<>(CourseTitleMode.NUMBER);
   private Teacher currentTeacher;
   private int nextTeacherId = 1;
   private int nextStudentId = 1;

   private RepositoryFactory createRepositoryFactory() {
      new DatabaseInitializer(databaseProvider).initialize();
      RepositoryFactory factory = new SQLiteRepositoryFactory(databaseProvider);
      new LegacyDataMigrator(
            databaseProvider,
            factory.transactionManager(),
            factory.teachers(),
            factory.students(),
            factory.payments()).migrateIfNeeded();
      return factory;
   }

   @Override
   public void start(Stage stage) {

      BorderPane root = new BorderPane();
      root.getStyleClass().add("app-shell");

      mainContent = new VBox();
      mainContent.getStyleClass().add("page");
      mainContent.setFillWidth(true);
      mainContent.setMaxSize(Double.MAX_VALUE, Double.MAX_VALUE);

      root.setLeft(createSidebar());
      root.setCenter(mainContent);

      Scene scene = new Scene(root, 1200, 760);
      scene.getStylesheets().add(getClass().getResource("/maestro.css").toExternalForm());

      stage.setTitle("Maestro");
      applyApplicationIcon(stage);
      stage.setScene(scene);
      stage.setMinWidth(980);
      stage.setMinHeight(650);
      stage.show();

      updateNextTeacherId();
      updateNextStudentId();
      showWelcomeView();
   }


   private VBox createSidebar() {
      VBox sidebar = new VBox();
      sidebar.getStyleClass().add("sidebar");
      sidebar.setFillWidth(true);

      ImageView logoImage = createApplicationLogoView(SIDEBAR_LOGO_SIZE);

      Label logoText = new Label("Maestro");
      logoText.getStyleClass().add("sidebar-brand-title");

      HBox logo = new HBox(10, logoImage, logoText);
      logo.setAlignment(javafx.geometry.Pos.CENTER_LEFT);
      logo.getStyleClass().add("sidebar-brand");

      Label subtitle = new Label("Music teaching studio");
      subtitle.getStyleClass().add("sidebar-subtitle");

      Button dashboard = createSidebarButton("Dashboard", () -> {
         if (currentTeacher == null) {
            showWelcomeView();
         } else {
            showTeacherDashboard();
         }
      });
      Button students = createSidebarButton("Students", () -> {
         if (currentTeacher == null) {
            showWelcomeView();
         } else {
            showStudentsView();
         }
      });
      Button calendar = createSidebarButton("Calendar", this::showTeacherCalendar);
      Button payments = createSidebarButton("Payments", this::showPaymentsDashboard);
      Button settings = createSidebarButton("Settings", this::showSettingsView);

      Region spacer = new Region();
      VBox.setVgrow(spacer, Priority.ALWAYS);

      Button exit = createSidebarButton("Exit", Platform::exit);

      sidebar.getChildren().addAll(logo, subtitle, dashboard, students, calendar, payments, settings, spacer, exit);
      return sidebar;
   }

   private void applyApplicationIcon(Stage stage) {
      if (stage == null) {
         return;
      }
      List<Image> icons = loadApplicationWindowIcons();
      if (!icons.isEmpty()) {
         stage.getIcons().clear();
         stage.getIcons().addAll(icons);
      }
   }

   private ImageView createApplicationLogoView(double size) {
      ImageView imageView = new ImageView();
      imageView.setFitWidth(size);
      imageView.setFitHeight(size);
      imageView.setPreserveRatio(true);
      imageView.setSmooth(true);
      loadApplicationIcon().ifPresent(imageView::setImage);
      return imageView;
   }

   private Optional<Image> loadApplicationIcon() {
      URL iconUrl = getClass().getResource(APPLICATION_ICON_PATH);
      if (iconUrl == null) {
         return Optional.empty();
      }
      return Optional.of(new Image(iconUrl.toExternalForm()));
   }

   private List<Image> loadApplicationWindowIcons() {
      List<Image> icons = new ArrayList<>();
      for (String iconPath : WINDOW_ICON_PATHS) {
         try (InputStream iconStream = getClass().getResourceAsStream(iconPath)) {
            if (iconStream == null) {
               continue;
            }
            Image icon = new Image(iconStream);
            if (!icon.isError()) {
               icons.add(icon);
            }
         } catch (Exception exception) {
            return icons;
         }
      }
      return icons;
   }

   private Button createSidebarButton(String text, Runnable action) {
      Button button = new Button(text);
      button.getStyleClass().add("sidebar-item");
      button.setMaxWidth(Double.MAX_VALUE);
      button.setOnAction(event -> {
         setActiveNavigation(button);
         action.run();
      });
      navigationButtons.add(button);
      return button;
   }

   private void setActiveNavigation(Button activeButton) {
      for (Button button : navigationButtons) {
         button.getStyleClass().remove("sidebar-item-active");
      }
      if (activeButton != null && !activeButton.getStyleClass().contains("sidebar-item-active")) {
         activeButton.getStyleClass().add("sidebar-item-active");
      }
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

   private VBox card() {
      VBox card = new VBox(12);
      card.getStyleClass().add("card");
      card.setMaxWidth(Double.MAX_VALUE);
      return card;
   }

   private Label pageTitle(String text) {
      Label label = new Label(text);
      label.getStyleClass().add("page-title");
      return label;
   }

   private Label mutedText(String text) {
      Label label = new Label(text);
      label.getStyleClass().add("muted-text");
      return label;
   }

   private void showSettingsView() {
      if (currentTeacher == null) {
         showError("Please sign in or create a teacher account first.");
         showWelcomeView();
         return;
      }

      Label title = pageTitle("Settings");
      HBox tabs = new HBox(8);
      Button teacherProfileTab = secondaryButton("Teacher Profile");
      Button applicationTab = secondaryButton("Application");
      Button preferencesTab = secondaryButton("Preferences");
      tabs.getChildren().addAll(teacherProfileTab, applicationTab, preferencesTab);

      VBox settingsContent = new VBox(16);
      settingsContent.setFillWidth(true);

      teacherProfileTab.setOnAction(event -> settingsContent.getChildren().setAll(createTeacherProfileSection(false)));
      applicationTab.setOnAction(event -> settingsContent.getChildren().setAll(createApplicationSettingsSection()));
      preferencesTab.setOnAction(event -> settingsContent.getChildren().setAll(createApplicationSettingsSection()));
      settingsContent.getChildren().setAll(createTeacherProfileSection(false));

      ScrollPane scrollPane = new ScrollPane(settingsContent);
      scrollPane.setFitToWidth(true);
      scrollPane.getStyleClass().add("scroll-pane");
      VBox.setVgrow(scrollPane, Priority.ALWAYS);

      mainContent.getChildren().setAll(title, tabs, scrollPane);
   }

   private VBox createApplicationSettingsSection() {
      VBox courseNameCard = card();

      Label cardTitle = new Label("Course Name");
      cardTitle.getStyleClass().add("card-title");
      Label help = mutedText("Choose how lessons are named across Courses and Course History.");

      ToggleGroup titleModeGroup = new ToggleGroup();
      VBox options = new VBox(8);
      for (CourseTitleMode titleMode : CourseTitleMode.values()) {
         RadioButton option = new RadioButton(titleMode.toString());
         option.setToggleGroup(titleModeGroup);
         option.setSelected(titleMode == courseTitleMode.get());
         option.setOnAction(event -> courseTitleMode.set(titleMode));
         options.getChildren().add(option);
      }

      courseNameCard.getChildren().addAll(cardTitle, help, options);
      return courseNameCard;
   }

   private VBox createTeacherProfileSection(boolean editMode) {
      VBox section = new VBox(16);
      section.setFillWidth(true);

      HBox header = new HBox(16);
      header.getStyleClass().add("card");
      header.setAlignment(javafx.geometry.Pos.CENTER_LEFT);

      Label avatar = new Label(teacherInitials(currentTeacher));
      avatar.setMinSize(64, 64);
      avatar.setMaxSize(64, 64);
      avatar.getStyleClass().add("avatar");

      VBox titleBlock = new VBox(4);
      Label profileTitle = new Label("Teacher Profile");
      profileTitle.getStyleClass().add("page-title");
      Label subtitle = mutedText("Manage your personal and teaching information.");
      Label teacherName = new Label(currentTeacher == null ? "" : currentTeacher.getName());
      teacherName.getStyleClass().add("card-title");
      Label teacherRole = mutedText((currentTeacher == null || currentTeacher.getMainInstrument().isBlank())
            ? "Music Teacher"
            : currentTeacher.getMainInstrument() + " Teacher");
      titleBlock.getChildren().addAll(profileTitle, subtitle, teacherName, teacherRole);

      Region spacer = new Region();
      HBox.setHgrow(spacer, Priority.ALWAYS);

      Button editButton = secondaryButton("Edit Profile");
      editButton.setVisible(!editMode);
      editButton.setManaged(!editMode);
      editButton.setOnAction(event -> refreshSettingsTeacherProfile(section, true));

      Button changePhotoButton = secondaryButton("Change Photo");
      changePhotoButton.setOnAction(event -> changeTeacherPhoto(section));

      header.getChildren().addAll(avatar, titleBlock, spacer, changePhotoButton, editButton);

      VBox personalCard = card();
      Label personalTitle = new Label("Personal Information");
      personalTitle.getStyleClass().add("card-title");

      VBox teachingCard = card();
      Label teachingTitle = new Label("Teaching Information");
      teachingTitle.getStyleClass().add("card-title");

      if (editMode) {
         buildEditableTeacherProfile(section, personalCard, personalTitle, teachingCard, teachingTitle);
      } else {
         personalCard.getChildren().addAll(
               personalTitle,
               profileLine("First name", currentTeacher.getFirstName()),
               profileLine("Last name", currentTeacher.getLastName()),
               profileLine("Studio name", currentTeacher.getStudioName()),
               profileLine("Email", currentTeacher.getEmail()),
               profileLine("Phone", currentTeacher.getTelephone()),
               profileLine("Address", currentTeacher.getAddress()),
               profileLine("City", currentTeacher.getCity()),
               profileLine("Postal code", currentTeacher.getPostalCode()));

         teachingCard.getChildren().addAll(
               teachingTitle,
               profileLine("Main instrument", currentTeacher.getMainInstrument()),
               profileLine("Other instruments", currentTeacher.getOtherInstruments()),
               profileLine("Default lesson duration", currentTeacher.getDefaultLessonDuration() + " minutes"),
               profileLine("Default lesson price", formatMoney(currentTeacher.getDefaultLessonPrice())),
               profileLine("Currency", currentTeacher.getCurrency()));
      }

      section.getChildren().setAll(header, personalCard, teachingCard);
      return section;
   }

   private void buildEditableTeacherProfile(
         VBox section,
         VBox personalCard,
         Label personalTitle,
         VBox teachingCard,
         Label teachingTitle) {
      TextField firstNameField = new TextField(currentTeacher.getFirstName());
      TextField lastNameField = new TextField(currentTeacher.getLastName());
      TextField studioNameField = new TextField(currentTeacher.getStudioName());
      TextField emailField = new TextField(currentTeacher.getEmail());
      TextField phoneField = new TextField(currentTeacher.getTelephone());
      TextField addressField = new TextField(currentTeacher.getAddress());
      TextField cityField = new TextField(currentTeacher.getCity());
      TextField postalCodeField = new TextField(currentTeacher.getPostalCode());
      TextField mainInstrumentField = new TextField(currentTeacher.getMainInstrument());
      TextField otherInstrumentsField = new TextField(currentTeacher.getOtherInstruments());
      TextField durationField = new TextField(String.valueOf(currentTeacher.getDefaultLessonDuration()));
      TextField priceField = new TextField(String.valueOf(currentTeacher.getDefaultLessonPrice()));
      TextField currencyField = new TextField(currentTeacher.getCurrency());

      Label firstNameError = validationLabel();
      Label lastNameError = validationLabel();
      Label emailError = validationLabel();
      Label durationError = validationLabel();
      Label priceError = validationLabel();

      personalCard.getChildren().addAll(
            personalTitle,
            editableProfileLine("First name", firstNameField, firstNameError),
            editableProfileLine("Last name", lastNameField, lastNameError),
            editableProfileLine("Studio name", studioNameField, null),
            editableProfileLine("Email", emailField, emailError),
            editableProfileLine("Phone", phoneField, null),
            editableProfileLine("Address", addressField, null),
            editableProfileLine("City", cityField, null),
            editableProfileLine("Postal code", postalCodeField, null));

      teachingCard.getChildren().addAll(
            teachingTitle,
            editableProfileLine("Main instrument", mainInstrumentField, null),
            editableProfileLine("Other instruments", otherInstrumentsField, null),
            editableProfileLine("Default lesson duration", durationField, durationError),
            editableProfileLine("Default lesson price", priceField, priceError),
            editableProfileLine("Currency", currencyField, null));

      Button cancelButton = secondaryButton("Cancel");
      cancelButton.setOnAction(event -> refreshSettingsTeacherProfile(section, false));
      Button saveButton = primaryButton("Save Changes");
      saveButton.setOnAction(event -> {
         clearValidation(firstNameError, lastNameError, emailError, durationError, priceError);
         if (!validateTeacherProfile(
               firstNameField,
               lastNameField,
               emailField,
               durationField,
               priceField,
               firstNameError,
               lastNameError,
               emailError,
               durationError,
               priceError)) {
            return;
         }

         currentTeacher.setFirstName(firstNameField.getText());
         currentTeacher.setLastName(lastNameField.getText());
         currentTeacher.setStudioName(studioNameField.getText());
         currentTeacher.setEmail(emailField.getText());
         currentTeacher.setTelephone(phoneField.getText());
         currentTeacher.setAddress(addressField.getText());
         currentTeacher.setCity(cityField.getText());
         currentTeacher.setPostalCode(postalCodeField.getText());
         currentTeacher.setMainInstrument(mainInstrumentField.getText());
         currentTeacher.setOtherInstruments(otherInstrumentsField.getText());
         currentTeacher.setDefaultLessonDuration(Integer.parseInt(durationField.getText().trim()));
         currentTeacher.setDefaultLessonPrice(Double.parseDouble(priceField.getText().trim()));
         currentTeacher.setCurrency(currencyField.getText());
         teacherService.updateTeacher(currentTeacher);
         refreshSettingsTeacherProfile(section, false);
      });

      HBox actions = new HBox(8, cancelButton, saveButton);
      actions.setAlignment(javafx.geometry.Pos.CENTER_RIGHT);
      teachingCard.getChildren().add(actions);
   }

   private void refreshSettingsTeacherProfile(VBox section, boolean editMode) {
      VBox refreshed = createTeacherProfileSection(editMode);
      section.getChildren().setAll(refreshed.getChildren());
   }

   private HBox profileLine(String labelText, String valueText) {
      Label label = new Label(labelText);
      label.getStyleClass().add("field-label");
      label.setMinWidth(170);
      Label value = new Label(valueText == null || valueText.isBlank() ? "Not set" : valueText);
      value.getStyleClass().add("field-value");
      value.setWrapText(true);
      HBox row = new HBox(12, label, value);
      row.setAlignment(javafx.geometry.Pos.CENTER_LEFT);
      return row;
   }

   private VBox editableProfileLine(String labelText, TextField field, Label errorLabel) {
      Label label = new Label(labelText);
      label.getStyleClass().add("field-label");
      label.setMinWidth(170);
      field.setMaxWidth(Double.MAX_VALUE);
      HBox row = new HBox(12, label, field);
      row.setAlignment(javafx.geometry.Pos.CENTER_LEFT);
      HBox.setHgrow(field, Priority.ALWAYS);
      VBox wrapper = new VBox(4, row);
      if (errorLabel != null) {
         wrapper.getChildren().add(errorLabel);
      }
      return wrapper;
   }

   private Label validationLabel() {
      Label label = new Label();
      label.getStyleClass().add("validation-error");
      label.setManaged(false);
      label.setVisible(false);
      return label;
   }

   private void setValidation(Label label, String message) {
      label.setText(message);
      label.setManaged(true);
      label.setVisible(true);
   }

   private void clearValidation(Label... labels) {
      for (Label label : labels) {
         label.setText("");
         label.setManaged(false);
         label.setVisible(false);
      }
   }

   private boolean validateTeacherProfile(
         TextField firstNameField,
         TextField lastNameField,
         TextField emailField,
         TextField durationField,
         TextField priceField,
         Label firstNameError,
         Label lastNameError,
         Label emailError,
         Label durationError,
         Label priceError) {
      boolean valid = true;
      if (firstNameField.getText() == null || firstNameField.getText().trim().isEmpty()) {
         setValidation(firstNameError, "First name is required.");
         valid = false;
      }
      if (lastNameField.getText() == null || lastNameField.getText().trim().isEmpty()) {
         setValidation(lastNameError, "Last name is required.");
         valid = false;
      }
      String email = emailField.getText() == null ? "" : emailField.getText().trim();
      if (!email.isEmpty() && !email.matches("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")) {
         setValidation(emailError, "Enter a valid email address.");
         valid = false;
      }
      try {
         if (Integer.parseInt(durationField.getText().trim()) <= 0) {
            setValidation(durationError, "Duration must be positive.");
            valid = false;
         }
      } catch (NumberFormatException exception) {
         setValidation(durationError, "Duration must be a number.");
         valid = false;
      }
      try {
         if (Double.parseDouble(priceField.getText().trim()) < 0) {
            setValidation(priceError, "Price cannot be negative.");
            valid = false;
         }
      } catch (NumberFormatException exception) {
         setValidation(priceError, "Price must be a number.");
         valid = false;
      }
      return valid;
   }

   private String teacherInitials(Teacher teacher) {
      if (teacher == null) {
         return "";
      }
      String first = teacher.getFirstName() == null || teacher.getFirstName().isBlank()
            ? teacher.getName()
            : teacher.getFirstName();
      String last = teacher.getLastName() == null ? "" : teacher.getLastName();
      String firstInitial = first == null || first.isBlank() ? "" : first.trim().substring(0, 1).toUpperCase(Locale.ROOT);
      String lastInitial = last.isBlank() ? "" : last.trim().substring(0, 1).toUpperCase(Locale.ROOT);
      return firstInitial + lastInitial;
   }

   private void changeTeacherPhoto(VBox section) {
      TextInputDialog dialog = new TextInputDialog(currentTeacher.getProfileImagePath());
      dialog.setTitle("Change Photo");
      dialog.setHeaderText(null);
      dialog.setContentText("Profile image path:");
      dialog.showAndWait().ifPresent(path -> {
         currentTeacher.setProfileImagePath(path);
         teacherService.updateTeacher(currentTeacher);
         refreshSettingsTeacherProfile(section, false);
      });
   }

   private void showWelcomeView() {
      setActiveNavigation(null);
      Label title = pageTitle("Welcome to Maestro");

      Label prompt = mutedText("Sign in or create a teacher account to manage students, lessons, projects, and payments.");

      Button signInButton = primaryButton("Sign In");
      signInButton.setOnAction(event -> signInTeacher());

      Button createAccountButton = secondaryButton("Create Teacher Account");
      createAccountButton.setOnAction(event -> createTeacherAccount());

      HBox actions = new HBox(10, signInButton, createAccountButton);
      VBox welcomeCard = card();
      welcomeCard.getChildren().addAll(title, prompt, actions);
      mainContent.getChildren().setAll(welcomeCard);
   }

   private void createTeacherAccount() {
      TeacherAccountDialog dialog = new TeacherAccountDialog(nextTeacherId);
      Optional<Teacher> teacher = dialog.showAndWait();

      teacher.ifPresent(createdTeacher -> {
         teacherService.addTeacher(createdTeacher);
         nextTeacherId++;
         currentTeacher = createdTeacher;
         showInfo("Teacher account created. Your teacher ID is: " + createdTeacher.getId());
         showTeacherDashboard();
      });
   }

   private void updateNextTeacherId() {
      int highestTeacherId = 0;
      for (Teacher teacher : teacherService.getAllTeachers()) {
         if (teacher.getId() > highestTeacherId) {
            highestTeacherId = teacher.getId();
         }
      }

      nextTeacherId = highestTeacherId + 1;
   }

   private void updateNextStudentId() {
      int highestStudentId = 0;
      for (Student student : studentService.getAllStudents()) {
         if (student.getId() > highestStudentId) {
            highestStudentId = student.getId();
         }
      }

      nextStudentId = highestStudentId + 1;
   }

   private void signInTeacher() {
      TextInputDialog dialog = new TextInputDialog();
      dialog.setTitle("Teacher Sign In");
      dialog.setHeaderText(null);
      dialog.setContentText("Teacher ID:");

      Optional<String> teacherId = dialog.showAndWait();
      teacherId.ifPresent(this::signInTeacherById);
   }

   private void signInTeacherById(String teacherIdText) {
      try {
         int teacherId = Integer.parseInt(teacherIdText.trim());
         Teacher teacher = teacherService.findTeacherById(teacherId);

         if (teacher == null) {
            showError("Teacher not found.");
            return;
         }

         currentTeacher = teacher;
         showTeacherDashboard();
      } catch (NumberFormatException exception) {
         showError("Teacher ID must be a number.");
      }
   }

   private void showTeacherDashboard() {
      Label title = pageTitle("Dashboard");

      Label signedInTeacher = mutedText("Signed in as " + currentTeacher.getName() + " · Teacher ID " + currentTeacher.getId());

      Button addStudentButton = primaryButton("+ Add Student");
      addStudentButton.setOnAction(event -> addStudentForCurrentTeacher());

      Button calendarButton = secondaryButton("Calendar");
      calendarButton.setOnAction(event -> showTeacherCalendar());

      Region headerSpacer = new Region();
      HBox.setHgrow(headerSpacer, Priority.ALWAYS);
      HBox actions = new HBox(10, signedInTeacher, headerSpacer, addStudentButton, calendarButton);
      actions.setAlignment(javafx.geometry.Pos.CENTER_LEFT);

      VBox dashboardContent = new VBox(16);
      dashboardContent.setFillWidth(true);
      dashboardContent.getChildren().addAll(
            createDashboardSummaryCards(),
            createDashboardSections());

      ScrollPane scrollPane = new ScrollPane(dashboardContent);
      scrollPane.setFitToWidth(true);
      scrollPane.getStyleClass().add("scroll-pane");
      VBox.setVgrow(scrollPane, Priority.ALWAYS);

      mainContent.getChildren().setAll(title, actions, scrollPane);
   }

   private void showStudentsView() {
      if (currentTeacher == null) {
         showError("Please sign in or create a teacher account first.");
         showWelcomeView();
         return;
      }

      Label title = pageTitle("Students");
      Label subtitle = mutedText("Manage and search students for " + currentTeacher.getName() + ".");

      TextField searchField = new TextField();
      searchField.setPromptText("Search by name, instrument, email, or phone...");
      searchField.setMaxWidth(Double.MAX_VALUE);

      Button addStudentButton = primaryButton("+ Add Student");
      addStudentButton.setOnAction(event -> addStudentForCurrentTeacher());

      Region spacer = new Region();
      HBox.setHgrow(searchField, Priority.ALWAYS);
      HBox filters = new HBox(10, searchField, spacer, addStudentButton);
      filters.setAlignment(javafx.geometry.Pos.CENTER_LEFT);

      ScrollPane scrollPane = new ScrollPane(createStudentListView(""));
      searchField.textProperty().addListener((observable, oldValue, newValue) ->
            scrollPane.setContent(createStudentListView(newValue)));
      scrollPane.setFitToWidth(true);
      scrollPane.getStyleClass().add("scroll-pane");
      VBox.setVgrow(scrollPane, Priority.ALWAYS);

      mainContent.getChildren().setAll(title, subtitle, filters, scrollPane);
   }

   private VBox createStudentListView(String searchText) {
      VBox students = card();
      Label studentsTitle = new Label("Students");
      studentsTitle.getStyleClass().add("card-title");
      students.getChildren().add(studentsTitle);

      List<Student> allStudents = visibleStudents();
      boolean hasVisibleStudent = false;

      for (Student student : allStudents) {
         if (studentMatchesSearch(student, searchText) || studentDetailMatchesSearch(student, searchText)) {
            hasVisibleStudent = true;
            Button studentButton = secondaryButton(student.getName());
            studentButton.setOnAction(event -> showStudentProfile(student));

            Label classTime = mutedText("Class: " + formatClassTime(student));
            Label paymentLeft = mutedText("Payment left: " + formatMoney(getPaymentLeft(student)));
            Label instrument = mutedText("Instrument: " + formatInstrument(student));

            HBox studentRow = new HBox(10, studentButton, instrument, classTime, paymentLeft);
            studentRow.setAlignment(javafx.geometry.Pos.CENTER_LEFT);
            students.getChildren().add(studentRow);
         }
      }

      if (!hasVisibleStudent) {
         students.getChildren().add(new Label(searchText == null || searchText.isBlank()
               ? "No students yet."
               : "No students match your search."));
      }

      return students;
   }

   private TilePane createDashboardSummaryCards() {
      YearMonth currentMonth = YearMonth.now();
      List<Student> students = visibleStudents();
      List<Payment> monthPayments = paymentsForMonth(currentMonth);
      List<LessonItem> monthLessons = lessonsForMonth(currentMonth);

      TilePane summaryCards = new TilePane();
      summaryCards.setHgap(12);
      summaryCards.setVgap(12);
      summaryCards.setPrefColumns(3);
      summaryCards.setTileAlignment(javafx.geometry.Pos.TOP_LEFT);
      summaryCards.getChildren().addAll(
            dashboardSummaryCard("Total Students", String.valueOf(students.size()), "Active studio roster"),
            dashboardSummaryCard("Revenue / Payments This Month", formatMoney(sumPayments(monthPayments)), monthPayments.size() + " payments"),
            dashboardSummaryCard("Lessons This Month", String.valueOf(monthLessons.size()), currentMonth.getMonth().getDisplayName(TextStyle.FULL, Locale.US)));
      return summaryCards;
   }

   private FlowPane createDashboardSections() {
      FlowPane sections = new FlowPane(16, 16);
      sections.setPrefWrapLength(820);
      sections.getChildren().addAll(
            createTodaysLessonsCard(),
            createUpcomingReviewsCard(),
            createPaymentAttentionCard());
      return sections;
   }

   private VBox dashboardSummaryCard(String title, String value, String detail) {
      VBox summaryCard = card();
      summaryCard.setPrefWidth(220);
      summaryCard.setMinWidth(200);
      Label titleLabel = mutedText(title.toUpperCase(Locale.ROOT));
      Label valueLabel = pageTitle(value);
      Label detailLabel = mutedText(detail);
      summaryCard.getChildren().addAll(titleLabel, valueLabel, detailLabel);
      return summaryCard;
   }

   private VBox createTodaysLessonsCard() {
      VBox lessonsCard = dashboardSectionCard("Today's Lessons");
      List<LessonItem> lessons = lessonsForDate(LocalDate.now());
      if (lessons.isEmpty()) {
         lessonsCard.getChildren().add(mutedText("No lessons scheduled for today."));
         return lessonsCard;
      }

      for (LessonItem lesson : lessons) {
         HBox row = dashboardRow();
         VBox detail = new VBox(3);
         Label student = new Label(lesson.student().getName());
         student.getStyleClass().add("field-value");
         Label metadata = mutedText(formatLessonTime(lesson.course()) + " · " + formatInstrument(lesson.student()));
         detail.getChildren().addAll(student, metadata);
         HBox.setHgrow(detail, Priority.ALWAYS);

         Button openLessonButton = secondaryButton("Open Lesson");
         openLessonButton.setOnAction(event ->
               showStudentProfile(lesson.student(), lesson.project().getId(), lesson.course().getId()));
         row.getChildren().addAll(detail, openLessonButton);
         lessonsCard.getChildren().add(row);
      }
      return lessonsCard;
   }

   private VBox createUpcomingReviewsCard() {
      VBox reviewsCard = dashboardSectionCard("Upcoming Notes to Review");
      List<ReviewItem> reviews = upcomingReviews();
      if (reviews.isEmpty()) {
         reviewsCard.getChildren().add(mutedText("No notes are due for review."));
         return reviewsCard;
      }

      for (ReviewItem review : reviews) {
         HBox row = dashboardRow();
         VBox detail = new VBox(3);
         Label student = new Label(review.student().getName());
         student.getStyleClass().add("field-value");
         Label piece = mutedText("Piece: " + blankFallback(review.note().getPiece(), "Not set"));
         Label note = mutedText("Note: " + blankFallback(review.note().getComment(), "No note"));
         Label due = mutedText(formatReviewDueLabel(review.note().getReviewDate()));
         detail.getChildren().addAll(student, piece, note, due);
         HBox.setHgrow(detail, Priority.ALWAYS);
         row.getChildren().add(detail);
         reviewsCard.getChildren().add(row);
      }
      return reviewsCard;
   }

   private VBox createPaymentAttentionCard() {
      VBox paymentsCard = dashboardSectionCard("Payment Attention");
      List<Student> attentionStudents = new ArrayList<>();
      for (Student student : visibleStudents()) {
         if (getPaymentLeft(student) <= 0) {
            attentionStudents.add(student);
         }
      }
      attentionStudents.sort(Comparator.comparingDouble(this::getPaymentLeft));

      if (attentionStudents.isEmpty()) {
         paymentsCard.getChildren().add(mutedText("No student balances need attention."));
         return paymentsCard;
      }

      for (Student student : attentionStudents) {
         HBox row = dashboardRow();
         VBox detail = new VBox(3);
         Label name = new Label(student.getName());
         name.getStyleClass().add("field-value");
         Label balance = mutedText("Balance: " + formatMoney(getPaymentLeft(student)));
         detail.getChildren().addAll(name, balance);
         HBox.setHgrow(detail, Priority.ALWAYS);

         Button openPaymentsButton = secondaryButton("Open Payments");
         openPaymentsButton.setOnAction(event -> showStudentProfile(student, StudentProfileView.ProfileSection.PAYMENTS));
         row.getChildren().addAll(detail, openPaymentsButton);
         paymentsCard.getChildren().add(row);
      }

      return paymentsCard;
   }

   private VBox dashboardSectionCard(String title) {
      VBox section = card();
      section.setPrefWidth(360);
      section.setMinWidth(300);
      Label cardTitle = new Label(title);
      cardTitle.getStyleClass().add("card-title");
      section.getChildren().add(cardTitle);
      return section;
   }

   private HBox dashboardRow() {
      HBox row = new HBox(10);
      row.getStyleClass().add("compact-card");
      row.setAlignment(javafx.geometry.Pos.CENTER_LEFT);
      row.setMaxWidth(Double.MAX_VALUE);
      return row;
   }

   private String formatClassTime(Student student) {
      String day = student.getCourseDay() == null ? "Not set" : student.getCourseDay().toString();
      String hour = student.getCourseHour() == null ? "Not set" : student.getCourseHour().toString();
      return day + " " + hour;
   }

   private double getPaymentLeft(Student student) {
      double totalPaid = paymentService.getTotalPaidByStudent(student);
      for (StudentCourse course : student.getCourses()) {
         if (course.getStatus() == LessonStatus.PRESENT || course.getStatus() == LessonStatus.ABSENT) {
            totalPaid -= course.getPrice();
         }
      }

      return totalPaid;
   }

   private List<Payment> paymentsForMonth(YearMonth month) {
      List<Payment> payments = new ArrayList<>();
      for (Payment payment : visiblePayments()) {
         LocalDate paymentDate = payment.getPaymentDate();
         if (paymentDate != null && YearMonth.from(paymentDate).equals(month)) {
            payments.add(payment);
         }
      }
      return payments;
   }

   private List<LessonItem> lessonsForMonth(YearMonth month) {
      List<LessonItem> lessons = new ArrayList<>();
      for (Student student : visibleStudents()) {
         for (StudentProject project : student.getProjects()) {
            for (StudentCourse course : project.getCourses()) {
               LocalDate courseDate = course.getDate();
               if (courseDate != null && YearMonth.from(courseDate).equals(month)) {
                  lessons.add(new LessonItem(student, project, course));
               }
            }
         }
      }
      lessons.sort(this::compareLessons);
      return lessons;
   }

   private List<LessonItem> lessonsForDate(LocalDate date) {
      List<LessonItem> lessons = new ArrayList<>();
      for (Student student : visibleStudents()) {
         for (StudentProject project : student.getProjects()) {
            for (StudentCourse course : project.getCourses()) {
               if (date.equals(course.getDate())) {
                  lessons.add(new LessonItem(student, project, course));
               }
            }
         }
      }
      lessons.sort(this::compareLessons);
      return lessons;
   }

   private int compareLessons(LessonItem first, LessonItem second) {
      LocalDate firstDate = first.course().getDate();
      LocalDate secondDate = second.course().getDate();
      int dateCompare = compareNullableDates(firstDate, secondDate);
      if (dateCompare != 0) {
         return dateCompare;
      }
      LocalTime firstTime = first.course().getHour();
      LocalTime secondTime = second.course().getHour();
      if (firstTime == null && secondTime != null) {
         return 1;
      }
      if (firstTime != null && secondTime == null) {
         return -1;
      }
      if (firstTime != null) {
         int timeCompare = firstTime.compareTo(secondTime);
         if (timeCompare != 0) {
            return timeCompare;
         }
      }
      return first.student().getName().compareToIgnoreCase(second.student().getName());
   }

   private int compareNullableDates(LocalDate firstDate, LocalDate secondDate) {
      if (firstDate == null && secondDate == null) {
         return 0;
      }
      if (firstDate == null) {
         return 1;
      }
      if (secondDate == null) {
         return -1;
      }
      return firstDate.compareTo(secondDate);
   }

   private List<ReviewItem> upcomingReviews() {
      LocalDate today = LocalDate.now();
      List<ReviewItem> reviews = new ArrayList<>();
      for (Student student : visibleStudents()) {
         for (StudentProject project : student.getProjects()) {
            for (StudentCourse course : project.getCourses()) {
               for (CourseNote note : course.getNotes()) {
                  LocalDate reviewDate = note.getReviewDate();
                  ReviewStatus reviewStatus = note.getReviewStatus();
                  if (reviewDate != null
                        && !reviewDate.isAfter(today.plusDays(7))
                        && reviewStatus == ReviewStatus.PENDING) {
                     reviews.add(new ReviewItem(student, project, course, note));
                  }
               }
            }
         }
      }
      reviews.sort((first, second) -> {
         int dateCompare = compareNullableDates(first.note().getReviewDate(), second.note().getReviewDate());
         if (dateCompare != 0) {
            return dateCompare;
         }
         return first.student().getName().compareToIgnoreCase(second.student().getName());
      });
      return reviews;
   }

   private String formatLessonTime(StudentCourse course) {
      return course.getHour() == null
            ? "No time"
            : course.getHour().format(DateTimeFormatter.ofPattern("h:mm a"));
   }

   private String formatInstrument(Student student) {
      return student.getInstrument() == null ? "Not set" : student.getInstrument().toString();
   }

   private String formatReviewDueLabel(LocalDate reviewDate) {
      if (reviewDate == null) {
         return "No review date";
      }
      LocalDate today = LocalDate.now();
      if (reviewDate.equals(today)) {
         return "Due today";
      }
      if (reviewDate.isBefore(today)) {
         return "Overdue since " + reviewDate;
      }
      return "Review date: " + reviewDate;
   }

   private String blankFallback(String value, String fallback) {
      return value == null || value.isBlank() ? fallback : value;
   }

   private boolean studentDetailMatchesSearch(Student student, String searchText) {
      String query = searchText == null ? "" : searchText.trim().toLowerCase(Locale.ROOT);
      if (query.isEmpty()) {
         return true;
      }
      String instrument = student.getInstrument() == null ? "" : student.getInstrument().toString();
      String email = student.getEmail() == null ? "" : student.getEmail();
      String phone = student.getPhone() == null ? "" : student.getPhone();
      return instrument.toLowerCase(Locale.ROOT).contains(query)
            || email.toLowerCase(Locale.ROOT).contains(query)
            || phone.toLowerCase(Locale.ROOT).contains(query);
   }

   private void addStudentForCurrentTeacher() {
      if (currentTeacher == null) {
         showError("Please sign in or create a teacher account first.");
         showWelcomeView();
         return;
      }

      AddStudentDialog dialog = new AddStudentDialog(currentTeacher);
      Optional<Student> student = dialog.showAndWait();

      student.ifPresent(createdStudent -> {
         createdStudent.setId(nextStudentId);
         nextStudentId++;
         studentService.addStudent(createdStudent);
         showStudentProfile(createdStudent);
      });
   }

   private void showCurrentTeacherProfile() {
      if (currentTeacher == null) {
         showError("Please sign in or create a teacher account first.");
         showWelcomeView();
         return;
      }

      Pane profileView = new TeacherProfileView(currentTeacher);
      profileView.getStyleClass().add("card");
      Button backButton = secondaryButton("Back to Dashboard");
      backButton.setOnAction(event -> showTeacherDashboard());

      mainContent.getChildren().setAll(pageTitle("Teacher Profile"), profileView, backButton);
   }

   private void showTeacherCalendar() {
      if (currentTeacher == null) {
         showError("Please sign in or create a teacher account first.");
         showWelcomeView();
         return;
      }

      Pane calendarView = new MaestroCalendarView(
            currentTeacher,
            studentService.getAllStudents(),
            paymentService,
            selection -> showStudentProfile(selection.student(), selection.projectId(), selection.courseId()),
            studentService::saveStudents);
      VBox.setVgrow(calendarView, Priority.ALWAYS);
      calendarView.getStyleClass().add("card");

      mainContent.getChildren().setAll(pageTitle("Calendar"), calendarView);
   }

   private void showPaymentsDashboard() {
      if (currentTeacher == null) {
         showError("Please sign in or create a teacher account first.");
         showWelcomeView();
         return;
      }

      Label title = pageTitle("Payments");
      ComboBox<MonthOption> monthBox = new ComboBox<>();
      monthBox.getItems().add(MonthOption.allMonths());
      for (Month month : Month.values()) {
         monthBox.getItems().add(MonthOption.of(month));
      }
      monthBox.setValue(MonthOption.of(LocalDate.now().getMonth()));

      ComboBox<Integer> yearBox = new ComboBox<>();
      yearBox.getItems().addAll(paymentYears());
      yearBox.setValue(yearBox.getItems().contains(LocalDate.now().getYear())
            ? LocalDate.now().getYear()
            : yearBox.getItems().get(0));

      ComboBox<StudentOption> studentBox = new ComboBox<>();
      studentBox.getItems().add(StudentOption.allStudents());
      for (Student student : visibleStudents()) {
         studentBox.getItems().add(StudentOption.of(student));
      }
      studentBox.setValue(StudentOption.allStudents());

      Button addPaymentButton = primaryButton("+ Add Payment");
      addPaymentButton.setOnAction(event -> addGlobalPayment());

      Region filterSpacer = new Region();
      HBox.setHgrow(filterSpacer, Priority.ALWAYS);
      HBox filters = new HBox(10, monthBox, yearBox, studentBox, filterSpacer, addPaymentButton);
      filters.setAlignment(javafx.geometry.Pos.CENTER_LEFT);

      HBox summaryCards = new HBox(12);
      summaryCards.setFillHeight(true);

      Label historyTitle = new Label("Payment History");
      historyTitle.getStyleClass().add("card-title");
      TextField searchField = new TextField();
      searchField.setPromptText("Search student...");
      ComboBox<String> typeBox = new ComboBox<>();
      typeBox.getItems().addAll("All transactions", "Payment", "Refund");
      typeBox.setValue("All transactions");

      Region historyFilterSpacer = new Region();
      HBox.setHgrow(historyFilterSpacer, Priority.ALWAYS);
      HBox historyFilters = new HBox(10, searchField, historyFilterSpacer, typeBox);
      historyFilters.setAlignment(javafx.geometry.Pos.CENTER_LEFT);

      TableView<PaymentRow> tableView = createPaymentTable();
      VBox.setVgrow(tableView, Priority.ALWAYS);

      VBox historyCard = card();
      historyCard.getChildren().addAll(historyTitle, historyFilters, tableView);
      VBox.setVgrow(historyCard, Priority.ALWAYS);

      Runnable refresh = () -> refreshPaymentsDashboard(
            monthBox.getValue(),
            yearBox.getValue(),
            studentBox.getValue(),
            typeBox.getValue(),
            searchField.getText(),
            summaryCards,
            tableView);

      monthBox.valueProperty().addListener((observable, oldValue, newValue) -> refresh.run());
      yearBox.valueProperty().addListener((observable, oldValue, newValue) -> refresh.run());
      studentBox.valueProperty().addListener((observable, oldValue, newValue) -> refresh.run());
      typeBox.valueProperty().addListener((observable, oldValue, newValue) -> refresh.run());
      searchField.textProperty().addListener((observable, oldValue, newValue) -> refresh.run());
      refresh.run();

      mainContent.getChildren().setAll(title, filters, summaryCards, historyCard);
      VBox.setVgrow(historyCard, Priority.ALWAYS);
   }

   private List<Integer> paymentYears() {
      List<Integer> years = new ArrayList<>();
      for (Payment payment : visiblePayments()) {
         if (payment.getPaymentDate() != null && !years.contains(payment.getPaymentDate().getYear())) {
            years.add(payment.getPaymentDate().getYear());
         }
      }
      if (!years.contains(LocalDate.now().getYear())) {
         years.add(LocalDate.now().getYear());
      }
      years.sort(Comparator.reverseOrder());
      return years;
   }

   private List<Student> visibleStudents() {
      List<Student> students = new ArrayList<>();
      for (Student student : studentService.getAllStudents()) {
         if (student.getTeacherId() == null || student.getTeacherId().equals(currentTeacher.getId())) {
            students.add(student);
         }
      }
      students.sort(Comparator.comparing(Student::getName, String.CASE_INSENSITIVE_ORDER));
      return students;
   }

   private List<Payment> visiblePayments() {
      List<Payment> payments = new ArrayList<>();
      for (Payment payment : paymentService.getAllPayments()) {
         Student student = payment.getStudent();
         if (student != null && (student.getTeacherId() == null || student.getTeacherId().equals(currentTeacher.getId()))) {
            payments.add(payment);
         }
      }
      return payments;
   }

   private TableView<PaymentRow> createPaymentTable() {
      TableView<PaymentRow> tableView = new TableView<>();
      tableView.setColumnResizePolicy(TableView.CONSTRAINED_RESIZE_POLICY);

      TableColumn<PaymentRow, String> dateColumn = new TableColumn<>("Date");
      dateColumn.setCellValueFactory(row -> new ReadOnlyStringWrapper(row.getValue().date()));

      TableColumn<PaymentRow, String> studentColumn = new TableColumn<>("Student");
      studentColumn.setCellValueFactory(row -> new ReadOnlyStringWrapper(row.getValue().studentName()));

      TableColumn<PaymentRow, String> amountColumn = new TableColumn<>("Amount");
      amountColumn.setCellValueFactory(row -> new ReadOnlyStringWrapper(row.getValue().amount()));

      TableColumn<PaymentRow, String> typeColumn = new TableColumn<>("Type");
      typeColumn.setCellValueFactory(row -> new ReadOnlyStringWrapper(row.getValue().type()));

      TableColumn<PaymentRow, String> methodColumn = new TableColumn<>("Payment Method");
      methodColumn.setCellValueFactory(row -> new ReadOnlyStringWrapper(row.getValue().method()));

      TableColumn<PaymentRow, String> notesColumn = new TableColumn<>("Notes");
      notesColumn.setCellValueFactory(row -> new ReadOnlyStringWrapper(row.getValue().notes()));

      tableView.getColumns().addAll(dateColumn, studentColumn, amountColumn, typeColumn, methodColumn, notesColumn);
      tableView.setRowFactory(view -> {
         TableRow<PaymentRow> row = new TableRow<>();
         row.itemProperty().addListener((observable, oldValue, newValue) -> {
            row.getStyleClass().removeAll("payment-row", "refund-row");
            if (newValue != null) {
               row.getStyleClass().add(newValue.payment().getAmount() < 0 ? "refund-row" : "payment-row");
            }
         });
         row.setOnMouseClicked(event -> {
            if (event.getClickCount() == 2 && !row.isEmpty()) {
               showStudentProfile(row.getItem().student(), StudentProfileView.ProfileSection.PAYMENTS);
            }
         });
         return row;
      });
      return tableView;
   }

   private void refreshPaymentsDashboard(
         MonthOption month,
         Integer year,
         StudentOption studentOption,
         String typeFilter,
         String searchText,
         HBox summaryCards,
         TableView<PaymentRow> tableView) {
      List<Payment> basePayments = visiblePayments();
      List<Payment> filteredPayments = filterPayments(basePayments, month, year, studentOption, typeFilter, searchText);
      ObservableList<PaymentRow> rows = FXCollections.observableArrayList();
      filteredPayments.sort((first, second) -> comparePaymentDates(second, first));
      for (Payment payment : filteredPayments) {
         rows.add(PaymentRow.from(payment));
      }
      tableView.setItems(rows);

      List<Payment> monthPayments = filterPayments(basePayments, month, year, studentOption, "All transactions", searchText);
      List<Payment> yearPayments = filterPayments(basePayments, MonthOption.allMonths(), year, studentOption, "All transactions", searchText);
      double totalCredit = 0;
      for (Student student : visibleStudents()) {
         if ((studentOption == null || studentOption.isAll() || studentOption.student() == student)
               && studentMatchesSearch(student, searchText)) {
            totalCredit += student.getPaymentCreditBalance();
         }
      }

      summaryCards.getChildren().setAll(
            paymentDashboardCard(month == null || month.isAll() ? "SELECTED PERIOD" : "THIS MONTH",
                  sumPayments(monthPayments),
                  monthPayments.size() + " payments"),
            paymentDashboardCard("THIS YEAR", sumPayments(yearPayments), yearPayments.size() + " payments"),
            paymentDashboardCard("TOTAL STUDENT CREDIT", totalCredit, "Students"));
   }

   private List<Payment> filterPayments(
         List<Payment> payments,
         MonthOption month,
         Integer year,
         StudentOption studentOption,
         String typeFilter,
         String searchText) {
      List<Payment> filtered = new ArrayList<>();
      for (Payment payment : payments) {
         Student student = payment.getStudent();
         LocalDate date = payment.getPaymentDate();
         if (student == null || date == null) {
            continue;
         }
         if (year != null && date.getYear() != year) {
            continue;
         }
         if (month != null && !month.isAll() && date.getMonth() != month.month()) {
            continue;
         }
         if (studentOption != null && !studentOption.isAll() && studentOption.student() != student) {
            continue;
         }
         if (!studentMatchesSearch(student, searchText)) {
            continue;
         }
         if ("Payment".equals(typeFilter) && payment.getAmount() < 0) {
            continue;
         }
         if ("Refund".equals(typeFilter) && payment.getAmount() >= 0) {
            continue;
         }
         filtered.add(payment);
      }
      return filtered;
   }

   private boolean studentMatchesSearch(Student student, String searchText) {
      String query = searchText == null ? "" : searchText.trim().toLowerCase(Locale.ROOT);
      if (query.isEmpty()) {
         return true;
      }
      String firstName = student.getFirstName() == null ? "" : student.getFirstName();
      String familyName = student.getFamilyName() == null ? "" : student.getFamilyName();
      String fullName = student.getName() == null ? "" : student.getName();
      return firstName.toLowerCase(Locale.ROOT).contains(query)
            || familyName.toLowerCase(Locale.ROOT).contains(query)
            || fullName.toLowerCase(Locale.ROOT).contains(query);
   }

   private int comparePaymentDates(Payment first, Payment second) {
      LocalDate firstDate = first.getPaymentDate();
      LocalDate secondDate = second.getPaymentDate();
      if (firstDate == null && secondDate == null) {
         return Integer.compare(first.getId(), second.getId());
      }
      if (firstDate == null) {
         return -1;
      }
      if (secondDate == null) {
         return 1;
      }
      int dateCompare = firstDate.compareTo(secondDate);
      return dateCompare != 0 ? dateCompare : Integer.compare(first.getId(), second.getId());
   }

   private double sumPayments(List<Payment> payments) {
      double total = 0;
      for (Payment payment : payments) {
         total += payment.getAmount();
      }
      return total;
   }

   private VBox paymentDashboardCard(String title, double amount, String detail) {
      VBox card = card();
      card.setMinWidth(180);
      HBox.setHgrow(card, Priority.ALWAYS);
      Label titleLabel = mutedText(title);
      Label amountLabel = pageTitle(formatMoney(amount));
      Label detailLabel = mutedText(detail);
      card.getChildren().addAll(titleLabel, amountLabel, detailLabel);
      return card;
   }

   private void addGlobalPayment() {
      Dialog<Payment> dialog = new Dialog<>();
      dialog.setTitle("Add Payment");
      dialog.setHeaderText(null);

      ComboBox<StudentOption> studentBox = new ComboBox<>();
      for (Student student : visibleStudents()) {
         studentBox.getItems().add(StudentOption.of(student));
      }
      if (!studentBox.getItems().isEmpty()) {
         studentBox.setValue(studentBox.getItems().get(0));
      }

      TextField amountField = new TextField();
      amountField.setPromptText("Amount");

      DatePicker paymentDatePicker = new DatePicker(LocalDate.now());

      TextField methodField = new TextField();
      methodField.setPromptText("Cash, card, transfer...");

      TextArea noteArea = new TextArea();
      noteArea.setPrefRowCount(3);
      noteArea.setWrapText(true);

      GridPane grid = paymentDialogGrid(amountField, paymentDatePicker, methodField, noteArea);
      grid.add(new Label("Student:"), 0, 0);
      grid.add(studentBox, 1, 0);

      dialog.getDialogPane().setContent(grid);
      dialog.getDialogPane().getButtonTypes().addAll(ButtonType.CANCEL, ButtonType.OK);

      dialog.setResultConverter(button -> {
         if (button != ButtonType.OK) {
            return null;
         }
         if (studentBox.getValue() == null || studentBox.getValue().student() == null) {
            showError("Please select a student.");
            return null;
         }
         try {
            Student selectedStudent = studentBox.getValue().student();
            return new Payment(
                  selectedStudent,
                  Double.parseDouble(amountField.getText().trim()),
                  paymentDatePicker.getValue(),
                  methodField.getText(),
                  noteArea.getText());
         } catch (NumberFormatException exception) {
            showError("Payment amount must be a number.");
            return null;
         }
      });

      Optional<Payment> payment = dialog.showAndWait();
      payment.ifPresent(createdPayment -> {
         paymentService.addPayment(createdPayment, createdPayment.getStudent().getCurrentProject());
         showPaymentsDashboard();
      });
   }

   private void showStudentProfile(Student student) {
      showStudentProfile(student, 0, 0);
   }

   private void showStudentProfile(Student student, StudentProfileView.ProfileSection initialSection) {
      List<Payment> payments = paymentService.getPaymentsByStudent(student);
      Pane profileView = new StudentProfileView(
            student,
            payments,
            project -> addPaymentForStudent(student, project),
            studentService::saveStudents,
            reviewService,
            0,
            0,
            courseTitleMode,
            initialSection);
      VBox.setVgrow(profileView, Priority.ALWAYS);
      Button backButton = secondaryButton("Back to Dashboard");
      backButton.setOnAction(event -> showTeacherDashboard());

      mainContent.getChildren().setAll(profileView, backButton);
   }

   private void showStudentProfile(Student student, int selectedProjectId, int selectedCourseId) {
      List<Payment> payments = paymentService.getPaymentsByStudent(student);
      Pane profileView = new StudentProfileView(
            student,
            payments,
            project -> addPaymentForStudent(student, project),
            studentService::saveStudents,
            reviewService,
            selectedProjectId,
            selectedCourseId,
            courseTitleMode);
      VBox.setVgrow(profileView, Priority.ALWAYS);
      Button backButton = secondaryButton("Back to Dashboard");
      backButton.setOnAction(event -> showTeacherDashboard());

      mainContent.getChildren().setAll(profileView, backButton);
   }

   private GridPane paymentDialogGrid(
         TextField amountField,
         DatePicker paymentDatePicker,
         TextField methodField,
         TextArea noteArea) {
      GridPane grid = new GridPane();
      grid.setHgap(10);
      grid.setVgap(10);
      grid.setPadding(new Insets(20));

      grid.add(new Label("Amount:"), 0, 1);
      grid.add(amountField, 1, 1);
      grid.add(new Label("Date:"), 0, 2);
      grid.add(paymentDatePicker, 1, 2);
      grid.add(new Label("Method:"), 0, 3);
      grid.add(methodField, 1, 3);
      grid.add(new Label("Note:"), 0, 4);
      grid.add(noteArea, 1, 4);
      return grid;
   }

   private void addPaymentForStudent(Student student, StudentProject project) {
      Dialog<Payment> dialog = new Dialog<>();
      dialog.setTitle("Add Payment");
      dialog.setHeaderText(null);

      TextField amountField = new TextField();
      amountField.setPromptText("Amount");

      DatePicker paymentDatePicker = new DatePicker(LocalDate.now());

      TextField methodField = new TextField();
      methodField.setPromptText("Cash, card, transfer...");

      TextArea noteArea = new TextArea();
      noteArea.setPrefRowCount(3);
      noteArea.setWrapText(true);

      GridPane grid = new GridPane();
      grid.setHgap(10);
      grid.setVgap(10);
      grid.setPadding(new Insets(20));

      grid.add(new Label("Amount:"), 0, 0);
      grid.add(amountField, 1, 0);
      grid.add(new Label("Date:"), 0, 1);
      grid.add(paymentDatePicker, 1, 1);
      grid.add(new Label("Method:"), 0, 2);
      grid.add(methodField, 1, 2);
      grid.add(new Label("Note:"), 0, 3);
      grid.add(noteArea, 1, 3);

      dialog.getDialogPane().setContent(grid);
      dialog.getDialogPane().getButtonTypes().addAll(ButtonType.CANCEL, ButtonType.OK);

      dialog.setResultConverter(button -> {
         if (button != ButtonType.OK) {
            return null;
         }

         try {
            double amount = Double.parseDouble(amountField.getText().trim());
            return new Payment(
                  student,
                  amount,
                  paymentDatePicker.getValue(),
                  methodField.getText(),
                  noteArea.getText());
         } catch (NumberFormatException exception) {
            showError("Payment amount must be a number.");
            return null;
         }
      });

      Optional<Payment> payment = dialog.showAndWait();
      payment.ifPresent(createdPayment -> {
         paymentService.addPayment(createdPayment, project);
         showStudentProfile(student);
      });
   }

   private void showError(String message) {
      Alert alert = new Alert(Alert.AlertType.ERROR);
      alert.setTitle("Maestro");
      alert.setHeaderText(null);
      alert.setContentText(message);
      alert.showAndWait();
   }

   private void showInfo(String message) {
      Alert alert = new Alert(Alert.AlertType.INFORMATION);
      alert.setTitle("Maestro");
      alert.setHeaderText(null);
      alert.setContentText(message);
      alert.showAndWait();
   }

   private String formatMoney(double amount) {
      return amount < 0 ? "-$" + String.format("%.2f", Math.abs(amount)) : "$" + String.format("%.2f", amount);
   }

   private static class MonthOption {
      private final Month month;
      private final String label;

      private MonthOption(Month month, String label) {
         this.month = month;
         this.label = label;
      }

      private static MonthOption allMonths() {
         return new MonthOption(null, "All Months");
      }

      private static MonthOption of(Month month) {
         return new MonthOption(month, month.getDisplayName(TextStyle.FULL, Locale.US));
      }

      private boolean isAll() {
         return month == null;
      }

      private Month month() {
         return month;
      }

      @Override
      public String toString() {
         return label;
      }
   }

   private static class StudentOption {
      private final Student student;
      private final String label;

      private StudentOption(Student student, String label) {
         this.student = student;
         this.label = label;
      }

      private static StudentOption allStudents() {
         return new StudentOption(null, "All Students");
      }

      private static StudentOption of(Student student) {
         return new StudentOption(student, student.getName());
      }

      private boolean isAll() {
         return student == null;
      }

      private Student student() {
         return student;
      }

      @Override
      public String toString() {
         return label;
      }
   }

   private static class PaymentRow {
      private final Payment payment;

      private PaymentRow(Payment payment) {
         this.payment = payment;
      }

      private static PaymentRow from(Payment payment) {
         return new PaymentRow(payment);
      }

      private Payment payment() {
         return payment;
      }

      private Student student() {
         return payment.getStudent();
      }

      private String date() {
         return payment.getPaymentDate() == null ? "No date" : payment.getPaymentDate().toString();
      }

      private String studentName() {
         return payment.getStudent() == null ? "Unknown student" : payment.getStudent().getName();
      }

      private String amount() {
         double amount = payment.getAmount();
         return amount < 0 ? "-$" + String.format("%.2f", Math.abs(amount)) : "$" + String.format("%.2f", amount);
      }

      private String type() {
         return payment.getAmount() < 0 ? "Refund" : "Payment";
      }

      private String method() {
         return payment.getMethod() == null || payment.getMethod().isBlank() ? "" : payment.getMethod();
      }

      private String notes() {
         return payment.getNote() == null ? "" : payment.getNote();
      }
   }

   private record LessonItem(Student student, StudentProject project, StudentCourse course) {
   }

   private record ReviewItem(Student student, StudentProject project, StudentCourse course, CourseNote note) {
   }

   public static void main(String[] args) {
        launch(args);
   }
}
