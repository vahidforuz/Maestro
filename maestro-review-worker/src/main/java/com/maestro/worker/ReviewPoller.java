package com.maestro.worker;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class ReviewPoller {
   private static final Logger LOGGER = LoggerFactory.getLogger(ReviewPoller.class);

   private final HttpClient httpClient = HttpClient.newHttpClient();
   private final String apiBaseUrl;

   public ReviewPoller(@Value("${maestro.api.base-url:http://localhost:8080}") String apiBaseUrl) {
      this.apiBaseUrl = apiBaseUrl;
   }

   @Scheduled(fixedDelayString = "${maestro.review-worker.delay-ms:3600000}")
   public void pollApi() {
      HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(apiBaseUrl + "/api/students"))
            .GET()
            .build();

      try {
         HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
         if (response.statusCode() >= 200 && response.statusCode() < 300) {
            LOGGER.info("Review worker reached API and loaded students for review scan.");
         } else {
            LOGGER.warn("Review worker API poll failed with status {}", response.statusCode());
         }
      } catch (IOException exception) {
         LOGGER.warn("Review worker could not reach Maestro API at {}", apiBaseUrl);
      } catch (InterruptedException exception) {
         Thread.currentThread().interrupt();
         LOGGER.warn("Review worker API poll interrupted");
      }
   }
}
