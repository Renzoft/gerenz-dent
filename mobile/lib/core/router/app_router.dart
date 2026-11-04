import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/inicio/presentation/inicio_page.dart';

abstract final class Rutas {
  static const inicio = '/';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Rutas.inicio,
    routes: [
      GoRoute(
        path: Rutas.inicio,
        builder: (context, state) => const InicioPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
