-- Genesis Master Roadmap: master orchestration layer + links to existing roadmaps
-- Additive: does not modify core roadmap semantics beyond optional linkage columns.

create table if not exists public.genesis_master_roadmap (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  layer smallint not null check (layer between 1 and 3),
  phase_number smallint not null check (phase_number between 1 and 6),
  phase_name text not null,
  start_date date not null,
  end_date date not null,
  description text,
  key_principles text,
  status text not null default 'pending' check (status in ('active', 'completed', 'pending')),
  milestone_review_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, phase_number),
  constraint genesis_master_roadmap_date_order check (end_date >= start_date)
);

create index if not exists genesis_master_roadmap_user_layer_idx on public.genesis_master_roadmap(user_id, layer, phase_number);
create index if not exists genesis_master_roadmap_user_dates_idx on public.genesis_master_roadmap(user_id, start_date, end_date);

create table if not exists public.genesis_roadmap_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  genesis_master_roadmap_id uuid not null references public.genesis_master_roadmap(id) on delete cascade,
  roadmap_id uuid not null references public.roadmaps(id) on delete cascade,
  connection_type text not null check (connection_type in ('supports', 'enables', 'requires')),
  influence_weight numeric(4,3) not null default 1.0 check (influence_weight >= 0 and influence_weight <= 1),
  created_at timestamptz not null default now(),
  unique (genesis_master_roadmap_id, roadmap_id)
);

create index if not exists genesis_roadmap_connections_user_idx on public.genesis_roadmap_connections(user_id, roadmap_id);
create index if not exists genesis_roadmap_connections_genesis_idx on public.genesis_roadmap_connections(genesis_master_roadmap_id);

create table if not exists public.genesis_critical_dates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  genesis_master_roadmap_id uuid references public.genesis_master_roadmap(id) on delete set null,
  label text not null,
  category text not null default 'deadline',
  due_date date not null,
  notes text,
  propagate_to_roadmap_ids uuid[] not null default array[]::uuid[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists genesis_critical_dates_user_due_idx on public.genesis_critical_dates(user_id, due_date);

create table if not exists public.genesis_milestone_links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  genesis_master_roadmap_id uuid not null references public.genesis_master_roadmap(id) on delete cascade,
  milestone_id uuid not null references public.milestones(id) on delete cascade,
  is_layer_gate boolean not null default false,
  created_at timestamptz not null default now(),
  unique (genesis_master_roadmap_id, milestone_id)
);

create index if not exists genesis_milestone_links_user_idx on public.genesis_milestone_links(user_id, milestone_id);
create index if not exists genesis_milestone_links_phase_idx on public.genesis_milestone_links(genesis_master_roadmap_id);

-- Reminder deduplication for critical dates (30 / 7 / 1 day offsets)
create table if not exists public.genesis_critical_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  critical_date_id uuid not null references public.genesis_critical_dates(id) on delete cascade,
  offset_days integer not null check (offset_days in (30, 7, 1)),
  scheduled_for date not null,
  notification_id uuid references public.notifications(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (critical_date_id, offset_days, scheduled_for)
);

create index if not exists genesis_critical_reminders_user_idx on public.genesis_critical_reminders(user_id, scheduled_for);

alter table public.milestones add column if not exists linked_genesis_phase_id uuid references public.genesis_master_roadmap(id) on delete set null;

create index if not exists milestones_linked_genesis_phase_idx on public.milestones(user_id, linked_genesis_phase_id);

alter table public.genesis_master_roadmap enable row level security;
alter table public.genesis_roadmap_connections enable row level security;
alter table public.genesis_critical_dates enable row level security;
alter table public.genesis_milestone_links enable row level security;
alter table public.genesis_critical_reminders enable row level security;

create policy "genesis_master_roadmap_all_own" on public.genesis_master_roadmap
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "genesis_roadmap_connections_all_own" on public.genesis_roadmap_connections
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "genesis_critical_dates_all_own" on public.genesis_critical_dates
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "genesis_milestone_links_all_own" on public.genesis_milestone_links
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "genesis_critical_reminders_all_own" on public.genesis_critical_reminders
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create trigger genesis_master_roadmap_updated_at before update on public.genesis_master_roadmap
  for each row execute procedure public.set_updated_at();
create trigger genesis_critical_dates_updated_at before update on public.genesis_critical_dates
  for each row execute procedure public.set_updated_at();

-- Connections must reference roadmaps owned by the same user (prevents cross-user wiring)
create or replace function public.enforce_genesis_connection_roadmap_owner()
returns trigger
language plpgsql
as $$
declare
  roadmap_owner uuid;
  genesis_owner uuid;
begin
  select user_id into roadmap_owner from public.roadmaps where id = new.roadmap_id;
  select user_id into genesis_owner from public.genesis_master_roadmap where id = new.genesis_master_roadmap_id;
  if roadmap_owner is null or genesis_owner is null then
    raise exception 'Invalid genesis connection reference';
  end if;
  if roadmap_owner <> genesis_owner or roadmap_owner <> new.user_id then
    raise exception 'genesis_roadmap_connections user mismatch';
  end if;
  return new;
end;
$$;

drop trigger if exists genesis_roadmap_connections_owner_guard on public.genesis_roadmap_connections;
create trigger genesis_roadmap_connections_owner_guard
  before insert or update on public.genesis_roadmap_connections
  for each row execute procedure public.enforce_genesis_connection_roadmap_owner();

create or replace function public.enforce_genesis_milestone_owner_match()
returns trigger
language plpgsql
as $$
declare
  milestone_owner uuid;
  genesis_owner uuid;
begin
  select user_id into milestone_owner from public.milestones where id = new.milestone_id;
  select user_id into genesis_owner from public.genesis_master_roadmap where id = new.genesis_master_roadmap_id;
  if milestone_owner is null or genesis_owner is null then
    raise exception 'Invalid genesis milestone link';
  end if;
  if milestone_owner <> genesis_owner or milestone_owner <> new.user_id then
    raise exception 'genesis_milestone_links user mismatch';
  end if;
  return new;
end;
$$;

drop trigger if exists genesis_milestone_links_owner_guard on public.genesis_milestone_links;
create trigger genesis_milestone_links_owner_guard
  before insert or update on public.genesis_milestone_links
  for each row execute procedure public.enforce_genesis_milestone_owner_match();
