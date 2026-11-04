import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class GerenzDentApp extends ConsumerWidget {
  const GerenzDentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'GERENZ DENT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      routerConfig: ref.watch(appRouterProvider),
      // Español de Perú: textos del sistema, calendarios y formatos (RNF-02).
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
