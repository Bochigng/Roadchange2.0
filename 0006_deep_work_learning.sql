-- Deep Work ↔ Knowledge: session goals, outcomes, cognitive aggregates

create table if not exists public.deep_work_goals (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.focus_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  goal_description text not null,
  related_concept_id uuid references public.knowledge_concepts(id) on delete set null,
  target_mastery_level smallint not null default 3 check (target_mastery_level between 1 and 5),
  created_at timestamptz not null default now()
);

create index if not exists deep_work_goals_session_idx on public.deep_work_goals(session_id);
create index if not exists deep_work_goals_user_idx on public.deep_work_goals(user_id);

create table if not exists public.deep_work_outcomes (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.focus_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  goal_id uuid references public.deep_work_goals(id) on delete set null,
  concept_id uuid references public.knowledge_concepts(id) on delete set null,
  mastery_rating smallint not null check (mastery_rating between 1 and 5),
  retention_confidence smallint not null default 3 check (retention_confidence between 1 and 5),
  confusion_notes text,
  created_at timestamptz not null default now()
);

create index if not exists deep_work_outcomes_session_idx on public.deep_work_outcomes(session_id);
create index if not exists deep_work_outcomes_user_idx on public.deep_work_outcomes(user_id, created_at desc);

create table if not exists public.cognitive_performance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  subject_area text not null default 'general',
  time_of_day text not null default 'unknown' check (time_of_day in ('morning', 'afternoon', 'evening', 'unknown')),
  average_focus_quality numeric not null default 0,
  average_mastery_gain numeric not null default 0,
  session_count integer not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, subject_area, time_of_day)
);

create index if not exists cognitive_performance_user_idx on public.cognitive_performance(user_id);

alter table public.deep_work_goals enable row level security;
alter table public.deep_work_outcomes enable row level security;
alter table public.cognitive_performance enable row level security;

create policy "deep_work_goals_all_own" on public.deep_work_goals for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "deep_work_outcomes_all_own" on public.deep_work_outcomes for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "cognitive_performance_all_own" on public.cognitive_performance for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create trigger cognitive_performance_updated_at before update on public.cognitive_performance for each row execute procedure public.set_updated_at();
