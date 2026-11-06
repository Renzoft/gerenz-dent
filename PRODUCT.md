# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Un solo usuario: el odontólogo del consultorio GERENZ DENT, el Dr. Marco Munayco Chacón. Es un adulto con
experiencia digital básica: usa WhatsApp a diario, pero no está acostumbrado a apps de gestión. Usa la app
entre pacientes, con poco tiempo, y cada tarde para avisar a los citados del día siguiente. Su hijo (el
desarrollador) le da soporte.

## Product Purpose

Que ningún paciente olvide su control y que el doctor sepa en todo momento quién le debe y cuánto.
La app registra pacientes, agenda el próximo control de cada tratamiento, avisa cada día a las 4:30 p. m. a
quién recordar, abre WhatsApp con el mensaje ya escrito (el doctor solo presiona enviar), da seguimiento a
quienes no vinieron y lleva deudas y pagos por tratamiento.

Éxito: el doctor envía los recordatorios de mañana en un par de toques, encuentra a un paciente al instante y,
al atenderlo, registra asistencia y pago sin dudar.

## Positioning

Hecha a la medida de un consultorio de una sola persona: sin agenda formal (las citas se acuerdan de palabra y
son aproximadas), sin presupuesto para la API de WhatsApp y con un usuario no técnico. No compite con
software de clínicas: reemplaza la memoria y el cuaderno del doctor.

## Operating Context

- Consultorio: lunes a viernes desde las 6 p. m., sábados desde las 4 p. m., domingos de 8 a. m. a 10 p. m.
- Unos 7 pacientes por semana. Citas aproximadas: muchos vienen días después (seguimiento de vencidos).
- El aviso diario llega a las 4:30 p. m.; el doctor abre Inicio y envía los recordatorios uno por uno.
- Al atender: marca "Asistió", registra lo que pagó y agenda el siguiente control.
- Se instala por APK (fuera de Play Store), Android 8.0 o superior, celular del doctor.

## Capabilities and Constraints

- Flutter (Material 3), Riverpod, go_router, dio. Backend propio Spring Boot (Render + Neon), fuera del alcance
  de la interfaz.
- Precios: fijo, por pieza, o inicial + cuota mensual (brackets: la cuota se cobra cuando el paciente asiste).
- Deuda = cargos válidos − pagos válidos, por tratamiento.
- Estados de un control: Pendiente, Recordado, Confirmó, Asistió, No vino, Cancelado (+ "Vencido", derivado).
- Términos del dominio usados hoy en la interfaz: control, tratamiento, plan, cargo, pago, deuda.
- Requiere internet (online-first); el servidor gratuito puede tardar hasta 1 minuto en despertar.

## Brand Commitments

- Nombre: GERENZ DENT (dos palabras). Logo "Cristal" (2026-11-05): muela de vidrio con destello sobre luces celeste y verde en fondo #0A5676; nombre en Sora ExtraBold (`docs/branding/`).
- Paleta obligatoria de 3 colores: celeste #3BB5E8 (primario/marca), blanco #FFFFFF (fondos),
  verde #22B573 (acento/acción principal). Solo se derivan tintes, sombras y neutros de ellos.
- Fuente del logo: Sora (exportado como imagen). Títulos de la app: Montserrat.
- Los mensajes a pacientes van en "usted" y firmados "Dr. Marco Munayco Chacón".
- Tono: profesional y de confianza, limpio, cercano; salud y orden, sin verse frío ni genérico.

## Evidence on Hand

- Datos de pacientes: datos personales y de salud. En pruebas, capturas y ejemplos solo datos ficticios.
- No hay testimonios ni métricas de uso; no inventarlos.

## Product Principles

1. Una tarea, una acción evidente: el doctor nunca debe preguntarse qué botón tocar.
2. Lenguaje del consultorio, no del sistema.
3. Pocas cosas en pantalla; el detalle se abre cuando se pide.
4. Nada se pierde: confirmar lo irreversible y permitir deshacer.
5. Legible primero: texto grande, contraste alto, estados con ícono y texto.

## Accessibility & Inclusion

WCAG 2.2 AA (4.5:1 texto, 3:1 texto grande/íconos/bordes de controles). Texto base ≥ 16 sp y la interfaz debe
funcionar con el tamaño de fuente del sistema al máximo (200 %). Áreas táctiles ≥ 48 dp. Etiquetas para
TalkBack. Respetar "reducir movimiento". Sin modo oscuro por ahora.

El doctor usa el tamaño de letra del sistema por defecto (confirmado). El 200 % se sigue probando como
requisito, pero el diseño se optimiza para el tamaño normal.

Estados: la paleta de marca se complementa con colores funcionales aprobados (rojo para error/alergia/vencido
y ámbar para pendientes), siempre acompañados de ícono y texto.
