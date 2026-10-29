# Actualización de Supabase para Palabreo 1.20

**Todavía no aplicada en Supabase.** Solo se ha ejecutado contra PostgreSQL local con datos ficticios.

## Qué hace exactamente

1. Añade `leagues.length_mode`, con valores 5, 6, 7 o `random`. Todas las ligas existentes reciben 5. Un disparador impide cambiarla después.
2. Añade longitud a los planes diarios y desafíos. Los ya existentes conservan cinco letras y sus palabras asignadas.
3. Amplía las restricciones del catálogo, soluciones, reservas e intentos a 5–7 letras. Los seis intentos máximos y la puntuación siguen igual.
4. Añade una función de creación para las nuevas longitudes. Conserva la función antigua para que sigan funcionando los clientes de cinco letras.
5. Actualiza la asignación de jornadas, las vistas JSON de partidas, validación/pistas y avisos de palabras. En Global fuerza cinco letras. En aleatoria elige una longitud equiprobable al preparar el día y la guarda con el plan; el bloqueo diario impide que dos usuarios reciban jornadas diferentes.
6. Añade al catálogo 10.000 propuestas sin tildes por longitud nueva, con 3.000 soluciones cada una. No cambia el catálogo de cinco letras. Las variantes con tildes se utilizan en el juego libre.
7. Mantiene tablas, filas, políticas RLS, propietarios y permisos existentes. No elimina ni reinicia usuarios, cuentas, ligas, membresías, jornadas, resultados, invitaciones o clasificaciones. No toca `auth.users` ni objetos ajenos a Palabreo, como `tdc_document_archives`.

## Cómo copiar y aplicar

- Antes de aplicar, disponer de una copia de seguridad del proyecto Supabase.
- Abrir `COPIAR-ACTUALIZACION.html` en un navegador y pulsar **Copiar SQL completo**. Si el navegador no permite el portapapeles, el botón selecciona todo el texto para copiarlo manualmente.
- Alternativamente usar `migrations/palabreo_1_20.sql` o `palabreo_1_20.txt`: contienen exactamente el mismo texto completo. Incluye los datos de diccionario; no omitir esas líneas largas.
- En Supabase SQL Editor, abrir una consulta nueva, pegar TODO y revisar antes de ejecutarlo. Requiere el rol administrativo del proyecto.
- El script contiene `BEGIN` y `COMMIT`: se aplica completo o revierte si aparece un error. Si ya detecta la columna nueva, se detiene para evitar reaplicar una migración o pisar otra versión. Un fallo por bloqueo requiere esperar a que terminen las operaciones en curso, no borrar datos ni quitar controles.
- Después de una ejecución correcta, compartir el resultado. Las pruebas contra Supabase y un teléfono real siguen pendientes hasta entonces.

La aplicación no ejecuta esta actualización automáticamente. La nueva APK puede jugar libremente sin ella; las ligas de seis/siete/aleatoria muestran que falta actualizar el servidor. No mezclar ni ejecutar los archivos de `tests/`, que son exclusivamente para una base de prueba local.

## Alcance de las pruebas

La estructura y las funciones afectadas se obtuvieron de metadatos reales enviados por el usuario. Las pruebas locales usan esa estructura, funciones y políticas; `auth.uid`, pertenencia a ligas y cálculo de semana se modelan en la instalación local de prueba. No se ha copiado una base Supabase completa ni sus datos. Se prueba conservación de filas ficticias anteriores, permisos de tablas, intentos duplicados, seis intentos, puntuación, creación/configuración, jornada aleatoria, concurrencia y rechazo seguro de una segunda aplicación.

Esto no reemplaza una verificación del entorno Supabase real tras aplicar el SQL. No se afirma que la actualización ya esté activa.
