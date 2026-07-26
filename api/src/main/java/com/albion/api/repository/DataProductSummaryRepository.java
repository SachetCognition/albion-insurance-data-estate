package com.albion.api.repository;
import com.albion.api.dto.DataProductSummaryDto;
public interface DataProductSummaryRepository {
  DataProductSummaryDto find();

  default DataProductSummaryDto get() {
    return find();
  }
}
