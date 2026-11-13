# Migraciones
- 0001_init.sql: modelo de datos base (copia en el proyecto WEEKLY DIET: sprint1/0001_init.sql). Aplicada el 12/11/2026.
- 0002_private_helper_functions.sql: funciones auxiliares de RLS movidas al esquema privado. Aplicada el 12/11/2026.
- 0003_terms_marketing_google_name.sql: aceptación de términos y marketing con fecha del servidor; nombre tomado de Google. Comprobación: `supabase/tests/0003_terms_check.sql` (8 × OK). Pendiente de aplicar.
- 0004_goals_safety_food_groups.sql: mayoría de edad, objetivo + modificadores, resultado del cribado de seguridad (health_screening, dato de salud) y grupos de alimentos de las recetas. Comprobación: `supabase/tests/0004_check.sql` (16 × OK). Pendiente de aplicar (después de 0003).
