-- =====================================================================
-- WEEKLY DIET · Comprobación de la migración 0004
-- Ejecutar en Supabase > SQL Editor después de aplicar 0004.
-- Resultado esperado: tabla con 16 filas en "OK". No deja datos.
-- Si algo falla verás "FALLO N: ..." con la comprobación que no pasa.
-- =====================================================================
reset role;
select set_config('request.jwt.claims', '', false);
delete from auth.users where id in ('66666666-6666-6666-6666-666666666666',
                                    '77777777-7777-7777-7777-777777777777',
                                    '88888888-8888-8888-8888-888888888888');
delete from public.recipes where title = '__test_0004_catalogo__';
drop table if exists _results4;
create temp table _results4 (n serial, check_name text, result text);
grant all on _results4 to authenticated, anon;
grant usage on sequence _results4_n_seq to authenticated, anon;

insert into auth.users (id, email, raw_user_meta_data) values
  -- Registro por email: la app envía términos y mayoría de edad
  ('66666666-6666-6666-6666-666666666666', 'eva.test@example.com',
   '{"display_name":"Eva","terms_version":"v1.0","adult_confirmed":true}'),
  -- Registro con Google: sin términos ni mayoría de edad todavía
  ('77777777-7777-7777-7777-777777777777', 'gus.test@example.com', '{"full_name":"Gus"}'),
  -- Metadatos raros: no deben impedir el registro
  ('88888888-8888-8888-8888-888888888888', 'raro4.test@example.com',
   '{"marketing_opt_in":"quizas","adult_confirmed":"puede"}');

-- Receta de catálogo (sin dueño) para las pruebas de etiquetado
insert into public.recipes (owner_id, title, source) values (null, '__test_0004_catalogo__', 'catalog');
insert into public.recipe_food_groups (recipe_id, group_code, servings_per_portion)
select id, 'legumes', 1 from public.recipes where title = '__test_0004_catalogo__';

do $$
declare r record;
begin
  select * into r from public.profiles where id = '66666666-6666-6666-6666-666666666666';
  if not r.is_adult_confirmed or r.adult_confirmed_at is null or r.terms_version <> 'v1.0' then
    raise exception 'FALLO 1: el registro por email no guarda la mayoría de edad';
  end if;
  select * into r from public.profiles where id = '77777777-7777-7777-7777-777777777777';
  if r.is_adult_confirmed or r.adult_confirmed_at is not null or r.display_name <> 'Gus' then
    raise exception 'FALLO 1: el registro con Google no debería confirmar la mayoría de edad';
  end if;
  insert into _results4(check_name, result) values ('1. Mayoría de edad: email la guarda, Google la deja pendiente', 'OK');

  select * into r from public.profiles where id = '88888888-8888-8888-8888-888888888888';
  if r is null or r.marketing_opt_in or r.is_adult_confirmed then
    raise exception 'FALLO 2: metadatos raros rompen el registro o se interpretan como true';
  end if;
  insert into _results4(check_name, result) values ('2. Metadatos inválidos no impiden registrarse', 'OK');
end $$;

-- ---------- Sesión de GUS (Google) ----------
select set_config('request.jwt.claims',
  '{"sub":"77777777-7777-7777-7777-777777777777","role":"authenticated"}', false);
set role authenticated;

do $$
declare r record;
begin
  update public.profiles set is_adult_confirmed = true, adult_confirmed_at = '2000-01-01';
  select * into r from public.profiles;
  if not r.is_adult_confirmed or r.adult_confirmed_at < now() - interval '1 minute' then
    raise exception 'FALLO 3: la fecha de mayoría de edad no la pone el servidor';
  end if;
  update public.profiles set is_adult_confirmed = false;
  select * into r from public.profiles;
  if not r.is_adult_confirmed then raise exception 'FALLO 3: se pudo deshacer la mayoría de edad'; end if;
  insert into _results4(check_name, result) values ('3. Mayoría de edad: fecha del servidor y no se puede deshacer', 'OK');

  -- 4. Objetivos y modificadores
  begin
    update public.preferences set goal = 'save_money';
    raise exception 'FALLO 4: save_money se acepta todavía como objetivo';
  exception when check_violation then null;
  end;
  begin
    update public.preferences set goal_modifiers = '{save_money,regalar}';
    raise exception 'FALLO 4: se acepta un modificador desconocido';
  exception when check_violation then null;
  end;
  update public.preferences set goal = 'eat_healthier', goal_modifiers = '{save_money,save_time}';
  insert into _results4(check_name, result) values ('4. goal solo nutricional; goal_modifiers save_money/save_time', 'OK');

  -- 5. Sin cribado: perder peso, ganar músculo y low_carb bloqueados
  begin
    update public.preferences set goal = 'lose_weight';
    raise exception 'FALLO 5: lose_weight sin cribado';
  exception when check_violation then null;
  end;
  begin
    update public.preferences set diets = '{low_carb}';
    raise exception 'FALLO 5: low_carb sin cribado';
  exception when check_violation then null;
  end;
  insert into _results4(check_name, result) values ('5. Sin cribado no hay perder peso, ganar músculo ni low_carb', 'OK');

  -- 6. Sin consentimiento no se guarda el cribado
  begin
    insert into public.health_screening (user_id, safety_mode, screening_version)
    values ('77777777-7777-7777-7777-777777777777', 'standard', 's_v0.1');
    raise exception 'FALLO 6: se guardó el cribado sin consentimiento';
  exception when insufficient_privilege then null;
  end;
  insert into _results4(check_name, result) values ('6. Cribado SIN consentimiento => bloqueado', 'OK');

  -- 7. Con consentimiento: cribado standard (fecha del servidor) y objetivos permitidos
  insert into public.health_consents (user_id, granted, policy_version)
  values ('77777777-7777-7777-7777-777777777777', true, 'v1.1');
  insert into public.health_screening (user_id, safety_mode, screening_version, screened_at)
  values ('77777777-7777-7777-7777-777777777777', 'standard', 's_v0.1', '2000-01-01');
  select * into r from public.health_screening;
  if r.screened_at < now() - interval '1 minute' then raise exception 'FALLO 7: fecha del cribado falseable'; end if;
  update public.preferences set goal = 'lose_weight', diets = '{omnivore,low_carb}';
  insert into _results4(check_name, result) values ('7. Cribado standard con permiso => perder peso permitido', 'OK');

  -- 8. Ganar músculo exige confirmar actividad física; al cambiar de objetivo se limpia
  begin
    update public.preferences set goal = 'gain_muscle', confirmed_physical_activity = false;
    raise exception 'FALLO 8: gain_muscle sin actividad física';
  exception when check_violation then null;
  end;
  update public.preferences set goal = 'gain_muscle', confirmed_physical_activity = true;
  update public.preferences set goal = 'maintain_weight';
  select * into r from public.preferences;
  if r.confirmed_physical_activity then raise exception 'FALLO 8: la confirmación sigue tras cambiar de objetivo'; end if;
  insert into _results4(check_name, result) values ('8. Ganar músculo exige actividad física confirmada', 'OK');

  -- 9. Resultado coherente: standard no lleva derivación; general sí
  begin
    update public.health_screening set safety_referral = 'general';
    raise exception 'FALLO 9: standard con derivación';
  exception when check_violation then null;
  end;
  insert into _results4(check_name, result) values ('9. Resultado del cribado siempre coherente', 'OK');

  -- 10. Pasar a modo general (embarazo) quita objetivo de peso y dietas restringidas
  update public.preferences set goal = 'lose_weight', diets = '{omnivore,low_carb}';
  update public.health_screening set safety_mode = 'general', safety_referral = 'pregnancy';
  select * into r from public.preferences;
  if r.goal is not null or r.diets <> '{omnivore}' then
    raise exception 'FALLO 10: en modo general sigue goal=% diets=%', r.goal, r.diets;
  end if;
  insert into _results4(check_name, result) values ('10. Modo general => se quitan perder peso y low_carb', 'OK');

  -- 11. Retirar el consentimiento borra alergias y cribado, quita el objetivo y queda auditado
  update public.health_screening set safety_mode = 'standard', safety_referral = null;
  update public.preferences set goal = 'lose_weight';
  insert into public.user_allergies (user_id, allergen_code) values ('77777777-7777-7777-7777-777777777777', 'lactose');
  update public.health_consents set policy_version = 'v1.2';   -- cambio de versión: también se audita
  update public.health_consents set granted = false;
  if exists (select 1 from public.health_screening) or exists (select 1 from public.user_allergies) then
    raise exception 'FALLO 11: quedan datos de salud tras retirar el consentimiento';
  end if;
  select * into r from public.preferences;
  if r.goal is not null then raise exception 'FALLO 11: sigue el objetivo de peso sin cribado'; end if;
  if (select count(*) from public.health_consent_events) <> 3 then
    raise exception 'FALLO 11: esperaba 3 eventos (alta, cambio de versión, retirada), hay %',
      (select count(*) from public.health_consent_events);
  end if;
  insert into _results4(check_name, result) values ('11. Retirar permiso => borra alergias y cribado + auditado', 'OK');

  -- 12. Etiquetado de recetas: propias sí, catálogo solo lectura, grupos válidos
  insert into public.recipes (title) values ('Garbanzos de Gus');
  insert into public.recipe_food_groups (recipe_id, group_code, servings_per_portion)
  select id, g, 1 from public.recipes, unnest(array['legumes','veg']) g where title = 'Garbanzos de Gus';
  if (select count(*) from public.recipe_food_groups) <> 3 then
    raise exception 'FALLO 12: esperaba ver 2 etiquetas propias + 1 del catálogo';
  end if;
  begin
    insert into public.recipe_food_groups (recipe_id, group_code, servings_per_portion)
    select id, 'patatas_fritas', 1 from public.recipes where title = 'Garbanzos de Gus';
    raise exception 'FALLO 12: grupo inexistente aceptado';
  exception when foreign_key_violation then null;
  end;
  begin
    insert into public.recipe_food_groups (recipe_id, group_code, servings_per_portion)
    select id, 'veg', 1 from public.recipes where title = '__test_0004_catalogo__';
    raise exception 'FALLO 12: se pudo etiquetar una receta del catálogo';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.recipes set safety_tags = '{picante}' where title = 'Garbanzos de Gus';
    raise exception 'FALLO 12: safety_tag desconocida aceptada';
  exception when check_violation then null;
  end;
  insert into _results4(check_name, result) values ('12. Etiquetas de grupos: propias sí, catálogo solo lectura', 'OK');
end $$;

-- ---------- Sesión de EVA: no ve nada de Gus ----------
select set_config('request.jwt.claims',
  '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}', false);

do $$
begin
  if exists (select 1 from public.health_screening)
     or exists (select 1 from public.recipe_food_groups rfg join public.recipes r on r.id = rfg.recipe_id
                where r.title = 'Garbanzos de Gus')
     or (select count(*) from public.profiles) <> 1 then
    raise exception 'FALLO 13: Eva ve datos de Gus';
  end if;
  insert into _results4(check_name, result) values ('13. Eva no ve el cribado ni las recetas de Gus', 'OK');
end $$;

-- ---------- Sin sesión (anon) ----------
reset role;
select set_config('request.jwt.claims', '', false);
set role anon;
do $$
begin
  perform 1 from public.health_screening limit 1;
  raise exception 'FALLO 14: un usuario sin sesión puede leer el cribado';
exception when insufficient_privilege then
  insert into _results4(check_name, result) values ('14. Sin sesión no se puede leer el cribado', 'OK');
end $$;

-- ---------- RLS en todas las tablas y borrado de cuenta ----------
reset role;
do $$
declare v_missing text;
begin
  select string_agg(c.relname, ', ') into v_missing
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if v_missing is not null then raise exception 'FALLO 15: tablas sin RLS: %', v_missing; end if;
  insert into _results4(check_name, result) values ('15. RLS activado en todas las tablas', 'OK');
end $$;

-- Eva con cribado y objetivo de peso, para comprobar el borrado en cascada con todo relleno
insert into public.health_consents (user_id, granted, policy_version)
values ('66666666-6666-6666-6666-666666666666', true, 'v1.1');
insert into public.health_screening (user_id, safety_mode, screening_version)
values ('66666666-6666-6666-6666-666666666666', 'standard', 's_v0.1');
update public.preferences set goal = 'lose_weight' where user_id = '66666666-6666-6666-6666-666666666666';

delete from auth.users where id in ('66666666-6666-6666-6666-666666666666',
                                    '77777777-7777-7777-7777-777777777777',
                                    '88888888-8888-8888-8888-888888888888');
delete from public.recipes where title = '__test_0004_catalogo__';
do $$
begin
  if exists (select 1 from public.health_screening
             where user_id in ('66666666-6666-6666-6666-666666666666', '77777777-7777-7777-7777-777777777777'))
     or exists (select 1 from public.recipes where title in ('Garbanzos de Gus', '__test_0004_catalogo__')) then
    raise exception 'FALLO 16: el borrado de cuenta deja datos';
  end if;
  insert into _results4(check_name, result) values ('16. Borrar la cuenta borra todo sin errores', 'OK');
end $$;

select check_name as "Comprobación", result as "Resultado" from _results4 order by n;
