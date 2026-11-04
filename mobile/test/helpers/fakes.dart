import 'package:gerenz_dent/features/auth/data/almacen_sesion.dart';
import 'package:gerenz_dent/features/auth/data/auth_repository.dart';
import 'package:gerenz_dent/features/auth/domain/sesion.dart';
import 'package:gerenz_dent/features/pacientes/data/pacientes_repository.dart';
import 'package:gerenz_dent/features/pacientes/domain/paciente.dart';
import 'package:mocktail/mocktail.dart';

/// Almacén de sesión en memoria (en las pruebas no hay Keystore).
class AlmacenSesionMemoria implements AlmacenSesion {
  AlmacenSesionMemoria([this.sesion]);

  Sesion? sesion;

  @override
  Future<Sesion?> leer() async => sesion;

  @override
  Future<void> guardar(Sesion s) async => sesion = s;

  @override
  Future<void> borrar() async => sesion = null;
}

class AuthRepositoryFalso extends Mock implements AuthRepository {}

class PacientesRepositoryFalso extends Mock implements PacientesRepository {}

const usuarioPrueba = Usuario(
  id: 'u-1',
  nombre: 'Dr. Marco Munayco',
  email: 'doctor@gerenzdent.test',
);

Sesion sesionPrueba({
  String access = 'access-1',
  String refresh = 'refresh-1',
}) =>
    Sesion(accessToken: access, refreshToken: refresh, usuario: usuarioPrueba);

Paciente pacientePrueba({
  String id = 'p-1',
  String nombre = 'Juan Pérez',
  String whatsapp = '+51987654321',
  String? alergias,
  bool archivado = false,
}) => Paciente(
  id: id,
  nombre: nombre,
  whatsapp: whatsapp,
  alergias: alergias,
  archivado: archivado,
);

Pagina<Paciente> paginaDe(List<Paciente> pacientes) => Pagina(
  contenido: pacientes,
  pagina: 0,
  totalElementos: pacientes.length,
  totalPaginas: 1,
);
