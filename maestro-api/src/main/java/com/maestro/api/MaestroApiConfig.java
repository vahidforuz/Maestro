package com.maestro.api;

import com.maestro.database.DatabaseInitializer;
import com.maestro.database.LegacyDataMigrator;
import com.maestro.database.SQLiteDatabaseProvider;
import com.maestro.repository.PaymentRepository;
import com.maestro.repository.RepositoryFactory;
import com.maestro.repository.StudentRepository;
import com.maestro.repository.TeacherRepository;
import com.maestro.repository.sqlite.SQLiteRepositoryFactory;
import com.maestro.service.PaymentService;
import com.maestro.service.PaymentServiceImpl;
import com.maestro.service.ReviewService;
import com.maestro.service.ReviewServiceImpl;
import com.maestro.service.StudentService;
import com.maestro.service.StudentServiceImpl;
import com.maestro.service.TeacherService;
import com.maestro.service.TeacherServiceImpl;
import java.nio.file.Path;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class MaestroApiConfig {
   @Bean
   public WebMvcConfigurer corsConfigurer(
         @Value("${maestro.cors.allowed-origin-patterns:http://localhost:*,http://127.0.0.1:*}") String allowedOriginPatterns) {
      return new WebMvcConfigurer() {
         @Override
         public void addCorsMappings(CorsRegistry registry) {
            registry.addMapping("/api/**")
                  .allowedOriginPatterns(allowedOriginPatterns.split(","))
                  .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                  .allowedHeaders("*");
         }
      };
   }

   @Bean
   public SQLiteDatabaseProvider databaseProvider(
         @Value("${maestro.database.path:data/music_school.db}") String databasePath) {
      return new SQLiteDatabaseProvider(Path.of(databasePath));
   }

   @Bean
   public RepositoryFactory repositoryFactory(SQLiteDatabaseProvider databaseProvider) {
      new DatabaseInitializer(databaseProvider).initialize();
      RepositoryFactory repositoryFactory = new SQLiteRepositoryFactory(databaseProvider);
      new LegacyDataMigrator(
            databaseProvider,
            repositoryFactory.transactionManager(),
            repositoryFactory.teachers(),
            repositoryFactory.students(),
            repositoryFactory.payments()).migrateIfNeeded();
      return repositoryFactory;
   }

   @Bean
   public StudentRepository studentRepository(RepositoryFactory repositoryFactory) {
      return repositoryFactory.students();
   }

   @Bean
   public TeacherRepository teacherRepository(RepositoryFactory repositoryFactory) {
      return repositoryFactory.teachers();
   }

   @Bean
   public PaymentRepository paymentRepository(RepositoryFactory repositoryFactory) {
      return repositoryFactory.payments();
   }

   @Bean
   public StudentService studentService(StudentRepository studentRepository) {
      return new StudentServiceImpl(studentRepository);
   }

   @Bean
   public TeacherService teacherService(TeacherRepository teacherRepository) {
      return new TeacherServiceImpl(teacherRepository);
   }

   @Bean
   public PaymentService paymentService(
         PaymentRepository paymentRepository,
         StudentRepository studentRepository,
         RepositoryFactory repositoryFactory) {
      return new PaymentServiceImpl(paymentRepository, studentRepository, repositoryFactory.transactionManager());
   }

   @Bean
   public ReviewService reviewService(StudentRepository studentRepository) {
      return new ReviewServiceImpl(studentRepository);
   }
}
