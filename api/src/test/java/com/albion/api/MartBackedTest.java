package com.albion.api;

import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

abstract class MartBackedTest {
  @DynamicPropertySource
  static void marts(DynamicPropertyRegistry registry) {
    registry.add("albion.marts.database", () -> MartTestDatabase.path().toString());
  }
}
