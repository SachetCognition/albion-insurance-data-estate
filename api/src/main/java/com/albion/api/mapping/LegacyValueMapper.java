package com.albion.api.mapping;
import com.albion.api.dto.FraudFlag;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;

public class LegacyValueMapper {
  public LocalDate date(String value) {
    try {
      return LocalDate.parse(value);
    } catch (DateTimeParseException e) {
      return LocalDate.parse(value, DateTimeFormatter.ofPattern("dd/MM/yyyy"));
    }
  }

  public FraudFlag fraudFlag(String value) {
    if (value == null) {
      throw new IllegalArgumentException("Fraud flag must not be null");
    }
    return switch (value.trim().toUpperCase()) {
      case "Y" -> FraudFlag.Y;
      case "N" -> FraudFlag.N;
      case "S", "SUSPECTED" -> FraudFlag.SUSPECTED;
      default -> throw new IllegalArgumentException("Unknown fraud flag: " + value);
    };
  }
}
