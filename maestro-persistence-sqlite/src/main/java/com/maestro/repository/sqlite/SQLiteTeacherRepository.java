package com.maestro.repository.sqlite;

import com.maestro.database.DatabaseProvider;
import com.maestro.model.Status;
import com.maestro.model.Teacher;
import com.maestro.repository.TeacherRepository;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public class SQLiteTeacherRepository extends SQLiteRepositorySupport implements TeacherRepository {
   public SQLiteTeacherRepository(DatabaseProvider databaseProvider) {
      super(databaseProvider);
   }

   @Override
   public Teacher save(Teacher teacher) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement(
               "INSERT INTO teachers ("
                     + "id, name, telephone, email, address, status, first_name, last_name, studio_name, city, postal_code, "
                     + "main_instrument, other_instruments, default_lesson_duration, default_lesson_price, currency, profile_image_path"
                     + ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
                     + "ON CONFLICT(id) DO UPDATE SET "
                     + "name = excluded.name, "
                     + "telephone = excluded.telephone, "
                     + "email = excluded.email, "
                     + "address = excluded.address, "
                     + "status = excluded.status, "
                     + "first_name = excluded.first_name, "
                     + "last_name = excluded.last_name, "
                     + "studio_name = excluded.studio_name, "
                     + "city = excluded.city, "
                     + "postal_code = excluded.postal_code, "
                     + "main_instrument = excluded.main_instrument, "
                     + "other_instruments = excluded.other_instruments, "
                     + "default_lesson_duration = excluded.default_lesson_duration, "
                     + "default_lesson_price = excluded.default_lesson_price, "
                     + "currency = excluded.currency, "
                     + "profile_image_path = excluded.profile_image_path")) {
            statement.setInt(1, teacher.getId());
            statement.setString(2, teacher.getName());
            statement.setString(3, teacher.getTelephone());
            statement.setString(4, teacher.getEmail());
            statement.setString(5, teacher.getAddress());
            statement.setString(6, teacher.getStatus().name());
            statement.setString(7, teacher.getFirstName());
            statement.setString(8, teacher.getLastName());
            statement.setString(9, teacher.getStudioName());
            statement.setString(10, teacher.getCity());
            statement.setString(11, teacher.getPostalCode());
            statement.setString(12, teacher.getMainInstrument());
            statement.setString(13, teacher.getOtherInstruments());
            statement.setInt(14, teacher.getDefaultLessonDuration());
            statement.setDouble(15, teacher.getDefaultLessonPrice());
            statement.setString(16, teacher.getCurrency());
            statement.setString(17, teacher.getProfileImagePath());
            statement.executeUpdate();
         }
         return teacher;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not save teacher", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public Optional<Teacher> findById(int id) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement("SELECT * FROM teachers WHERE id = ?")) {
            statement.setInt(1, id);
            try (ResultSet resultSet = statement.executeQuery()) {
               return resultSet.next() ? Optional.of(mapTeacher(resultSet)) : Optional.empty();
            }
         }
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not find teacher", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public List<Teacher> findAll() {
      Connection connection = null;
      try {
         connection = getConnection();
         List<Teacher> teachers = new ArrayList<>();
         try (PreparedStatement statement = connection.prepareStatement("SELECT * FROM teachers ORDER BY id");
              ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
               teachers.add(mapTeacher(resultSet));
            }
         }
         return teachers;
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not load teachers", exception);
      } finally {
         close(connection);
      }
   }

   @Override
   public void update(Teacher teacher) {
      save(teacher);
   }

   @Override
   public void deleteById(int id) {
      Connection connection = null;
      try {
         connection = getConnection();
         try (PreparedStatement statement = connection.prepareStatement("DELETE FROM teachers WHERE id = ?")) {
            statement.setInt(1, id);
            statement.executeUpdate();
         }
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not delete teacher", exception);
      } finally {
         close(connection);
      }
   }

   private Teacher mapTeacher(ResultSet resultSet) throws SQLException {
      Teacher teacher = new Teacher(
            resultSet.getInt("id"),
            resultSet.getString("name"),
            resultSet.getString("telephone"),
            resultSet.getString("email"),
            resultSet.getString("address"));
      teacher.setStatus(Status.valueOf(resultSet.getString("status")));
      teacher.setFirstName(resultSet.getString("first_name"));
      teacher.setLastName(resultSet.getString("last_name"));
      teacher.setStudioName(resultSet.getString("studio_name"));
      teacher.setCity(resultSet.getString("city"));
      teacher.setPostalCode(resultSet.getString("postal_code"));
      teacher.setMainInstrument(resultSet.getString("main_instrument"));
      teacher.setOtherInstruments(resultSet.getString("other_instruments"));
      teacher.setDefaultLessonDuration(resultSet.getInt("default_lesson_duration"));
      teacher.setDefaultLessonPrice(resultSet.getDouble("default_lesson_price"));
      teacher.setCurrency(resultSet.getString("currency"));
      teacher.setProfileImagePath(resultSet.getString("profile_image_path"));
      return teacher;
   }

   private void close(Connection connection) {
      try {
         releaseConnection(connection);
      } catch (SQLException exception) {
         throw new IllegalStateException("Could not close teacher repository connection", exception);
      }
   }
}
