package com.albion.api.web;

public class InvalidPaginationException extends RuntimeException {
  public InvalidPaginationException(String detail) {
    super(detail);
  }
}
