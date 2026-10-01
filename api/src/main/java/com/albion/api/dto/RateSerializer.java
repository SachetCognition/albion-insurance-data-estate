package com.albion.api.dto;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.JsonSerializer;
import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
public class RateSerializer extends JsonSerializer<BigDecimal> {
  @Override
  public void serialize(
      BigDecimal value,
      JsonGenerator gen,
      com.fasterxml.jackson.databind.SerializerProvider provider)
      throws IOException {
    if (value == null) {
      gen.writeNull();
      return;
    }
    gen.writeString(value.setScale(4, RoundingMode.HALF_UP).toPlainString());
  }
}
