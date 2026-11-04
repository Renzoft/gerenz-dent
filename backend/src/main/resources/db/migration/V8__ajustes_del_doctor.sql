-- Versión 1.1: cambios pedidos por el doctor tras probar la app.

-- 1. Nombre completo con el que firma los mensajes de WhatsApp.
UPDATE usuario
SET nombre = 'Dr. Marco Munayco Chacón'
WHERE nombre = 'Dr. Marco Munayco';

-- 2. Aviso diario a las 4:30 p. m. (antes 5:30): los pacientes reciben el recordatorio con más
--    anticipación. Solo cambia a quien seguía con la hora por defecto.
ALTER TABLE usuario ALTER COLUMN hora_notificacion SET DEFAULT '16:30';

UPDATE usuario
SET hora_notificacion = '16:30'
WHERE hora_notificacion = '17:30';
