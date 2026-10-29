-- BLOQUE 3. Solo metadatos de RLS, propietarios, permisos y disparadores.
SELECT 'politica_rls' AS tipo,schemaname AS esquema,tablename AS objeto,
 jsonb_build_object('nombre',policyname,'permisiva',permissive,'roles',roles,'comando',cmd,'using',qual,'with_check',with_check) AS detalle
FROM pg_catalog.pg_policies WHERE schemaname IN ('public','palabreo_private')
UNION ALL
SELECT 'permisos_esquema',n.nspname,n.nspname,jsonb_build_object('propietario',pg_catalog.pg_get_userbyid(n.nspowner),'acl',n.nspacl::text)
FROM pg_catalog.pg_namespace n WHERE n.nspname IN ('public','palabreo_private')
UNION ALL
SELECT 'permisos_objeto',n.nspname,c.relname,jsonb_build_object('propietario',pg_catalog.pg_get_userbyid(c.relowner),'acl',c.relacl::text,'rls',c.relrowsecurity,'rls_forzada',c.relforcerowsecurity)
FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('public','palabreo_private') AND c.relkind IN ('r','p','v','m','S')
UNION ALL
SELECT 'permisos_predeterminados',n.nspname,pg_catalog.pg_get_userbyid(d.defaclrole),jsonb_build_object('tipo',d.defaclobjtype,'acl',d.defaclacl::text)
FROM pg_catalog.pg_default_acl d JOIN pg_catalog.pg_namespace n ON n.oid=d.defaclnamespace
WHERE n.nspname IN ('public','palabreo_private')
UNION ALL
SELECT 'trigger',n.nspname,c.relname,jsonb_build_object('nombre',t.tgname,'habilitado',t.tgenabled,'definicion',pg_catalog.pg_get_triggerdef(t.oid,true))
FROM pg_catalog.pg_trigger t JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('public','palabreo_private') AND NOT t.tgisinternal
ORDER BY esquema,objeto,tipo;
