import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
import '../application/auth_controller.dart';

/// Inicio de sesión (HU-01). Solo se ve la primera vez: la sesión se recuerda.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _ocultarClave = true;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_email.text, _password.text);
    } catch (e) {
      // Si la API devolvió un error por campo, se muestra ese (es más claro
      // que el genérico "Revisa los campos marcados").
      final error = ApiError.desde(e);
      if (mounted) {
        setState(
          () => _error = error.errores.values.firstOrNull ?? error.mensaje,
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.superficieMarca,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Espacio.xl),
            child: Form(
              key: _formulario,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/branding/logo-horizontal.png',
                      height: 64,
                      fit: BoxFit.contain,
                      semanticLabel: 'GERENZ DENT, consultorio odontológico',
                    ),
                    const SizedBox(height: Espacio.xxl),
                    Semantics(
                      header: true,
                      child: Text(
                        'Bienvenido',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: Espacio.xs),
                    const Text(
                      'Ingresa con tu correo y contraseña. Solo se pide una vez.',
                      style: TextStyle(
                        fontSize: TipoTam.cuerpo,
                        color: Tokens.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: Espacio.xl),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Ingresa tu correo';
                        if (!t.contains('@')) return 'Correo no válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: Espacio.lg),
                    TextFormField(
                      controller: _password,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _ocultarClave
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          icon: Icon(
                            _ocultarClave
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _ocultarClave = !_ocultarClave),
                        ),
                      ),
                      obscureText: _ocultarClave,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _ingresar(),
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'Ingresa tu contraseña' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Espacio.lg),
                      Aviso(
                        key: const Key('login-error'),
                        tono: Tono.peligro,
                        icono: Icons.error_outline,
                        texto: _error!,
                      ),
                    ],
                    const SizedBox(height: Espacio.xl),
                    FilledButton(
                      onPressed: _enviando ? null : _ingresar,
                      child: _enviando
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Tokens.textoSobreAccion,
                              ),
                            )
                          : const Text('Ingresar'),
                    ),
                    if (_enviando) ...[
                      const SizedBox(height: Espacio.md),
                      const Text(
                        'Conectando con el consultorio… la primera vez del día '
                        'puede tardar hasta 1 minuto.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: TipoTam.cuerpo,
                          color: Tokens.textoSecundario,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
