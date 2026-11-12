# WEEKLY DIET

App para planificar menús semanales según presupuesto, objetivo y lo que hay en la nevera, y generar la lista de la compra.

## Estado (Sprint 1)
- Base de datos en Supabase (proyecto `weekly-diet`, región UE). Migraciones en `supabase/migrations/`.
- App Flutter mínima: registro, inicio de sesión, recuperar contraseña y pantalla de prueba de conexión.

## Cómo se obtiene la app
No hace falta instalar nada. Cada cambio en `main` compila automáticamente la app de Android en GitHub Actions
(pestaña **Actions → Build Android APK → weekly-diet-apk**). Ese archivo `.apk` se instala en el móvil Android.

## Seguridad
- La URL y la clave pública (anon) están en el workflow: son públicas por diseño; la protección la da el RLS.
- La clave secreta (service_role) nunca va en la app ni en este repositorio.
- Cada cambio de base de datos va en una migración nueva (`0003_...`), nunca editando una ya aplicada.
