import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pantallas con la barra inferior.
class NavegacionPrincipal extends StatelessWidget {
  const NavegacionPrincipal({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: BarraPrincipal(
        seleccionado: shell.currentIndex,
        onElegir: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}

/// Barra inferior: Inicio · Agenda · Pacientes · Deudas · Ajustes.
class BarraPrincipal extends StatelessWidget {
  const BarraPrincipal({
    super.key,
    required this.seleccionado,
    required this.onElegir,
  });

  final int seleccionado;
  final ValueChanged<int> onElegir;

  /// Con 5 destinos, una letra mayor partiría "Pacientes" en dos líneas: en
  /// esta barra la letra crece solo hasta 115 % (y nada en celulares de menos
  /// de 360 dp de ancho). El resto de la app sigue la letra del sistema, y
  /// cada etiqueta va con su ícono. Revisado en emulador a 320 y 393 dp.
  static double escalaMaxima(double ancho) => ancho < 360 ? 1.0 : 1.15;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).navigationBarTheme;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: escalaMaxima(MediaQuery.sizeOf(context).width),
      child: NavigationBarTheme(
        data: tema.copyWith(
          labelTextStyle: WidgetStateProperty.resolveWith(
            (estados) => tema.labelTextStyle
                ?.resolve(estados)
                ?.copyWith(fontSize: 13, letterSpacing: 0),
          ),
        ),
        child: NavigationBar(
          selectedIndex: seleccionado,
          onDestinationSelected: onElegir,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Agenda',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Pacientes',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Deudas',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}
