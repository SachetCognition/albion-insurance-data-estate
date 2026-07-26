package com.albion.api.repository.fixture;
import com.albion.api.mapping.LegacyValueMapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

abstract class FixtureRepositorySupport {
  protected final ObjectMapper mapper;
  protected final LegacyValueMapper legacy = new LegacyValueMapper();
  private final Path directory;

  protected FixtureRepositorySupport(ObjectMapper mapper, String configuredPath) {
    this.mapper = mapper;
    this.directory = locate(configuredPath);
  }

  private Path locate(String configured) {
    List<Path> candidates = new ArrayList<>();
    candidates.add(Paths.get(configured));
    Path current = Paths.get(System.getProperty("user.dir")).toAbsolutePath().normalize();
    for (Path cursor = current; cursor != null; cursor = cursor.getParent()) {
      candidates.add(cursor.resolve(configured));
    }
    candidates.add(current.resolve("api").resolve(configured));
    candidates.add(current.resolve("repos/albion-insurance-data-estate").resolve(configured));
    return candidates.stream()
        .map(Path::toAbsolutePath)
        .map(Path::normalize)
        .filter(Files::isDirectory)
        .findFirst()
        .orElseThrow(
            () ->
                new IllegalStateException(
                    "Fixture directory not found: " + configured + " (looked in " + candidates + ")"));
  }

  protected JsonNode read(String name) {
    try {
      return mapper.readTree(directory.resolve(name).toFile());
    } catch (IOException e) {
      throw new IllegalStateException("Unable to read fixture " + directory.resolve(name), e);
    }
  }

  protected void normalize(JsonNode node) {
    ObjectNode object = (ObjectNode) node;
    if (node.has("lossDate") && node.get("lossDate").isTextual()) {
      object.put("lossDate", legacy.date(node.get("lossDate").asText()).toString());
    }
    if (node.has("notifiedDate") && node.get("notifiedDate").isTextual()) {
      object.put("notifiedDate", legacy.date(node.get("notifiedDate").asText()).toString());
    }
    if (node.has("fraudFlag") && node.get("fraudFlag").isTextual()) {
      object.put("fraudFlag", legacy.fraudFlag(node.get("fraudFlag").asText()).name());
    }
  }

  protected <T> List<T> readList(String name, Class<T> type) {
    List<T> result = new ArrayList<>();
    for (JsonNode node : read(name)) {
      normalize(node);
      result.add(mapper.convertValue(node, type));
    }
    return result;
  }
}
