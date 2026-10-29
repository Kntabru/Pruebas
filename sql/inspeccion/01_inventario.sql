-- BLOQUE 1. Solo metadatos. No lee datos de la aplicación ni hace cambios.
-- Ejecutar en SQL Editor y devolver el resultado completo de esta única consulta.
SELECT 'esquema' AS tipo, n.nspname AS esquema, n.nspname AS objeto,
       NULL::text AS detalle
FROM pg_catalog.pg_namespace n
WHERE n.nspname IN ('public', 'palabreo_private')
UNION ALL
SELECT CASE c.relkind WHEN 'r' THEN 'tabla' WHEN 'p' THEN 'tabla_particionada'
       WHEN 'v' THEN 'vista' WHEN 'm' THEN 'vista_materializada'
       WHEN 'S' THEN 'secuencia' WHEN 'f' THEN 'tabla_externa' END,
       n.nspname, c.relname,
       'RLS=' || c.relrowsecurity::text || '; FORCE_RLS=' || c.relforcerowsecurity::text
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('public','palabreo_private') AND c.relkind IN ('r','p','v','m','S','f')
UNION ALL
SELECT CASE p.prokind WHEN 'p' THEN 'procedimiento' ELSE 'funcion' END,
       n.nspname, p.proname,
       pg_catalog.pg_get_function_identity_arguments(p.oid)
FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname IN ('public','palabreo_private') AND p.prokind IN ('f','p')
ORDER BY esquema,tipo,objeto,detalle;
