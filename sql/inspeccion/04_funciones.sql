-- BLOQUE 4. Solo metadatos/definiciones. NO invoca las funciones de la aplicación.
-- Antes de compartir: revisar si hay secretos escritos literalmente en el código.
-- Se pide un máximo de 10 funciones por bloque; después cambiar OFFSET 0 a 10, 20, etc.
SELECT n.nspname AS esquema,p.proname AS funcion,
 pg_catalog.pg_get_function_identity_arguments(p.oid) AS argumentos,
 pg_catalog.pg_get_function_result(p.oid) AS resultado,
 pg_catalog.pg_get_userbyid(p.proowner) AS propietario,
 l.lanname AS lenguaje,p.prosecdef AS security_definer,
 p.provolatile AS volatilidad,p.proconfig AS configuracion,p.proacl::text AS permisos,
 pg_catalog.pg_get_functiondef(p.oid) AS definicion
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
JOIN pg_catalog.pg_language l ON l.oid=p.prolang
WHERE n.nspname IN ('public','palabreo_private') AND p.prokind IN ('f','p')
ORDER BY n.nspname,p.proname,pg_catalog.pg_get_function_identity_arguments(p.oid)
LIMIT 10 OFFSET 0;
