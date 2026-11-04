package pe.gerenzdent.paciente.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;
import pe.gerenzdent.shared.domain.Textos;

class PacienteTest {

  private static final UUID USUARIO = UUID.randomUUID();

  private static DatosPaciente datos(String nombre, Integer edad, String alergias) {
    return new DatosPaciente(nombre, "987654321", edad, alergias, null, true);
  }

  @Test
  void limpiaElNombreYGuardaLaVersionDeBusqueda() {
    Paciente p = new Paciente(USUARIO, datos("  José   Ñañez  Pérez ", null, null));

    assertThat(p.getNombre()).isEqualTo("José Ñañez Pérez");
    assertThat(Textos.paraBusqueda(p.getNombre())).isEqualTo("jose nanez perez");
    assertThat(p.getWhatsapp()).isEqualTo("+51987654321");
  }

  @Test
  void camposOpcionalesVaciosSeGuardanComoNulos() {
    Paciente p = new Paciente(USUARIO, datos("Ana", null, "   "));

    assertThat(p.getAlergias()).isNull();
    assertThat(p.tieneAlergias()).isFalse();
  }

  @Test
  void rechazaNombreMuyCorto() {
    assertThatThrownBy(() -> new Paciente(USUARIO, datos(" A ", null, null)))
        .isInstanceOf(DatoInvalido.class)
        .extracting("campo")
        .isEqualTo("nombre");
  }

  @Test
  void rechazaEdadFueraDeRango() {
    assertThatThrownBy(() -> new Paciente(USUARIO, datos("Ana", 121, null)))
        .isInstanceOf(DatoInvalido.class)
        .extracting("campo")
        .isEqualTo("edad");
  }

  @Test
  void archivarYDesarchivar() {
    Paciente p = new Paciente(USUARIO, datos("Ana", 8, "Penicilina"));
    p.archivar();
    assertThat(p.isArchivado()).isTrue();
    p.desarchivar();
    assertThat(p.isArchivado()).isFalse();
    assertThat(p.tieneAlergias()).isTrue();
  }
}
