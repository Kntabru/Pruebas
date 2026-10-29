# Pruebas

El juego no necesita dependencias JavaScript. Las pruebas de navegador requieren Python, Playwright (`requirements.txt`) y Chromium en `/usr/bin/chromium`:

```sh
python tools/build_html.py
python tests/smoke.py
python tests/lengths.py
```

Bloquean peticiones externas. Cubren el asset único y los archivos editables. En entornos restringidos puede ser necesario permitir procesos de Chromium y sockets de servidor local.

## Servidor local de prueba

**NO EJECUTAR `tests/local_fixture.sql` EN SUPABASE.** Contiene únicamente el montaje destructible de una base de pruebas con roles y usuarios inventados, no la actualización del servidor.

Se usó PostgreSQL 17.11 extraído de los paquetes Debian en `/workspace/server-validation/postgresql`, con base `palabreo_test`, usuario local `agent` y socket privado `/workspace/server-validation/socket`; no escucha por TCP. Los scripts de pruebas del servidor fijan esos destinos y no aceptan URL ni credenciales de un servidor remoto.

1. Crear un clúster PostgreSQL local nuevo con `initdb`, UTF-8 y autenticación local de pruebas; iniciarlo solo con socket local y `listen_addresses=''`.
2. Crear la base vacía `palabreo_test`.
3. Ejecutar `python tests/make_server_fixture.py` para generar el montaje a partir de los metadatos suministrados y funciones observadas.
4. Cargar `tests/local_fixture.sql` en esa base LOCAL mediante psql, con `ON_ERROR_STOP=1`.
5. Ejecutar `python tests/server_migration.py`. Aplica la migración en la base ficticia y prueba el comportamiento y conservación de datos.
6. Ejecutar `python tests/competitions_browser.py`. El navegador intercepta las llamadas HTTP y traduce las RPC de juego a esa base local; las respuestas de autenticación, perfil y actividad social se simulan. Ninguna petición sale a Supabase.

No reutilizar el montaje en una base con datos que se quieran conservar. Para repetir la migración, preparar otra base local vacía; su segunda aplicación se rechaza expresamente. Detener el clúster local cuando se termine.

Las pruebas no sustituyen la verificación del teléfono ni del Supabase real. En `validation/` se conservan sus resultados. Los metadatos corresponden solo a objetos de Palabreo; no contienen filas del servidor. Los auxiliares no modificados de pertenencia y semana, así como auth.uid, se modelan localmente; no constituyen un volcado integral de Supabase.
