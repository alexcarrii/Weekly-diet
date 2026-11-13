-- =====================================================================
-- WEEKLY DIET · Comprobación de la migración 0001 (RLS + RGPD)
-- Ejecutar en: Supabase > SQL Editor > New query > Run
-- Crea 2 usuarios de prueba (Ana y Beto), simula sus sesiones y comprueba
-- que cada uno solo ve lo suyo. Al final borra los usuarios de prueba:
-- no deja datos en tu base (y si algo falla, Supabase deshace todo el lote).
-- Resultado esperado: una tabla con 14 filas en "OK".
-- Si algo falla verás un error "FALLO N: ..." indicando qué comprobación.
-- =====================================================================
reset role;
delete from auth.users where id in ('11111111-1111-1111-1111-111111111111',
                                    '22222222-2222-2222-2222-222222222222');
drop table if exists _results;
create temp table _results (n serial, check_name text, result text);
grant all on _results to authenticated, anon;
grant usage on sequence _results_n_seq to authenticated, anon;

-- Dos usuarios de prueba (el trigger les crea perfil y preferencias)
insert into auth.users (id, email, raw_user_meta_data)
values ('11111111-1111-1111-1111-111111111111', 'ana.test@example.com',  '{"display_name":"Ana"}'),
       ('22222222-2222-2222-2222-222222222222', 'beto.test@example.com', '{"display_name":"Beto"}');

-- ---------- Sesión de ANA ----------
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', false);
set role authenticated;

do $$
declare v_menu uuid; v_list uuid; v_cnt int;
begin
  -- 1. El trigger creó perfil y preferencias
  select count(*) into v_cnt from public.profiles;
  if v_cnt <> 1 then raise exception 'FALLO 1: Ana debería ver 1 perfil y ve %', v_cnt; end if;
  insert into _results(check_name, result) values ('1. Perfil creado al registrarse y visible solo el propio', 'OK');

  update public.preferences
     set household_size = 3, weekly_budget_eur = 90, diets = '{mediterranean}', goal = 'eat_healthier',
         preferred_ingredients = '{garbanzos,salmón}', favorite_dishes = '{lentejas,tortilla}';
  insert into _results(check_name, result) values ('2. Ana edita sus preferencias', 'OK');

  -- 3. Sin consentimiento NO puede guardar alergias
  begin
    insert into public.user_allergies (user_id, allergen_code)
    values ('11111111-1111-1111-1111-111111111111', 'peanuts');
    raise exception 'FALLO 3: se guardó una alergia sin consentimiento';
  exception when insufficient_privilege then
    insert into _results(check_name, result) values ('3. Alergia SIN consentimiento => bloqueada', 'OK');
  end;

  -- 4. Con consentimiento SÍ
  insert into public.health_consents (user_id, granted, policy_version)
  values ('11111111-1111-1111-1111-111111111111', true, 'v1.0');
  insert into public.user_allergies (user_id, allergen_code)
  values ('11111111-1111-1111-1111-111111111111', 'peanuts'),
         ('11111111-1111-1111-1111-111111111111', 'gluten');
  select count(*) into v_cnt from public.user_allergies;
  if v_cnt <> 2 then raise exception 'FALLO 4: esperaba 2 alergias, hay %', v_cnt; end if;
  insert into _results(check_name, result) values ('4. Alergias CON consentimiento => guardadas', 'OK');

  -- 5. Datos de inventario, menú, receta y lista
  insert into public.inventory_items (name, quantity, unit, location, expiry_date)
  values ('Yogur natural', 4, 'unit', 'fridge', current_date + 3);

  insert into public.recipes (title, servings) values ('Lentejas de Ana', 4);

  insert into public.weekly_menus (week_start, household_size)
  values (date_trunc('week', current_date)::date, 3) returning id into v_menu;
  insert into public.menu_items (menu_id, day_of_week, meal, servings)
  values (v_menu, 1, 'lunch', 3);

  insert into public.shopping_lists (menu_id) values (v_menu) returning id into v_list;
  insert into public.shopping_list_items (list_id, product_name, quantity, unit, aisle)
  values (v_list, 'Lentejas', 500, 'g', 'pantry');
  insert into _results(check_name, result) values ('5. Ana crea inventario, receta, menú y lista', 'OK');
end $$;

-- ---------- Sesión de BETO ----------
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', false);

do $$
declare v_cnt int; v_ana_menu uuid; v_ana_recipe uuid; v_beto_menu uuid;
begin
  -- 6. Beto no ve NADA de Ana
  select (select count(*) from public.profiles where id <> '22222222-2222-2222-2222-222222222222')
       + (select count(*) from public.preferences where user_id <> '22222222-2222-2222-2222-222222222222')
       + (select count(*) from public.user_allergies)
       + (select count(*) from public.health_consents)
       + (select count(*) from public.health_consent_events)
       + (select count(*) from public.inventory_items)
       + (select count(*) from public.recipes)
       + (select count(*) from public.weekly_menus)
       + (select count(*) from public.menu_items)
       + (select count(*) from public.shopping_lists)
       + (select count(*) from public.shopping_list_items)
    into v_cnt;
  if v_cnt <> 0 then raise exception 'FALLO 6: Beto ve % filas de Ana', v_cnt; end if;
  insert into _results(check_name, result) values ('6. Beto no ve ningún dato de Ana (11 tablas)', 'OK');

  -- 7. Beto no puede modificar ni borrar datos de Ana (0 filas afectadas)
  update public.inventory_items set quantity = 0;
  delete from public.shopping_list_items;
  insert into _results(check_name, result) values ('7. Beto intenta editar/borrar lo de Ana (se comprueba abajo)', 'OK');

  -- 8. Beto no puede insertar filas a nombre de Ana
  begin
    insert into public.inventory_items (user_id, name)
    values ('11111111-1111-1111-1111-111111111111', 'Intruso');
    raise exception 'FALLO 8: Beto insertó a nombre de Ana';
  exception when insufficient_privilege then
    insert into _results(check_name, result) values ('8. Beto no puede escribir a nombre de Ana', 'OK');
  end;

  -- 9. Beto no puede colgar elementos en el menú de Ana aunque adivine su id
  reset role;
  select id into v_ana_menu from public.weekly_menus where user_id = '11111111-1111-1111-1111-111111111111';
  select id into v_ana_recipe from public.recipes where owner_id = '11111111-1111-1111-1111-111111111111';
  set role authenticated;
  begin
    insert into public.menu_items (menu_id, day_of_week, meal) values (v_ana_menu, 2, 'dinner');
    raise exception 'FALLO 9: Beto añadió un plato al menú de Ana';
  exception when foreign_key_violation then
    insert into _results(check_name, result) values ('9. Beto no puede usar el menú de Ana (FK compuesta)', 'OK');
  end;

  -- 10. Beto no puede usar la receta privada de Ana en su propio menú
  insert into public.weekly_menus (week_start) values (date_trunc('week', current_date)::date)
  returning id into v_beto_menu;
  begin
    insert into public.menu_items (menu_id, day_of_week, meal, recipe_id)
    values (v_beto_menu, 1, 'dinner', v_ana_recipe);
    raise exception 'FALLO 10: Beto usó la receta privada de Ana';
  exception when insufficient_privilege then
    insert into _results(check_name, result) values ('10. Beto no puede usar recetas privadas de Ana', 'OK');
  end;
end $$;

-- ---------- Vuelta a ANA: retirada del consentimiento ----------
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', false);

do $$
declare v_cnt int;
begin
  -- Confirma que lo que Beto intentó en el paso 7 no tuvo efecto
  select count(*) into v_cnt from public.inventory_items where quantity = 4;
  if v_cnt <> 1 then raise exception 'FALLO 7: el inventario de Ana fue modificado'; end if;
  select count(*) into v_cnt from public.shopping_list_items;
  if v_cnt <> 1 then raise exception 'FALLO 7: la lista de Ana fue borrada'; end if;

  -- 11. Retirar consentimiento borra las alergias y queda auditado
  update public.health_consents set granted = false;
  select count(*) into v_cnt from public.user_allergies;
  if v_cnt <> 0 then raise exception 'FALLO 11: siguen % alergias tras retirar el consentimiento', v_cnt; end if;
  select count(*) into v_cnt from public.health_consent_events;
  if v_cnt <> 2 then raise exception 'FALLO 11: esperaba 2 eventos de consentimiento, hay %', v_cnt; end if;
  insert into _results(check_name, result) values ('11. Retirar consentimiento => alergias borradas + auditado', 'OK');

  -- 12. El usuario no puede falsear el registro de auditoría
  begin
    insert into public.health_consent_events (user_id, action, policy_version)
    values ('11111111-1111-1111-1111-111111111111', 'granted', 'fake');
    raise exception 'FALLO 12: se pudo escribir en la auditoría';
  exception when insufficient_privilege then
    insert into _results(check_name, result) values ('12. Auditoría de consentimiento de solo lectura', 'OK');
  end;
end $$;

-- ---------- Sin sesión (anon) ----------
reset role;
select set_config('request.jwt.claims', '', false);
set role anon;
do $$
begin
  perform 1 from public.preferences limit 1;
  raise exception 'FALLO 13: un usuario sin sesión puede leer preferencias';
exception when insufficient_privilege then
  insert into _results(check_name, result) values ('13. Sin sesión no se puede leer nada', 'OK');
end $$;

-- ---------- 14. RLS activado en TODAS las tablas de public ----------
reset role;
do $$
declare v_missing text;
begin
  select string_agg(c.relname, ', ') into v_missing
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if v_missing is not null then raise exception 'FALLO 14: tablas sin RLS: %', v_missing; end if;
  insert into _results(check_name, result) values ('14. RLS activado en todas las tablas', 'OK');
end $$;

-- ---------- Limpieza: borra los usuarios de prueba (y en cascada todos sus datos) ----------
select set_config('request.jwt.claims', '', false);
delete from auth.users where id in ('11111111-1111-1111-1111-111111111111',
                                    '22222222-2222-2222-2222-222222222222');

select check_name as "Comprobación", result as "Resultado" from _results order by n;
