package pe.gerenzdent;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

/**
 * Reglas de arquitectura (docs/planificacion/04-arquitectura.md, RNF-09). Cada módulo funcional
 * tiene las capas api / application / domain / infrastructure.
 */
@AnalyzeClasses(packages = "pe.gerenzdent", importOptions = ImportOption.DoNotIncludeTests.class)
class ArquitecturaTest {

  @ArchTest
  static final ArchRule dominioNoDependeDeInfraestructuraNiApi =
      noClasses()
          .that()
          .resideInAPackage("..domain..")
          .should()
          .dependOnClassesThat()
          .resideInAnyPackage("..infrastructure..", "..api..")
          .allowEmptyShould(true);

  @ArchTest
  static final ArchRule dominioNoDependeDeSpringWeb =
      noClasses()
          .that()
          .resideInAPackage("..domain..")
          .should()
          .dependOnClassesThat()
          .resideInAnyPackage("org.springframework.web..", "org.springframework.http..")
          .allowEmptyShould(true);

  @ArchTest
  static final ArchRule applicationNoDependeDeApi =
      noClasses()
          .that()
          .resideInAPackage("..application..")
          .should()
          .dependOnClassesThat()
          .resideInAPackage("..api..")
          .allowEmptyShould(true);
}
