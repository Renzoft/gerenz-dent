import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/application/auth_controller.dart';

/// Ajustes (iteración 1: cuenta y cerrar sesión). La hora del aviso diario y
/// el catálogo de tratamientos se agregan en las iteraciones 2, 3 y 5.
class AjustesPage extends ConsumerWidget {
  const AjustesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(usuario?.nombre ?? ''),
            subtitle: Text(usuario?.email ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              final ok = await confirmar(
                context,
                titulo: 'Cerrar sesión',
                mensaje:
                    'Tendrás que ingresar tu correo y contraseña de nuevo.',
                accion: 'Cerrar sesión',
              );
              if (ok) await ref.read(authControllerProvider.notifier).logout();
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('GERENZ DENT'),
            subtitle: Text('Versión 0.2.0 · ${Env.apiUrl}'),
          ),
        ],
      ),
    );
  }
}
