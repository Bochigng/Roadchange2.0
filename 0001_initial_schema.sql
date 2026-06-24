create extension if not exists "pgcrypto";

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  avatar_url text,
  vision_statement text,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  theme text not null default 'pearl_glass',
  motion_level text not null default 'cinematic',
  dashboard_layout jsonb not null default '{}'::jsonb,
  focus_preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  category text not null,
  priority integer not null default 3,
  status text not null default 'active',
  target_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.roadmaps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  goal_id uuid references public.goals(id) on delete set null,
  title text not null,
  category text not null,
  visualization_mode text not null default 'timeline_lanes',
  progress numeric(5,2) not null default 0,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.milestones (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  roadmap_id uuid not null references public.roadmaps(id) on delete cascade,
  parent_milestone_id uuid references public.milestones(id) on delete cascade,
  title text not null,
  description text,
  phase text,
  position integer not null default 0,
  xp_value integer not null default 100,
  status text not null default 'queued',
  due_date date,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.focus_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  intention text not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  duration_minutes integer not null,
  quality_score integer check (quality_score between 1 and 10),
  distractions text[] not null default '{}',
  completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.xp_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  domain text not null,
  amount integer not null default 0,
  source_type text,
  source_id uuid,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.streaks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  streak_type text not null,
  current_count integer not null default 0,
  best_count integer not null default 0,
  last_activity_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, streak_type)
);

create table if not exists public.health_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  log_date date not null default current_date,
  hydration_glasses integer default 0,
  exercise_minutes integer default 0,
  posture_score integer check (posture_score between 1 and 10),
  burnout_indicator integer check (burnout_indicator between 1 and 10),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, log_date)
);

create table if not exists public.sleep_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  sleep_start timestamptz,
  sleep_end timestamptz,
  duration_minutes integer,
  consistency_score integer check (consistency_score between 0 and 100),
  quality_score integer check (quality_score between 1 and 10),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.knowledge_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  content_markdown text not null default '',
  folder text,
  tags text[] not null default '{}',
  roadmap_id uuid references public.roadmaps(id) on delete set null,
  milestone_id uuid references public.milestones(id) on delete set null,
  source_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reflections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  reflection_date date not null default current_date,
  content text not null,
  emotional_pattern text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.weekly_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  week_start date not null,
  wins text,
  failures text,
  distractions text,
  emotional_patterns text,
  burnout_signals text,
  next_week_adjustments text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, week_start)
);

create table if not exists public.evolution_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  metric_type text not null,
  metric_value numeric not null,
  period_start date,
  period_end date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.dashboard_widgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  widget_type text not null,
  position integer not null default 0,
  visible boolean not null default true,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists goals_user_status_idx on public.goals(user_id, status);
create index if not exists roadmaps_user_category_idx on public.roadmaps(user_id, category);
create index if not exists milestones_roadmap_position_idx on public.milestones(roadmap_id, position);
create index if not exists focus_sessions_user_started_idx on public.focus_sessions(user_id, started_at desc);
create index if not exists xp_progress_user_domain_idx on public.xp_progress(user_id, domain, recorded_at desc);
create index if not exists health_logs_user_date_idx on public.health_logs(user_id, log_date desc);
create index if not exists sleep_logs_user_created_idx on public.sleep_logs(user_id, created_at desc);
create index if not exists knowledge_entries_user_folder_idx on public.knowledge_entries(user_id, folder);
create index if not exists weekly_reviews_user_week_idx on public.weekly_reviews(user_id, week_start desc);
create index if not exists evolution_metrics_user_type_idx on public.evolution_metrics(user_id, metric_type, created_at desc);

alter table public.profiles enable row level security;
alter table public.settings enable row level security;
alter table public.goals enable row level security;
alter table public.roadmaps enable row level security;
alter table public.milestones enable row level security;
alter table public.focus_sessions enable row level security;
alter table public.xp_progress enable row level security;
alter table public.streaks enable row level security;
alter table public.health_logs enable row level security;
alter table public.sleep_logs enable row level security;
alter table public.knowledge_entries enable row level security;
alter table public.reflections enable row level security;
alter table public.weekly_reviews enable row level security;
alter table public.evolution_metrics enable row level security;
alter table public.dashboard_widgets enable row level security;

create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

create policy "settings_all_own" on public.settings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "goals_all_own" on public.goals for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "roadmaps_all_own" on public.roadmaps for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "milestones_all_own" on public.milestones for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "focus_sessions_all_own" on public.focus_sessions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "xp_progress_all_own" on public.xp_progress for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "streaks_all_own" on public.streaks for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "health_logs_all_own" on public.health_logs for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "sleep_logs_all_own" on public.sleep_logs for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "knowledge_entries_all_own" on public.knowledge_entries for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "reflections_all_own" on public.reflections for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "weekly_reviews_all_own" on public.weekly_reviews for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "evolution_metrics_all_own" on public.evolution_metrics for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "dashboard_widgets_all_own" on public.dashboard_widgets for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;

  insert into public.settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create trigger profiles_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
create trigger settings_updated_at before update on public.settings for each row execute procedure public.set_updated_at();
create trigger goals_updated_at before update on public.goals for each row execute procedure public.set_updated_at();
create trigger roadmaps_updated_at before update on public.roadmaps for each row execute procedure public.set_updated_at();
create trigger milestones_updated_at before update on public.milestones for each row execute procedure public.set_updated_at();
create trigger focus_sessions_updated_at before update on public.focus_sessions for each row execute procedure public.set_updated_at();
create trigger streaks_updated_at before update on public.streaks for each row execute procedure public.set_updated_at();
create trigger health_logs_updated_at before update on public.health_logs for each row execute procedure public.set_updated_at();
create trigger sleep_logs_updated_at before update on public.sleep_logs for each row execute procedure public.set_updated_at();
create trigger knowledge_entries_updated_at before update on public.knowledge_entries for each row execute procedure public.set_updated_at();
create trigger reflections_updated_at before update on public.reflections for each row execute procedure public.set_updated_at();
create trigger weekly_reviews_updated_at before update on public.weekly_reviews for each row execute procedure public.set_updated_at();
create trigger dashboard_widgets_updated_at before update on public.dashboard_widgets for each row execute procedure public.set_updated_at();
