import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nombres de días y meses en español ("mar 11 nov").
  await initializeDateFormatting('es_PE');
  runApp(const ProviderScope(child: GerenzDentApp()));
}
