-- =====================================================================
-- WEEKLY DIET · Migración 0003 · Registro "bonito" del diseñador (Sprint 1)
-- - Guarda la aceptación de Términos/Privacidad (versión + fecha puesta por el servidor)
-- - Guarda el consentimiento opcional de marketing (con fecha de cada cambio)
-- - Toma el nombre de Google (full_name / name) al registrarse con Google
-- Requiere 0001 y 0002 aplicadas. No toca ningún dato existente:
-- los usuarios ya creados verán la pantalla "Aceptar términos" en su próximo acceso.
-- =====================================================================

alter table public.profiles
  add column if not exists terms_version        text check (char_length(terms_version) between 1 and 20),
  add column if not exists terms_accepted_at    timestamptz,
  add column if not exists marketing_opt_in     boolean not null default false,
  add column if not exists marketing_updated_at timestamptz;

comment on column public.profiles.terms_version is 'Versión de Términos y Privacidad aceptada. NULL = aún no aceptados (la app muestra la pantalla A3).';
comment on column public.profiles.terms_accepted_at is 'Fecha de aceptación. La pone el servidor; el móvil no puede falsearla.';
comment on column public.profiles.marketing_opt_in is 'Consentimiento opcional para recibir ideas y ofertas por email.';

-- Fechas de aceptación y de marketing puestas siempre por el servidor
create or replace function public.profiles_stamp_consents()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.terms_accepted_at    := case when new.terms_version is not null then now() end;
    new.marketing_updated_at := case when new.marketing_opt_in then now() end;
    return new;
  end if;

  -- Términos: no se pueden "des-aceptar" (para eso está borrar la cuenta)
  if new.terms_version is null and old.terms_version is not null then
    new.terms_version := old.terms_version;
  end if;
  if new.terms_version is distinct from old.terms_version then
    new.terms_accepted_at := now();
  else
    new.terms_accepted_at := old.terms_accepted_at;
  end if;

  -- Marketing: se puede activar y desactivar; se registra la fecha del último cambio
  if new.marketing_opt_in is distinct from old.marketing_opt_in then
    new.marketing_updated_at := now();
  else
    new.marketing_updated_at := old.marketing_updated_at;
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_stamp_consents on public.profiles;
create trigger profiles_stamp_consents before insert or update on public.profiles
  for each row execute function public.profiles_stamp_consents();

revoke execute on function public.profiles_stamp_consents() from public, anon, authenticated;

-- Alta de usuario: perfil + preferencias, ahora con nombre de Google y términos/marketing del registro por email
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.profiles (id, display_name, terms_version, marketing_opt_in)
  values (
    new.id,
    left(nullif(trim(coalesce(v_meta ->> 'display_name', v_meta ->> 'full_name', v_meta ->> 'name', '')), ''), 60),
    nullif(left(v_meta ->> 'terms_version', 20), ''),
    coalesce((v_meta ->> 'marketing_opt_in')::boolean, false)
  );
  insert into public.preferences (user_id) values (new.id);
  return new;
exception
  when invalid_text_representation then
    -- marketing_opt_in con un valor no booleano: se ignora en lugar de impedir el registro
    insert into public.profiles (id, display_name, terms_version)
    values (
      new.id,
      left(nullif(trim(coalesce(v_meta ->> 'display_name', v_meta ->> 'full_name', v_meta ->> 'name', '')), ''), 60),
      nullif(left(v_meta ->> 'terms_version', 20), '')
    );
    insert into public.preferences (user_id) values (new.id);
    return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Fin de la migración 0003
