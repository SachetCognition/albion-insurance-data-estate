package com.albion.api.web;
import jakarta.servlet.http.HttpServletRequest;
import com.albion.api.service.ClaimNotFoundException;
import com.albion.api.service.PolicyNotFoundException;
import java.net.URI;
import java.util.Map;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

@RestControllerAdvice
public class ApiExceptionHandler {
  @ExceptionHandler(PolicyNotFoundException.class)
  public ResponseEntity<Map<String, Object>> policy(
      PolicyNotFoundException exception, HttpServletRequest request) {
    return problem(
        "https://albion.example/problems/policy-not-found",
        "Policy not found",
        404,
        "No policy exists with id '" + exception.getMessage() + "'",
        request);
  }

  @ExceptionHandler(ClaimNotFoundException.class)
  public ResponseEntity<Map<String, Object>> claim(
      ClaimNotFoundException exception, HttpServletRequest request) {
    return problem(
        "https://albion.example/problems/claim-not-found",
        "Claim not found",
        404,
        "No claim exists with id '" + exception.getMessage() + "'",
        request);
  }

  @ExceptionHandler(MethodArgumentTypeMismatchException.class)
  public ResponseEntity<Map<String, Object>> bad(
      MethodArgumentTypeMismatchException exception, HttpServletRequest request) {
    return problem(
        "https://albion.example/problems/invalid-request",
        "Invalid request",
        400,
        "Invalid value for parameter '" + exception.getName() + "'",
        request);
  }

  private ResponseEntity<Map<String, Object>> problem(
      String type, String title, int status, String detail, HttpServletRequest request) {
    return ResponseEntity.status(status)
        .contentType(MediaType.valueOf("application/problem+json"))
        .body(
            Map.of(
                "type", URI.create(type).toString(),
                "title", title,
                "status", status,
                "detail", detail,
                "instance", request.getRequestURI()));
  }
}
