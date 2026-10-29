# Palabreo 1.19 recuperado

Recuperación desde `assets/Palabra.html` de la APK aportada. No se han añadido mejoras ni cambiado reglas, textos, diccionarios, estilos o integración con el servidor. El README preexistente se conserva. La carpeta `/workspace/recuperacion-palabreo-1.19` permanece intacta y no es necesaria para ejecutar este proyecto.

## Archivos editables

- `index.html`: estructura y referencias locales.
- `css/palabreo.css`: bloque CSS original.
- `js/theme.js`: tema, ejecutado en la cabecera antes de aplicar estilos.
- `js/game.js`: diccionarios integrados, reglas, interfaz, estadísticas y funciones locales.
- `js/auth.js`: autenticación original.
- `js/competitions.js`: ligas, competición y rankings originales.

Los scripts siguen siendo clásicos, sin `defer`, `async` ni módulos: se mantiene su orden y ámbito compartido. La separación es mecánica. `RECOVERY-MAP.json` conserva los hashes de los bloques y del HTML original. No se necesitan npm, dependencias JavaScript ni un proceso de compilación para jugar en el navegador.

## Ejecutar y reconstruir el asset

Desde `/workspace/Pruebas` (o desde la raíz donde se descomprima el ZIP):

```sh
python -m http.server 8000 --bind 127.0.0.1
```

Abrir `index.html` a través del servidor local. Parar con Ctrl+C. Cada tarea en la nube ya tiene su entorno aislado; utilizar este checkout, sin crear worktrees salvo petición expresa.

Para reconstruir el archivo único destinado a la WebView Android:

```sh
python tools/build_html.py
```

Produce `dist/assets/Palabra.html`. En esta recuperación su SHA-256 coincide exactamente con el original:
`ac77d38068ac465fac3979f2660d3f01884e294f394aa75fc97666dab69d3f0e`.
El script informa de la coincidencia; tras futuras ediciones es normal que cambie el hash. No compila ni firma una APK.

## Validación realizada

Los cuatro JS pasan `node --check`. `python tests/smoke.py` pasa en Chromium tanto sobre `index.html` como sobre el asset reconstruido: 12 comprobaciones por versión (24 en total), sin errores de página. Resultado detallado: `validation/browser-results.json`.

Probado: carga y 30 casillas, rechazo de palabra inválida sin consumir intento, persistencia de entrada al recargar, victoria y pistas correctas en Normal, resultado compartido sin solución, nueva partida, persistencia del tema y de colores, victoria en Difícil, teclado con tildes y victoria en Tildes, derrota tras seis intentos válidos. Los aciertos se introducen por botones reales; la prueba consulta únicamente la solución de su partida local para poder completar la ronda de forma reproducible. No es una auditoría exhaustiva de todas las reglas ni una prueba en un teléfono.

El test necesita Python, Playwright (versión en `tests/requirements.txt`) y Chromium en `/usr/bin/chromium`. Puede instalarse el paquete de pruebas con `python -m pip install -r tests/requirements.txt`; Chromium se instala mediante el gestor de paquetes del sistema. El entorno usado ya los proporciona. El test abre un servidor temporal, usa perfiles de navegador nuevos, bloquea TODAS las peticiones no locales y cierra el servidor al terminar. No usa cuentas reales.

## Funciones no verificadas y datos

No se ha ejecutado SQL ni realizado peticiones a Supabase. Se conservan sin cambios la URL y la clave pública publishable incluidas en el HTML; no son una copia de la base de datos ni una credencial administrativa. Autenticación, recuperación de cuenta, alias, rankings, ligas, competición global, invitaciones y avisos de palabras dependen del backend y no se han validado. No se recuperan de una APK las tablas, funciones RPC, políticas RLS, usuarios, resultados ni datos históricos del servidor. Los nombres RPC encontrados se recogen en `android-reference/INSPECCION.json`, sin ejecutarlos.

Las definiciones de Wikcionario, enlaces RAE, portapapeles y compartir mediante aplicaciones externas no se han comprobado con servicios reales. Sí se ha comprobado la generación del texto compartido. Las estadísticas de pruebas son nuevas y locales: no se han recuperado las partidas guardadas en un teléfono. El almacenamiento del navegador se vincula al origen; cambiar dominio o puerto no traslada sus datos.

## Android y firma: qué se conserva y qué falta

La APK declara paquete `com.palabreo.app`, versión `1.19`, versionCode `20`, minSdk `26`, targetSdk y compileSdk `35`. Usa una WebView con el asset en `https://appassets.androidplatform.net/assets/Palabra.html` y puentes `PalabreoActions`, `PalabreoAppearance` y `PalabreoReminders`. Incluye actividad principal, receptor y servicio de recordatorios, permisos de Internet, notificaciones, alarmas y arranque del dispositivo.

`android-reference/` conserva las otras ocho entradas de la APK, copiadas sin alteración: DEX, manifiesto y recursos compilados, iconos binarios y metadatos de firma. Son referencia binaria, no un proyecto Android editable. El código nativo existe compilado en `classes.dex`; no se han recuperado ni decompilado sus fuentes Java/Kotlin. Los recordatorios, notificaciones, sesión nativa, barras del sistema y acciones Android no se pueden validar en Chromium.

Para una reconstrucción mantenible faltan las fuentes originales del contenedor Android (o su recuperación por decompilación y revisión), configuración Gradle/wrapper y dependencias, recursos/manifiesto fuente, toolchain Android SDK/Build Tools compatible con API 35 y pruebas en emulador o dispositivo. Este ZIP NO contiene una APK nueva ni un proyecto Android compilable. No se ha instalado un SDK ni intentado compilar Android en esta fase.

El certificado público de firma conservado tiene sujeto `CN=Palabra personal` y huella SHA-256:
`32:50:7F:D4:A2:5A:F4:EC:FE:33:EE:D9:4F:24:B5:2B:0A:9F:57:2F:7D:1E:F3:35:A2:A5:06:B7:D3:3A:1F:4A`.

No aparece ningún almacén o archivo de clave privada en `/workspace` ni entre las nueve entradas APK. Los archivos `META-INF/PALABRA.RSA` y `.SF` contienen certificado/firma, NO la clave privada, que no puede extraerse del certificado. No se puede afirmar que la clave exista en otro equipo. Debe recuperarse el almacén original y sus credenciales por un canal seguro, o comprobar con el responsable de distribución si existe Play App Signing. No se ha consultado Google Play y no se presupone esa opción.

Para actualizar directamente una instalación existente se requiere el mismo paquete, una firma compatible con la instalación (normalmente la misma clave original) y un versionCode mayor que 20. Una clave nueva ordinaria no permitirá sustituir la aplicación instalada. No desinstalarla para probar: se podrían perder datos locales. Conservar la APK antigua permite reinstalar esa versión, pero no firmar una actualización modificada. La lectura del certificado y la comprobación CRC/hash realizadas no equivalen a una verificación criptográfica completa de todos los esquemas de firma APK.
