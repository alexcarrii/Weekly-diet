-- =====================================================================
-- WEEKLY DIET · Migración 0004 · Objetivos, cribado de seguridad y grupos de alimentos
-- Historias: sprint1/historias-reglas-seguridad.md · Reglas: sprint1/reglas-nutricionales-y-seguridad.md
--   HU-1  Mayoría de edad confirmada (profiles.is_adult_confirmed, fecha del servidor)
--   HU-2  Objetivo nutricional + modificadores (goal / goal_modifiers / confirmed_physical_activity)
--   HU-3  Cribado de seguridad: solo se guarda el RESULTADO (health_screening), nunca las respuestas
--   HU-5  Recetas etiquetadas por grupos de alimentos (food_groups, recipe_food_groups)
--   HU-7  Lactosa separada de la leche: no requiere cambios aquí (el catálogo ya tiene 'lactose')
-- Requiere 0001, 0002 y 0003 aplicadas. Pensada para ejecutarse UNA vez.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. HU-1 · Mayoría de edad y versión del cribado que se ha mostrado
--    (ninguno de los dos es dato de salud)
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists is_adult_confirmed       boolean not null default false,
  add column if not exists adult_confirmed_at       timestamptz,
  add column if not exists safety_screening_version text check (char_length(safety_screening_version) between 1 and 20);

comment on column public.profiles.is_adult_confirmed is
  'El usuario confirmó tener 18 años o más (casilla en A2/A3). No se pide la fecha de nacimiento.';
comment on column public.profiles.safety_screening_version is
  'Versión del cribado de seguridad que el usuario ya ha respondido. NO indica el resultado (eso es dato de salud y vive en health_screening).';

-- La fecha la pone el servidor y la confirmación no se puede deshacer
create or replace function public.profiles_stamp_adult()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.adult_confirmed_at := case when new.is_adult_confirmed then now() end;
    return new;
  end if;
  if old.is_adult_confirmed and not new.is_adult_confirmed then
    new.is_adult_confirmed := true;
  end if;
  if new.is_adult_confirmed and not old.is_adult_confirmed then
    new.adult_confirmed_at := now();
  else
    new.adult_confirmed_at := old.adult_confirmed_at;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_stamp_adult on public.profiles;
create trigger profiles_stamp_adult before insert or update on public.profiles
  for each row execute function public.profiles_stamp_adult();
revoke execute on function public.profiles_stamp_adult() from public, anon, authenticated;

-- Alta de usuario: igual que en 0003 + mayoría de edad del registro por email.
-- Los booleanos de los metadatos se leen sin conversión: cualquier valor raro cuenta como false
-- y nunca impide el registro.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.profiles (id, display_name, terms_version, marketing_opt_in, is_adult_confirmed)
  values (
    new.id,
    left(nullif(trim(coalesce(v_meta ->> 'display_name', v_meta ->> 'full_name', v_meta ->> 'name', '')), ''), 60),
    nullif(left(v_meta ->> 'terms_version', 20), ''),
    coalesce(v_meta ->> 'marketing_opt_in', '') = 'true',
    coalesce(v_meta ->> 'adult_confirmed', '') = 'true'
  );
  insert into public.preferences (user_id) values (new.id);
  return new;
end;
$$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. HU-2 · Objetivo nutricional + modificadores
-- ---------------------------------------------------------------------
alter table public.preferences
  add column if not exists goal_modifiers              text[]  not null default '{}',
  add column if not exists confirmed_physical_activity boolean not null default false;

comment on column public.preferences.goal is
  'Objetivo nutricional: eat_healthier | maintain_weight | lose_weight | gain_muscle. lose_weight y gain_muscle solo con cribado "standard".';
comment on column public.preferences.goal_modifiers is
  'Modificadores opcionales y combinables: save_money, save_time.';
comment on column public.preferences.confirmed_physical_activity is
  'El usuario confirmó que hace actividad física de fuerza con regularidad (requisito de gain_muscle).';

-- Datos anteriores: ahorrar dinero/tiempo pasan a ser modificadores de "comer más sano"
update public.preferences
   set goal_modifiers = array[goal], goal = 'eat_healthier'
 where goal in ('save_money', 'save_time');

-- Nadie tiene todavía cribado: los objetivos y dietas que lo requieren se vacían
-- (el usuario los elegirá de nuevo tras responder el cribado).
update public.preferences
   set goal  = case when goal in ('lose_weight', 'gain_muscle') then null else goal end,
       diets = array_remove(array_remove(diets, 'low_carb'), 'high_protein')
 where goal in ('lose_weight', 'gain_muscle')
    or diets && array['low_carb', 'high_protein']::text[];

alter table public.preferences drop constraint if exists preferences_goal_check;
alter table public.preferences
  add constraint preferences_goal_check
    check (goal in ('eat_healthier', 'maintain_weight', 'lose_weight', 'gain_muscle')),
  add constraint preferences_goal_modifiers_check
    check (goal_modifiers <@ array['save_money', 'save_time']::text[]),
  add constraint preferences_gain_muscle_needs_activity
    check (goal is distinct from 'gain_muscle' or confirmed_physical_activity);

-- ---------------------------------------------------------------------
-- 3. HU-3 · Resultado del cribado de seguridad (DATO DE SALUD, RGPD art. 9)
--    Sin fila = modo general. Solo se puede escribir con consentimiento vigente.
-- ---------------------------------------------------------------------
create table public.health_screening (
  user_id            uuid primary key references public.profiles (id) on delete cascade,
  safety_mode        text not null check (safety_mode in ('standard', 'general')),
  safety_referral    text check (safety_referral in ('pregnancy', 'general')),
  screening_version  text not null check (char_length(screening_version) between 1 and 20),
  screened_at        timestamptz not null default now(),
  check ((safety_mode = 'standard') = (safety_referral is null))
);
comment on table public.health_screening is
  'DATO DE SALUD (RGPD art. 9). Solo el resultado del cribado S2–S6, nunca las respuestas. '
  'Sin fila = modo general. Se borra al retirar el consentimiento.';
comment on column public.health_screening.safety_referral is
  'pregnancy = aplicar exclusiones de embarazo/lactancia (SEC-05); general = resto de derivaciones.';

-- Fecha del cribado puesta por el servidor
create or replace function public.health_screening_stamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.screened_at := now();
  return new;
end;
$$;
create trigger health_screening_stamp before insert or update on public.health_screening
  for each row execute function public.health_screening_stamp();
revoke execute on function public.health_screening_stamp() from public, anon, authenticated;

-- Si el resultado deja de ser "standard" (o se borra), se quitan los objetivos y dietas
-- que lo requieren. Así la base de datos nunca queda en un estado inseguro.
create or replace function public.health_screening_after()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
  v_mode text;
begin
  if tg_op = 'DELETE' then
    v_user := old.user_id;
    v_mode := 'general';
  else
    v_user := new.user_id;
    v_mode := new.safety_mode;
  end if;
  if v_mode <> 'standard' then
    update public.preferences
       set goal  = case when goal in ('lose_weight', 'gain_muscle') then null else goal end,
           diets = array_remove(array_remove(diets, 'low_carb'), 'high_protein')
     where user_id = v_user
       and (goal in ('lose_weight', 'gain_muscle') or diets && array['low_carb', 'high_protein']::text[]);
  end if;
  return null;
end;
$$;
create trigger health_screening_after after insert or update or delete on public.health_screening
  for each row execute function public.health_screening_after();
revoke execute on function public.health_screening_after() from public, anon, authenticated;

-- Preferencias: perder peso, ganar músculo, low_carb y high_protein exigen cribado "standard"
create or replace function public.preferences_enforce_safety()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mode text;
begin
  if new.goal is distinct from 'gain_muscle' then
    new.confirmed_physical_activity := false;
  end if;

  if (tg_op = 'INSERT' or new.goal is distinct from old.goal or new.diets is distinct from old.diets)
     and (new.goal in ('lose_weight', 'gain_muscle') or new.diets && array['low_carb', 'high_protein']::text[]) then
    select s.safety_mode into v_mode from public.health_screening s where s.user_id = new.user_id;
    if coalesce(v_mode, 'general') <> 'standard' then
      raise exception 'goal_requires_safety_screening'
        using errcode = 'check_violation',
              hint = 'Perder peso, ganar músculo, low_carb y high_protein requieren el cribado de seguridad con resultado standard.';
    end if;
  end if;
  return new;
end;
$$;
create trigger preferences_enforce_safety before insert or update on public.preferences
  for each row execute function public.preferences_enforce_safety();
revoke execute on function public.preferences_enforce_safety() from public, anon, authenticated;

-- Consentimiento: igual que en 0001 + borrar el cribado al retirarlo
-- + auditar cuando cambia la versión del texto aceptado (v1.0 → v1.1).
create or replace function public.health_consents_after()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.granted and (tg_op = 'INSERT' or not old.granted) then
    insert into public.health_consent_events (user_id, action, policy_version)
    values (new.user_id, 'granted', new.policy_version);
  elsif tg_op = 'UPDATE' and old.granted and not new.granted then
    insert into public.health_consent_events (user_id, action, policy_version)
    values (new.user_id, 'revoked', new.policy_version);
    delete from public.user_allergies where user_id = new.user_id;
    delete from public.health_screening where user_id = new.user_id;
  elsif tg_op = 'UPDATE' and old.granted and new.granted and new.policy_version is distinct from old.policy_version then
    insert into public.health_consent_events (user_id, action, policy_version)
    values (new.user_id, 'granted', new.policy_version);
  end if;
  return new;
end;
$$;
revoke execute on function public.health_consents_after() from public, anon, authenticated;

-- RLS de health_screening (mismo patrón que user_allergies)
alter table public.health_screening enable row level security;

create policy "screening_select_own" on public.health_screening
  for select to authenticated using (user_id = (select auth.uid()));
create policy "screening_insert_own_with_consent" on public.health_screening
  for insert to authenticated
  with check (user_id = (select auth.uid()) and private.has_health_consent());
create policy "screening_update_own_with_consent" on public.health_screening
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and private.has_health_consent());
create policy "screening_delete_own" on public.health_screening
  for delete to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- 4. HU-5 · Grupos de alimentos y etiquetado de recetas
-- ---------------------------------------------------------------------
create table public.food_groups (
  code         text primary key,
  name_es      text not null,
  parent_code  text references public.food_groups (code)
);
comment on table public.food_groups is
  'Grupos de rules_v0.1 (sección 1.1). Los subgrupos (fish_oily, grains_whole) se etiquetan ADEMÁS del grupo padre.';

insert into public.food_groups (code, name_es, parent_code) values
  ('veg',            'Verduras y hortalizas',              null),
  ('fruit',          'Fruta fresca',                       null),
  ('legumes',        'Legumbres',                          null),
  ('fish',           'Pescado y marisco',                  null),
  ('fish_oily',      'Pescado azul',                       'fish'),
  ('eggs',           'Huevos (unidades)',                  null),
  ('meat_white',     'Ave y conejo',                       null),
  ('meat_red',       'Carne roja',                         null),
  ('meat_processed', 'Carne procesada',                    null),
  ('grains',         'Cereales',                           null),
  ('grains_whole',   'Cereales integrales',                'grains'),
  ('tubers',         'Patata y tubérculos',                null),
  ('dairy',          'Lácteos',                            null),
  ('nuts',           'Frutos secos y semillas',            null),
  ('oil',            'Aceite de oliva virgen extra',       null),
  ('ultraprocessed', 'Ultraprocesados',                    null)
on conflict (code) do nothing;

create table public.recipe_food_groups (
  recipe_id             uuid not null references public.recipes (id) on delete cascade,
  group_code            text not null references public.food_groups (code),
  servings_per_portion  numeric(4,2) not null check (servings_per_portion > 0 and servings_per_portion <= 10),
  primary key (recipe_id, group_code)
);
comment on table public.recipe_food_groups is
  'Raciones de cada grupo que aporta UNA porción de la receta (para una persona). Huevos en unidades.';

alter table public.recipes
  add column if not exists is_fried             boolean not null default false,
  add column if not exists is_ultraprocessed    boolean not null default false,
  add column if not exists allergens_reviewed   boolean not null default false,
  add column if not exists trace_allergen_codes text[]  not null default '{}',
  add column if not exists safety_tags          text[]  not null default '{}'
    check (safety_tags <@ array['raw_or_undercooked_animal', 'raw_milk_cheese', 'liver_or_pate',
                                'high_mercury_fish', 'alcohol']::text[]);

comment on column public.recipes.allergens_reviewed is
  'SEC-03: alérgenos revisados (por reglas o por el nutricionista). Sin revisar no se sirve a usuarios con alergias.';
comment on column public.recipes.trace_allergen_codes is
  'SEC-01: alérgenos que "puede contener" (trazas). Excluyen la receta igual que allergen_codes.';
comment on column public.recipes.safety_tags is
  'SEC-05: marcas para exclusiones de embarazo y lactancia.';

alter table public.food_groups        enable row level security;
alter table public.recipe_food_groups enable row level security;

create policy "food_groups_read" on public.food_groups
  for select to authenticated using (true);
create policy "recipe_food_groups_select" on public.recipe_food_groups
  for select to authenticated using (private.can_read_recipe(recipe_id));
create policy "recipe_food_groups_write_own" on public.recipe_food_groups
  for all to authenticated
  using (private.owns_recipe(recipe_id))
  with check (private.owns_recipe(recipe_id));

-- ---------------------------------------------------------------------
-- 5. Permisos: los anónimos no tocan las tablas nuevas
-- ---------------------------------------------------------------------
revoke all on public.health_screening   from anon;
revoke all on public.food_groups        from anon;
revoke all on public.recipe_food_groups from anon;

-- Fin de la migración 0004
