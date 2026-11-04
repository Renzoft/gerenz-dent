# 05 · Pantallas (wireframes de baja fidelidad)

Principios: **pocos toques, letras grandes, un botón principal por pantalla**. Navegación inferior con 4 pestañas:
**Inicio · Pacientes · Deudas · Ajustes**. Botón flotante **"+ Paciente"** siempre visible en Inicio y Pacientes.

## P1 · Inicio (lo primero que ve el doctor)

```
┌──────────────────────────────────┐
│ 🦷 GERENZ DENT        lun 10 nov │
├──────────────────────────────────┤
│ RECORDAR PARA MAÑANA (3)         │
│ ┌──────────────────────────────┐ │
│ │ Juan Pérez · Brackets        │ │
│ │ mar 11 · 6:00 p. m.  [Enviar]│ │
│ └──────────────────────────────┘ │
│ ┌──────────────────────────────┐ │
│ │ Ana Ríos · Limpieza  ✔ Envia.│ │
│ └──────────────────────────────┘ │
│ [ Enviar todos uno por uno  ▶ ]  │
├──────────────────────────────────┤
│ VENCIDOS (2)                     │
│ Luis T. · Brackets · hace 4 días │
│                    [Seguimiento] │
├──────────────────────────────────┤
│ ME DEBEN: S/ 3 450 (6 pacientes) │
└──────────────────────────────────┘
 [Inicio] [Pacientes] [Deudas] [⚙]   (+)
```

"Enviar todos uno por uno": abre WhatsApp del primero; al volver, pregunta "¿Se envió?" y pasa al siguiente.

## P2 · Nuevo paciente (un solo formulario, ≤ 30 s)

```
┌──────────────────────────────────┐
│ ← Nuevo paciente                 │
│ Nombre *        [______________] │
│ WhatsApp *      [+51 9________] 📇│  ← importar de contactos
│ ▸ Más datos (edad, alergias, nota)│  ← colapsado
│ ☑ Autoriza recordatorios WhatsApp│
│ ─────── Próximo control ──────── │
│ Tratamiento *   [Brackets     ▼] │
│ Fecha *  [+1 sem][+15 d][+1 mes] │
│          [+3 m ][+6 m ][📅 otra] │
│ Hora            [—  opcional   ] │
│ Nota            [— opcional    ] │
│ Piezas          [ 1 ]  ← solo si es por pieza
│ Costo S/        [ 500.00 ] (auto, editable)
│ Pagó hoy S/     [— opcional    ] │
│                                  │
│        [   GUARDAR   ]           │
└──────────────────────────────────┘
```

Al elegir "Brackets" se preselecciona "+1 mes" y el costo inicial S/ 500. Al elegir "Puente de zirconio"
aparece "Piezas" y el costo se recalcula (2 piezas → S/ 1 400).

## P3 · Ficha del paciente

```
┌──────────────────────────────────┐
│ ← Juan Pérez            [✎]      │
│ 📱 +51 987 654 321   [WhatsApp]  │
│ ⚠ Alergia: penicilina            │
├──────────────────────────────────┤
│ PRÓXIMO CONTROL                  │
│ Brackets · mar 11 nov · 6 p. m.  │
│ [Asistió] [No vino] [Reprogramar]│
├──────────────────────────────────┤
│ DEUDA: S/ 1 200   [+ Registrar pago]
│ Brackets  cargos 1 300 · pagó 100│
├──────────────────────────────────┤
│ HISTORIAL                        │
│ 10 oct · Brackets · Asistió      │
│ 09 sep · Brackets · Asistió      │
└──────────────────────────────────┘
```

"Asistió" → hoja inferior: "Cuota del mes S/ 100 ✔ · ¿Pagó algo hoy? [____] · ¿Próximo control? Brackets ·
10 dic [Guardar] [Ahora no]".

## P4 · Pacientes
Buscador arriba (nombre o número), lista alfabética, filtro "Con deuda" / "Archivados".

## P5 · Deudas
Total arriba, lista ordenada por monto, toque → ficha del paciente.

## P6 · Ajustes
Hora de la notificación diaria · Catálogo de tratamientos · Texto de los mensajes (vista previa) · Cerrar sesión ·
Versión de la app.

## P0 · Login
Logo, correo, contraseña, "Ingresar". Solo se ve la primera vez.
