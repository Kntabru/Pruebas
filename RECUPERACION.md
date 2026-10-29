# Palabreo recuperado: estado 1.20

La base 1.19 se recuperó de la APK del usuario y se guardó en el commit `d4690af`. El HTML reconstruido en esa base coincidía byte por byte con el asset original. La carpeta `/workspace/recuperacion-palabreo-1.19` permanece intacta. El estado actual incorpora únicamente la ampliación autorizada a 6/7 letras y la configuración de longitud de ligas.

## Qué hay

- `index.html`, `css/` y `js/`: juego editable, sin dependencias npm.
- `data/`, `DICTIONARY.md` y `licenses/`: diccionarios nuevos, selección y licencias. Los listados originales de cinco letras se conservan sin cambios.
- `dist/assets/Palabra.html`: archivo único generado para Android.
- `android-reference/`: DEX, manifiesto y recursos originales compilados, no fuentes Java/Kotlin.
- `tools/`: construcción del asset, APK y SQL; no genera claves de firma.
- `sql/observed/`: funciones reales aportadas por el usuario, como referencia. No es un volcado completo del servidor.
- `sql/migrations/palabreo_1_20.sql`: actualización transaccional preparada y probada localmente; NO aplicada en Supabase.
- `sql/COPIAR-ACTUALIZACION.html`: copia íntegra del SQL con botón para copiar. No ejecuta SQL.
- `tests/` y `validation/`: pruebas y resultados, con las limitaciones indicadas.

## Jugar y construir

Desde la raíz del proyecto:

```sh
python -m http.server 8000 --bind 127.0.0.1
python tools/build_html.py
```

El primer comando sirve el proyecto localmente; terminarlo con Ctrl+C cuando ya no se necesite. El segundo se ejecuta en otra terminal y genera el asset único. El entorno de cada tarea ya está aislado; reutilizar el checkout sin crear worktrees salvo petición expresa.

En modo libre se elige longitud 5, 6 o 7 con un selector independiente de Normal/Difícil/Tildes. Hay seis intentos en todas las longitudes. Cambiar de modo o longitud con una partida empezada cuenta como abandono tras confirmación. Las estadísticas se conservan por modalidad y en total, combinando longitudes; se mantiene la compatibilidad con el almacenamiento de 1.19.

En Global se mantienen cinco letras. Las ligas antiguas se interpretan como cinco. Las nuevas opciones 6/7/aleatoria necesitan aplicar primero el SQL del servidor. La longitud solo se elige al crear la liga; el número de palabras al día sigue siendo independiente. La asignación diaria aleatoria elige entre las tres longitudes con `floor(random()*3)+5`, guarda el resultado en el plan diario y comparte las mismas palabras con todos los miembros.

Consultar `ANDROID.md` para compilar y restaurar la firma; `sql/LEEME.md` para la actualización de la base de datos. La clave privada y su contraseña se entregan en un ZIP separado, fuera del repositorio.

## Qué está probado

- Las nueve combinaciones de modo y longitud, tanto en archivos editables como en el asset único, con anchura móvil de 320 píxeles.
- Entrada y borrado de letras, longitud, pistas/repeticiones, victoria, derrota, persistencia, colores, tema y resultado compartido.
- Carga de partidas y estadísticas anteriores de cinco letras.
- Migración SQL sobre PostgreSQL 17 local con datos inventados: conservación de filas previas, ACL/RLS, ligas antiguas, nuevas longitudes, idempotencia de intentos, puntuación, avisos, permisos y asignación aleatoria consistente incluso con accesos simultáneos.
- Interfaz de ligas contra las funciones migradas locales. La autenticación/perfil/actividad social se simulan; no es una prueba de cuentas reales.
- APK firmada con v2/v3 y construcción reproducible desde un respaldo de firma restaurado.

No se ha ejecutado SQL ni realizado peticiones al servidor Supabase real. Sus metadatos se han recibido mediante consultas de solo lectura ejecutadas por el usuario. No se han recuperado ni descargado filas de usuarios, partidas, invitaciones o soluciones del servidor.

No se han probado con servicios reales correo, contraseña, definiciones externas ni notificaciones Android. No se ha instalado la APK en un móvil. No se ha recuperado la firma antigua: la nueva APK requiere reinstalación y perderá las estadísticas locales, conforme a la autorización del usuario. Las cuentas y datos online no se borran.
