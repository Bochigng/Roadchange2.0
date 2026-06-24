# Road Change Database Schema

Road Change uses Supabase Auth for identity and user-owned public tables for the transformation system.

Core domains:

- Identity: `profiles`, `settings`
- Planning: `goals`, `roadmaps`, `milestones`
- Focus: `focus_sessions`
- Progression: `xp_progress`, `streaks`, `evolution_metrics`
- Health: `health_logs`, `sleep_logs`
- Knowledge: `knowledge_entries`
- Reflection: `reflections`, `weekly_reviews`
- Personalization: `dashboard_widgets`

Every user-owned table includes a `user_id` foreign key, timestamps, indexes for primary query paths, and row-level security.
