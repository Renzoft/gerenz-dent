import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agenda/presentation/agenda_page.dart';
import '../../features/ajustes/presentation/ajustes_page.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/cuenta/presentation/deudas_page.dart';
import '../../features/inicio/presentation/inicio_page.dart';
import '../../features/pacientes/presentation/paciente_detalle_page.dart';
import '../../features/pacientes/presentation/paciente_form_page.dart';
import '../../features/pacientes/presentation/pacientes_page.dart';
import '../../features/tratamientos/presentation/catalogo_page.dart';
import '../widgets/pantalla_de_carga.dart';
import 'navegacion_principal.dart';

abstract final class Rutas {
  static const cargando = '/cargando';
  static const login = '/login';
  static const inicio = '/';
  static const agenda = '/agenda';
  static const pacientes = '/pacientes';
  static const pacienteNuevo = '/pacientes/nuevo';
  static const deudas = '/deudas';
  static const ajustes = '/ajustes';
  static const catalogo = '/ajustes/catalogo';

  static String paciente(String id, {bool agendar = false}) =>
      '/pacientes/$id${agendar ? '?agendar=1' : ''}';
  static String pacienteEditar(String id) => '/pacientes/$id/editar';
}

/// Cuánto se ve, como mínimo, la pantalla de carga al abrir la app.
final duracionCargaMinimaProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

/// `true` cuando ya pasó el tiempo mínimo de la pantalla de carga.
///
/// Empieza a contar cuando la pantalla de carga ya está a la vista (la avisa
/// ella misma), no antes: mientras Android muestra su propia pantalla de
/// arranque, Flutter puede ir dibujando sin que el doctor lo vea.
final cargaMinimaCumplidaProvider = NotifierProvider<CargaMinima, bool>(
  CargaMinima.new,
);

class CargaMinima extends Notifier<bool> {
  Timer? _temporizador;

  @override
  bool build() {
    // Por si la pantalla de carga nunca llega a avisar (p. ej. la imagen no
    // carga), la app no se queda trabada: sigue igual a los pocos segundos.
    final respaldo = Timer(
      ref.read(duracionCargaMinimaProvider) * 3,
      () => state = true,
    );
    ref.onDispose(() {
      respaldo.cancel();
      _temporizador?.cancel();
    });
    return false;
  }

  /// Lo llama la pantalla de carga al verse por primera vez.
  void empezar() {
    if (_temporizador != null || state) return;
    _temporizador = Timer(
      ref.read(duracionCargaMinimaProvider),
      () => state = true,
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Avisa al router cuando cambia la sesión (o termina la pantalla de carga)
  // para que vuelva a evaluar redirect.
  final cambiosSesion = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => cambiosSesion.value++);
  ref.listen(cargaMinimaCumplidaProvider, (_, _) => cambiosSesion.value++);

  final router = GoRouter(
    initialLocation: Rutas.inicio,
    refreshListenable: cambiosSesion,
    redirect: (context, state) {
      final sesion = ref.read(authControllerProvider);
      final ruta = state.matchedLocation;
      // La pantalla de carga se ve siempre al abrir la app (al menos 2 s),
      // aunque la sesión ya esté guardada, y mientras se lee la sesión.
      final cargando =
          !ref.read(cargaMinimaCumplidaProvider) ||
          (sesion.isLoading && !sesion.hasValue);
      if (cargando) {
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
        builder: (context, state) => PantallaDeCarga(
          alMostrarse: () =>
              ref.read(cargaMinimaCumplidaProvider.notifier).empezar(),
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
                path: Rutas.agenda,
                builder: (context, state) => const AgendaPage(),
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
