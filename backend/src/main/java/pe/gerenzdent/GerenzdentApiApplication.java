package pe.gerenzdent;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class GerenzdentApiApplication {

  public static void main(String[] args) {
    SpringApplication.run(GerenzdentApiApplication.class, args);
  }
}
