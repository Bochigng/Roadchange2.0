-- Adaptive roadmap + health regulation: cached state, audit log, daily health scores

create table if not exists public.health_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  score_date date not null default current_date,
  composite_score smallint not null check (composite_score between 0 and 100),
  sleep_proxy_points smallint not null default 0,
  exercise_points smallint not null default 0,
  energy_points smallint not null default 0,
  posture_points smallint not null default 0,
  stress_points smallint not null default 0,
  breakdown jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, score_date)
);

create index if not exists health_scores_user_date_idx on public.health_scores(user_id, score_date desc);

create table if not exists public.exec_regulation_state (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  computed_at timestamptz not null default now(),
  health_score smallint,
  capacity_score smallint check (capacity_score between 0 and 100),
  burnout_risk_pct smallint check (burnout_risk_pct between 0 and 100),
  workload_adjustment_pct smallint,
  recovery_mode boolean not null default false,
  recovery_source text not null default 'none' check (recovery_source in ('none', 'user', 'system')),
  recommended_milestone_cap integer,
  snapshot jsonb not null default '{}'::jsonb
);

create table if not exists public.adaptive_adjustments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  roadmap_id uuid references public.roadmaps(id) on delete set null,
  adjustment_type text not null,
  delta jsonb not null default '{}'::jsonb,
  reason text not null,
  auto_applied boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists adaptive_adjustments_user_idx on public.adaptive_adjustments(user_id, created_at desc);

create table if not exists public.recovery_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  source text not null default 'user' check (source in ('user', 'system')),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists recovery_sessions_user_idx on public.recovery_sessions(user_id, started_at desc);

alter table public.health_scores enable row level security;
alter table public.exec_regulation_state enable row level security;
alter table public.adaptive_adjustments enable row level security;
alter table public.recovery_sessions enable row level security;

create policy "health_scores_all_own" on public.health_scores for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "exec_regulation_state_all_own" on public.exec_regulation_state for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "adaptive_adjustments_all_own" on public.adaptive_adjustments for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "recovery_sessions_all_own" on public.recovery_sessions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
