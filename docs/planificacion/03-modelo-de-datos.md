# 03 · Modelo de datos

Base de datos: **PostgreSQL** (Neon). Migraciones versionadas con **Flyway**. Todas las tablas tienen
`id UUID`, `created_at`, `updated_at` (auditoría) y se borran de forma lógica cuando aplica.

## 1. Diagrama entidad–relación

```mermaid
erDiagram
    USUARIO ||--o{ PACIENTE : registra
    PACIENTE ||--o{ PLAN_TRATAMIENTO : tiene
    TRATAMIENTO ||--o{ PLAN_TRATAMIENTO : "se aplica en"
    PLAN_TRATAMIENTO ||--o{ CONTROL : agenda
    PLAN_TRATAMIENTO ||--o{ CARGO : genera
    PLAN_TRATAMIENTO ||--o{ PAGO : recibe
    CONTROL |o--o| CARGO : "cuota mensual"
    CONTROL ||--o{ RECORDATORIO : genera

    USUARIO {
        uuid id PK
        string email UK
        string password_hash
        string nombre
        time hora_notificacion "default 17:30"
    }
    PACIENTE {
        uuid id PK
        uuid usuario_id FK
        string nombre
        string whatsapp "E.164, UK entre activos"
        smallint edad "nullable"
        string alergias "nullable"
        string nota "nullable"
        boolean consiente_whatsapp
        boolean archivado
    }
    TRATAMIENTO {
        uuid id PK
        string nombre UK
        string tipo_precio "FIJO | POR_PIEZA | INICIAL_MAS_MENSUAL"
        numeric precio_base "nullable"
        numeric precio_mensual "nullable, solo INICIAL_MAS_MENSUAL"
        int intervalo_control_dias "nullable"
        smallint edad_maxima_control "nullable; flúor = 12"
        boolean activo
    }
    PLAN_TRATAMIENTO {
        uuid id PK
        uuid paciente_id FK
        uuid tratamiento_id FK
        smallint piezas "nullable, solo POR_PIEZA"
        string estado "ACTIVO | FINALIZADO"
        date fecha_inicio
    }
    CARGO {
        uuid id PK
        uuid plan_tratamiento_id FK
        uuid control_id FK "nullable: cuota de ese control"
        string concepto "INICIAL | MENSUAL | TRATAMIENTO | OTRO"
        numeric monto "editable por el doctor"
        date fecha
        string estado "VALIDO | ANULADO"
    }
    CONTROL {
        uuid id PK
        uuid plan_tratamiento_id FK
        date fecha
        time hora "nullable"
        string nota "nullable, max 140"
        string estado "PENDIENTE | RECORDADO | CONFIRMADO | ASISTIO | NO_ASISTIO | CANCELADO"
    }
    RECORDATORIO {
        uuid id PK
        uuid control_id FK
        string tipo "PREVIO | SEGUIMIENTO"
        string canal "WHATSAPP_MANUAL | WHATSAPP_API (futuro)"
        timestamptz enviado_at
    }
    PAGO {
        uuid id PK
        uuid plan_tratamiento_id FK
        numeric monto
        date fecha
        string medio "EFECTIVO | YAPE | PLIN | TRANSFERENCIA | OTRO"
        string estado "VALIDO | ANULADO"
        string motivo_anulacion "nullable"
    }
```

## 2. Por qué existe `PLAN_TRATAMIENTO`

Es la pieza que une **recordatorios** y **deudas** sin pedirle más datos al doctor:

- "Juan · Brackets" es **un** plan. De él cuelgan sus controles mensuales, sus cargos y sus abonos.
- La deuda de Juan = Σ cargos válidos − Σ pagos válidos de todos sus planes. Nunca se guarda: se calcula.

## 2.1 Por qué existe `CARGO` (y no un "costo total")

El consultorio cobra de tres formas (ver [08-catalogo-tratamientos.md](08-catalogo-tratamientos.md)), y en
brackets el total **no se conoce al inicio**: depende de cuántos meses dure. Por eso la deuda es un libro de
movimientos (cargos − pagos), generados automáticamente:

| Evento | Cargo automático (monto editable) |
|---|---|
| Se crea un plan `FIJO` | `TRATAMIENTO` = precio_base |
| Se crea un plan `POR_PIEZA` | `TRATAMIENTO` = precio_base × piezas |
| Se crea un plan `INICIAL_MAS_MENSUAL` | `INICIAL` = precio_base |
| Un control de un plan `INICIAL_MAS_MENSUAL` pasa a `ASISTIO` | `MENSUAL` = precio_mensual (ligado al control) |

Ejemplo: Juan inicia brackets (cargo S/ 500), paga S/ 300 → debe S/ 200. Asiste al control de diciembre
(cargo S/ 100) y paga S/ 100 → sigue debiendo S/ 200. Si ese día no le cobra la cuota, el doctor anula el cargo.
- Si mañana se agregan sesiones, odontograma o presupuestos, se cuelgan del plan sin romper nada.

En la UI el plan es **invisible**: el doctor solo elige "paciente + tratamiento"; si ya existe un plan activo
para esa combinación, se reutiliza; si no, se crea.

## 3. Máquina de estados del control

```mermaid
stateDiagram-v2
    [*] --> PENDIENTE: registrar
    PENDIENTE --> RECORDADO: envió WhatsApp
    RECORDADO --> CONFIRMADO: paciente respondió SÍ
    PENDIENTE --> CONFIRMADO
    PENDIENTE --> ASISTIO
    RECORDADO --> ASISTIO
    CONFIRMADO --> ASISTIO
    RECORDADO --> NO_ASISTIO
    CONFIRMADO --> NO_ASISTIO
    PENDIENTE --> CANCELADO
    RECORDADO --> CANCELADO
    CONFIRMADO --> CANCELADO
    ASISTIO --> [*]: propone siguiente control
    NO_ASISTIO --> [*]
    CANCELADO --> [*]
```

"Vencido" **no es un estado**: es una consulta (`fecha < hoy AND estado IN (PENDIENTE, RECORDADO, CONFIRMADO)`).
Así, si el paciente llega 4 días tarde, el doctor simplemente marca "asistió".
Reprogramar = cambiar la fecha y volver a `PENDIENTE`.

## 4. Índices previstos

| Tabla | Índice | Uso |
|---|---|---|
| paciente | `UNIQUE (whatsapp) WHERE archivado = false` | Evitar duplicados |
| paciente | `GIN (nombre gin_trgm_ops)` | Búsqueda parcial por nombre |
| control | `(fecha, estado)` | Lista de "mañana" y "vencidos" |
| cargo | `(plan_tratamiento_id) WHERE estado = 'VALIDO'` | Cálculo de saldo |
| cargo | `UNIQUE (control_id) WHERE control_id IS NOT NULL` | Una sola cuota por control |
| pago | `(plan_tratamiento_id) WHERE estado = 'VALIDO'` | Cálculo de saldo |
