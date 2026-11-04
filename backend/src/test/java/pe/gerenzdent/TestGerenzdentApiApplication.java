package pe.gerenzdent;

import org.springframework.boot.SpringApplication;

public class TestGerenzdentApiApplication {

  public static void main(String[] args) {
    SpringApplication.from(GerenzdentApiApplication::main)
        .with(TestcontainersConfiguration.class)
        .run(args);
  }
}
