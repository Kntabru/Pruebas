-- BLOQUE 2. Solo metadatos de columnas, restricciones e índices. No consulta filas.
-- Cada fila agrupa el detalle en JSON; no ejecuta expresiones default ni funciones.
SELECT 'columna' AS tipo, n.nspname AS esquema, c.relname AS objeto,
 jsonb_build_object('posicion',a.attnum,'columna',a.attname,'tipo',pg_catalog.format_type(a.atttypid,a.atttypmod),
 'not_null',a.attnotnull,'default',pg_catalog.pg_get_expr(d.adbin,d.adrelid),
 'identidad',a.attidentity,'generada',a.attgenerated) AS detalle
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON c.oid=a.attrelid
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
LEFT JOIN pg_catalog.pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
WHERE n.nspname IN ('public','palabreo_private') AND c.relkind IN ('r','p','v','m')
AND a.attnum>0 AND NOT a.attisdropped
UNION ALL
SELECT 'restriccion',n.nspname,c.relname,
 jsonb_build_object('nombre',co.conname,'tipo',co.contype,'definicion',pg_catalog.pg_get_constraintdef(co.oid,true),'validada',co.convalidated)
FROM pg_catalog.pg_constraint co
JOIN pg_catalog.pg_class c ON c.oid=co.conrelid
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('public','palabreo_private')
UNION ALL
SELECT 'indice',schemaname,tablename,jsonb_build_object('nombre',indexname,'definicion',indexdef)
FROM pg_catalog.pg_indexes WHERE schemaname IN ('public','palabreo_private')
ORDER BY esquema,objeto,tipo,detalle::text;
