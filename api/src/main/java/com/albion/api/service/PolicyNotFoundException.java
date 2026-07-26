package com.albion.api.service;

public class PolicyNotFoundException extends RuntimeException {
  public PolicyNotFoundException(String id) {
    super(id);
  }
}
