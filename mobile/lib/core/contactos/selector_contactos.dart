import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contacto elegido en la agenda del teléfono.
class ContactoElegido {
  const ContactoElegido({this.nombre, this.telefono});

  final String? nombre;
  final String? telefono;
}

/// Importar el número desde los contactos (HU-07). Usa el selector nativo de
/// Android: la app solo recibe el contacto que el doctor elige, sin pedir
/// permiso para leer toda la agenda.
abstract class SelectorContactos {
  /// `null` si el doctor cancela.
  Future<ContactoElegido?> elegirTelefono();
}

class SelectorContactosNativo implements SelectorContactos {
  final _selector = FlutterNativeContactPicker();

  @override
  Future<ContactoElegido?> elegirTelefono() async {
    final contacto = await _selector.selectPhoneNumber();
    if (contacto == null) return null;
    return ContactoElegido(
      nombre: contacto.fullName,
      telefono:
          contacto.selectedPhoneNumber ?? contacto.phoneNumbers?.firstOrNull,
    );
  }
}

final selectorContactosProvider = Provider<SelectorContactos>(
  (ref) => SelectorContactosNativo(),
);
