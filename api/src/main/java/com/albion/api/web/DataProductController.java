package com.albion.api.web;
import com.albion.api.dto.DataProductSummaryDto;
import com.albion.api.service.DataProductService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/data-products")
public class DataProductController {
  private final DataProductService service;

  public DataProductController(DataProductService service) {
    this.service = service;
  }

  @GetMapping("/summary")
  public DataProductSummaryDto summary() {
    return service.summary();
  }
}
