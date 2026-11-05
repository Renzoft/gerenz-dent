import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ajustes/presentation/ajustes_page.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/cuenta/presentation/deudas_page.dart';
import '../../features/inicio/presentation/inicio_page.dart';
import '../../features/pacientes/presentation/paciente_detalle_page.dart';
import '../../features/pacientes/presentation/paciente_form_page.dart';
import '../../features/pacientes/presentation/pacientes_page.dart';
import '../../features/tratamientos/presentation/catalogo_page.dart';
import '../widgets/estados.dart';
import 'navegacion_principal.dart';

abstract final class Rutas {
  static const cargando = '/cargando';
  static const login = '/login';
  static const inicio = '/';
  static const pacientes = '/pacientes';
  static const pacienteNuevo = '/pacientes/nuevo';
  static const deudas = '/deudas';
  static const ajustes = '/ajustes';
  static const catalogo = '/ajustes/catalogo';

  static String paciente(String id, {bool agendar = false}) =>
      '/pacientes/$id${agendar ? '?agendar=1' : ''}';
  static String pacienteEditar(String id) => '/pacientes/$id/editar';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Avisa al router cuando cambia la sesión para que vuelva a evaluar redirect.
  final cambiosSesion = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => cambiosSesion.value++);

  final router = GoRouter(
    initialLocation: Rutas.inicio,
    refreshListenable: cambiosSesion,
    redirect: (context, state) {
      final sesion = ref.read(authControllerProvider);
      final ruta = state.matchedLocation;
      if (sesion.isLoading && !sesion.hasValue) {
        return ruta == Rutas.cargando ? null : Rutas.cargando;
      }
      final autenticado = sesion.value != null;
      if (!autenticado) return ruta == Rutas.login ? null : Rutas.login;
      if (ruta == Rutas.login || ruta == Rutas.cargando) return Rutas.inicio;
      return null;
    },
    routes: [
      GoRoute(
        path: Rutas.cargando,
        builder: (context, state) => const Scaffold(
          body: VistaCargando(mensaje: 'Abriendo GERENZ DENT…'),
        ),
      ),
      GoRoute(
        path: Rutas.login,
        builder: (context, state) => const LoginPage(),
      ),
      // Pantallas completas (sin barra inferior).
      GoRoute(
        path: Rutas.pacienteNuevo,
        builder: (context, state) => const PacienteFormPage(),
      ),
      GoRoute(
        path: Rutas.catalogo,
        builder: (context, state) => const CatalogoPage(),
      ),
      GoRoute(
        path: '/pacientes/:id/editar',
        builder: (context, state) =>
            PacienteFormPage(pacienteId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/pacientes/:id',
        builder: (context, state) => PacienteDetallePage(
          pacienteId: state.pathParameters['id']!,
          abrirAgendar: state.uri.queryParameters['agendar'] == '1',
        ),
      ),
      // Pestañas con barra inferior.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => NavegacionPrincipal(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.inicio,
                builder: (context, state) => const InicioPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.pacientes,
                builder: (context, state) => const PacientesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.deudas,
                builder: (context, state) => const DeudasPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.ajustes,
                builder: (context, state) => const AjustesPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    cambiosSesion.dispose();
  });
  return router;
});
