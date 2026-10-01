package com.albion.api.service;
import com.albion.api.dto.DataProductSummaryDto;
import com.albion.api.repository.DataProductSummaryRepository;
import org.springframework.stereotype.Service;

@Service
public class DataProductService {
  private final DataProductSummaryRepository repository;

  public DataProductService(DataProductSummaryRepository repository) {
    this.repository = repository;
  }

  public DataProductSummaryDto summary() {
    return repository.find();
  }
}
