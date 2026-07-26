package com.albion.api.repository.jdbc;

import java.util.Properties;
import javax.sql.DataSource;
import org.duckdb.DuckDBDriver;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.datasource.SimpleDriverDataSource;

@Configuration
public class MartDataSourceConfig {

  @Bean
  public DataSource martDataSource(
      @Value("${albion.marts.database:dbt/target/albion.duckdb}") String database) {
    Properties properties = new Properties();
    properties.setProperty(DuckDBDriver.DUCKDB_READONLY_PROPERTY, "true");
    return new SimpleDriverDataSource(
        new DuckDBDriver(), "jdbc:duckdb:" + MartPaths.resolve(database), properties);
  }
}
