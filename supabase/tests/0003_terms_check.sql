-- =====================================================================
-- WEEKLY DIET · Comprobación de la migración 0003
-- Ejecutar en Supabase > SQL Editor después de aplicar 0003.
-- Resultado esperado: tabla con 8 filas en "OK". No deja datos.
-- =====================================================================
reset role;
delete from auth.users where id in ('33333333-3333-3333-3333-333333333333',
                                    '44444444-4444-4444-4444-444444444444',
                                    '55555555-5555-5555-5555-555555555555');
drop table if exists _results3;
create temp table _results3 (n serial, check_name text, result text);
grant all on _results3 to authenticated;
grant usage on sequence _results3_n_seq to authenticated;

-- Registro por email (la app envía terms_version y marketing en los metadatos)
insert into auth.users (id, email, raw_user_meta_data) values
  ('33333333-3333-3333-3333-333333333333', 'email.test@example.com',
   '{"terms_version":"v1.0","marketing_opt_in":true}'),
-- Registro con Google (Google envía full_name; sin términos todavía)
  ('44444444-4444-4444-4444-444444444444', 'google.test@example.com',
   '{"full_name":"Laura García","name":"Laura García"}'),
-- Metadatos raros: no deben impedir el registro
  ('55555555-5555-5555-5555-555555555555', 'raro.test@example.com',
   '{"marketing_opt_in":"quizas"}');

do $$
declare r record;
begin
  select * into r from public.profiles where id = '33333333-3333-3333-3333-333333333333';
  if r.terms_version <> 'v1.0' or r.terms_accepted_at is null or not r.marketing_opt_in or r.marketing_updated_at is null then
    raise exception 'FALLO 1: registro por email no guarda términos/marketing';
  end if;
  insert into _results3(check_name, result) values ('1. Email: términos y marketing guardados con fecha', 'OK');

  select * into r from public.profiles where id = '44444444-4444-4444-4444-444444444444';
  if r.display_name <> 'Laura García' or r.terms_version is not null or r.terms_accepted_at is not null or r.marketing_opt_in then
    raise exception 'FALLO 2: registro con Google incorrecto';
  end if;
  insert into _results3(check_name, result) values ('2. Google: nombre tomado de Google y términos pendientes', 'OK');

  select * into r from public.profiles where id = '55555555-5555-5555-5555-555555555555';
  if r is null or r.marketing_opt_in then raise exception 'FALLO 3: metadatos raros rompen el registro'; end if;
  if not exists (select 1 from public.preferences where user_id = '55555555-5555-5555-5555-555555555555') then
    raise exception 'FALLO 3: faltan preferencias';
  end if;
  insert into _results3(check_name, result) values ('3. Metadatos inválidos no impiden registrarse', 'OK');
end $$;

-- Sesión del usuario de Google: acepta términos en la hoja A3
select set_config('request.jwt.claims',
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', false);
set role authenticated;

do $$
declare r record;
begin
  update public.profiles
     set terms_version = 'v1.0', marketing_opt_in = false,
         terms_accepted_at = '2000-01-01'          -- intento de falsear la fecha
   where id = '44444444-4444-4444-4444-444444444444';
  select * into r from public.profiles;
  if r.terms_version <> 'v1.0' or r.terms_accepted_at < now() - interval '1 minute' then
    raise exception 'FALLO 4: la fecha de aceptación no la pone el servidor';
  end if;
  insert into _results3(check_name, result) values ('4. Aceptar términos: fecha puesta por el servidor', 'OK');

  update public.profiles set terms_version = null;
  select * into r from public.profiles;
  if r.terms_version is null then raise exception 'FALLO 5: se pudieron des-aceptar los términos'; end if;
  insert into _results3(check_name, result) values ('5. No se pueden des-aceptar los términos', 'OK');

  update public.profiles set marketing_opt_in = true;
  select * into r from public.profiles;
  if not r.marketing_opt_in or r.marketing_updated_at is null then raise exception 'FALLO 6: marketing'; end if;
  insert into _results3(check_name, result) values ('6. Activar marketing registra la fecha', 'OK');

  update public.profiles set onboarding_completed = true, display_name = 'Laura';
  select * into r from public.profiles;
  if not r.onboarding_completed then raise exception 'FALLO 7: no se guarda el fin del onboarding'; end if;
  insert into _results3(check_name, result) values ('7. Fin del onboarding guardado', 'OK');

  if (select count(*) from public.profiles) <> 1 then raise exception 'FALLO 8: ve perfiles ajenos'; end if;
  insert into _results3(check_name, result) values ('8. Sigue viendo solo su perfil (RLS)', 'OK');
end $$;

reset role;
select set_config('request.jwt.claims', '', false);
delete from auth.users where id in ('33333333-3333-3333-3333-333333333333',
                                    '44444444-4444-4444-4444-444444444444',
                                    '55555555-5555-5555-5555-555555555555');

select check_name as "Comprobación", result as "Resultado" from _results3 order by n;
