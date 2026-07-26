package com.albion.api.repository.jdbc;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

final class MartPaths {
  private MartPaths() {}

  static Path resolve(String configured) {
    List<Path> candidates = new ArrayList<>();
    candidates.add(Paths.get(configured));
    Path current = Paths.get(System.getProperty("user.dir")).toAbsolutePath().normalize();
    for (Path cursor = current; cursor != null; cursor = cursor.getParent()) {
      candidates.add(cursor.resolve(configured));
    }
    return candidates.stream()
        .map(Path::toAbsolutePath)
        .map(Path::normalize)
        .filter(Files::isRegularFile)
        .findFirst()
        .orElseThrow(
            () ->
                new IllegalStateException(
                    "Canonical mart database not found: "
                        + configured
                        + ". Build it first with 'python3 migration/load_local.py' then"
                        + " 'dbt build --profiles-dir .' in dbt/. (looked in "
                        + candidates
                        + ")"));
  }
}
