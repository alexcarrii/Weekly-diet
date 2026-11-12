-- WEEKLY DIET · Migración 0002 (aplicada el 12/11/2026)
-- Mueve las funciones auxiliares de RLS a un esquema no expuesto por la API.
-- Las políticas las referencian por OID, así que siguen funcionando sin cambios.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

alter function public.has_health_consent() set schema private;
alter function public.can_read_recipe(uuid) set schema private;
alter function public.owns_recipe(uuid) set schema private;

revoke execute on function private.has_health_consent() from public, anon;
revoke execute on function private.can_read_recipe(uuid) from public, anon;
revoke execute on function private.owns_recipe(uuid) from public, anon;
grant execute on function private.has_health_consent() to authenticated;
grant execute on function private.can_read_recipe(uuid) to authenticated;
grant execute on function private.owns_recipe(uuid) to authenticated;
