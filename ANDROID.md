# Construcción Android reproducible — Palabreo 1.20

La aplicación mantiene el paquete `com.palabreo.app`, minSdk 26, targetSdk 35, versión visible **1.20** y versionCode **22**. La recuperación original no se modifica.

Se reconstruye el HTML a partir de archivos editables y se empaqueta con el **mismo DEX y los mismos recursos compilados** de la APK 1.19. Así se conservan los puentes de sesión, compartir, apariencia y recordatorios, junto con el receptor de arranque y el servicio de avisos. Solo se cambian la versión del manifiesto, el contenido web y la firma. No se afirma haber recuperado fuentes Java/Kotlin ni un proyecto Gradle: no son necesarios para este procedimiento de empaquetado, pero siguen pendientes si se quiere modificar código nativo.

## Construir

Requisitos: Python 3, Java 21 o JRE compatible y apksigner de Android 35.0.2. El instalador usa paquetes de Debian con hashes SHA-256 fijados, obtenidos de índices firmados. No necesita permisos de administrador para extraerlos.

```sh
python tools/install_android_tools.py /ruta/fuera-del-proyecto/android-tools
python tools/build_android.py \
  --signing-dir /ruta/fuera-del-proyecto/firma-palabreo \
  --apksigner-dir /ruta/fuera-del-proyecto/android-tools/usr/share/java
```

En el ZIP del proyecto se incluyen también las herramientas públicas en `toolchain/usr/share/java`. Si se usa ese ZIP, se puede construir sin descargarlas, sustituyendo el último argumento por `toolchain/usr/share/java`.

La carpeta privada debe contener `release.p12` y `key-password.txt` restaurados del ZIP de firma separado. **El constructor nunca genera una clave.** Falla expresamente si falta algún archivo o si el certificado no coincide con la firma de esta recuperación. Las contraseñas no se escriben en comandos, registros, código ni Git. El almacén debe estar fuera del checkout.

Salida: `android-build/Palabreo 1.20.apk`. El directorio de salida está excluido de Git. Para otra publicación aumentar `--version-code`; la versión visible se puede ajustar con `--version-name` (el empaquetador conservador admite cuatro caracteres ASCII, como `1.21`). La misma clave debe utilizarse siempre.

El constructor comprueba firmas v2/v3, CRC ZIP, contenido del asset, igualdad del DEX nativo, manifiesto y alineación de `resources.arsc`. Las entradas ZIP tienen fechas fijas: se ha comprobado que dos construcciones desde el mismo código, herramientas y respaldo de firma producen exactamente los mismos bytes. La aplicación del SQL no modifica el APK ni requiere volver a firmarlo.

## Firma nueva y recuperación

Huella pública SHA-256 nueva:
`8d1b1c337dfa5ba83e3f85e987d4785f5af9ad7f4ad1909c0b3dc431d67d3b5e`.

No es la firma antigua de 1.19. Para la primera instalación hay que desinstalar la APK antigua; esto elimina sus estadísticas y sesión locales. **No borrar la cuenta de Supabase**: las cuentas y los datos online permanecen en el servidor. Después se podrá volver a iniciar sesión. No se ha desinstalado nada desde este entorno.

`Palabreo-respaldo-privado-firma.zip` se entrega APARTE del código y no se sube a GitHub. Contiene la clave, su contraseña y las instrucciones. Guardar dos copias fuera del entorno en ubicaciones privadas. El ZIP contiene también la contraseña y no está cifrado externamente; tratarlo como un secreto completo.

## Verificación y límites

- `validation/` conserva resultados de pruebas y hashes; el archivo de firma detallado se genera al construir en `android-build/`.
- El juego web se prueba en Chromium en móvil simulado, sin conectar con servicios reales.
- El backend se prueba en PostgreSQL 17 local con datos ficticios y metadatos suministrados por el usuario, no contra Supabase real.
- No hay dispositivo ni emulador Android disponible. Quedan por comprobar instalación, permisos, inicio de sesión real, WebView del teléfono, compartir con otras aplicaciones, notificaciones y recordatorios con la pantalla apagada/reinicio. El DEX de recordatorios se conserva byte por byte; esto no sustituye esa prueba real.
