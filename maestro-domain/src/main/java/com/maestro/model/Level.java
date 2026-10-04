package com.maestro.model;

public enum Level {
   BEGINNER,
   INTERMEDIATE,
   ADVANCED;

   @Override
   public String toString() {
      String lowerName = name().toLowerCase();
      return lowerName.substring(0, 1).toUpperCase() + lowerName.substring(1);
   }
}
