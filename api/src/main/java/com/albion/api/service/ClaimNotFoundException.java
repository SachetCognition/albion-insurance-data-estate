package com.albion.api.service;

public class ClaimNotFoundException extends RuntimeException {
  public ClaimNotFoundException(String id) {
    super(id);
  }
}
