create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  roadmap_id uuid references public.roadmaps(id) on delete set null,
  milestone_id uuid references public.milestones(id) on delete set null,
  title text not null,
  description text,
  category text not null default 'general',
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high', 'critical')),
  status text not null default 'active' check (status in ('active', 'completed', 'archived')),
  due_date date,
  recurrence_rule text,
  carry_over boolean not null default true,
  position integer not null default 0,
  xp_reward integer not null default 25,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.knowledge_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  parent_folder_id uuid references public.knowledge_folders(id) on delete cascade,
  name text not null,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, parent_folder_id, name)
);

alter table public.knowledge_entries add column if not exists folder_id uuid references public.knowledge_folders(id) on delete set null;
alter table public.knowledge_entries add column if not exists pinned boolean not null default false;
alter table public.knowledge_entries add column if not exists category text not null default 'notes';
alter table public.knowledge_entries add column if not exists search_vector tsvector generated always as (to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content_markdown, ''))) stored;

create table if not exists public.file_uploads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  knowledge_entry_id uuid references public.knowledge_entries(id) on delete cascade,
  bucket text not null default 'knowledge-assets',
  storage_path text not null,
  file_name text not null,
  mime_type text,
  size_bytes bigint,
  created_at timestamptz not null default now()
);

create table if not exists public.exercise_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  log_date date not null default current_date,
  activity_type text not null default 'movement',
  duration_minutes integer not null default 0,
  intensity integer check (intensity between 1 and 10),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text,
  notification_type text not null default 'system',
  related_type text,
  related_id uuid,
  scheduled_for timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null,
  domain text not null default 'system',
  value numeric not null default 1,
  source_type text,
  source_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.flashcard_decks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  knowledge_entry_id uuid references public.knowledge_entries(id) on delete set null,
  title text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.flashcards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  deck_id uuid not null references public.flashcard_decks(id) on delete cascade,
  knowledge_entry_id uuid references public.knowledge_entries(id) on delete set null,
  front text not null,
  back text not null,
  ease_factor numeric(4,2) not null default 2.50,
  interval_days integer not null default 0,
  repetitions integer not null default 0,
  due_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.flashcard_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  flashcard_id uuid not null references public.flashcards(id) on delete cascade,
  quality integer not null check (quality between 0 and 5),
  reviewed_at timestamptz not null default now(),
  next_due_at timestamptz not null,
  created_at timestamptz not null default now()
);

alter table public.focus_sessions add column if not exists task_id uuid references public.tasks(id) on delete set null;
alter table public.focus_sessions add column if not exists milestone_id uuid references public.milestones(id) on delete set null;
alter table public.focus_sessions add column if not exists focus_score integer check (focus_score between 0 and 100);
alter table public.focus_sessions add column if not exists xp_awarded integer not null default 0;
alter table public.focus_sessions add column if not exists ambient_sound text;

create index if not exists tasks_user_status_due_idx on public.tasks(user_id, status, due_date);
create index if not exists tasks_roadmap_idx on public.tasks(roadmap_id, milestone_id);
create index if not exists knowledge_folders_user_parent_idx on public.knowledge_folders(user_id, parent_folder_id, position);
create index if not exists knowledge_entries_folder_idx on public.knowledge_entries(folder_id);
create index if not exists knowledge_entries_search_idx on public.knowledge_entries using gin(search_vector);
create index if not exists file_uploads_entry_idx on public.file_uploads(knowledge_entry_id);
create index if not exists exercise_logs_user_date_idx on public.exercise_logs(user_id, log_date desc);
create index if not exists notifications_user_read_idx on public.notifications(user_id, read_at, scheduled_for);
create index if not exists analytics_events_user_domain_idx on public.analytics_events(user_id, domain, occurred_at desc);
create index if not exists flashcards_due_idx on public.flashcards(user_id, due_at);

alter table public.tasks enable row level security;
alter table public.knowledge_folders enable row level security;
alter table public.file_uploads enable row level security;
alter table public.exercise_logs enable row level security;
alter table public.notifications enable row level security;
alter table public.analytics_events enable row level security;
alter table public.flashcard_decks enable row level security;
alter table public.flashcards enable row level security;
alter table public.flashcard_reviews enable row level security;

create policy "tasks_all_own" on public.tasks for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "knowledge_folders_all_own" on public.knowledge_folders for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "file_uploads_all_own" on public.file_uploads for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "exercise_logs_all_own" on public.exercise_logs for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "notifications_all_own" on public.notifications for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "analytics_events_all_own" on public.analytics_events for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "flashcard_decks_all_own" on public.flashcard_decks for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "flashcards_all_own" on public.flashcards for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "flashcard_reviews_all_own" on public.flashcard_reviews for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create trigger tasks_updated_at before update on public.tasks for each row execute procedure public.set_updated_at();
create trigger knowledge_folders_updated_at before update on public.knowledge_folders for each row execute procedure public.set_updated_at();
create trigger exercise_logs_updated_at before update on public.exercise_logs for each row execute procedure public.set_updated_at();
create trigger flashcard_decks_updated_at before update on public.flashcard_decks for each row execute procedure public.set_updated_at();
create trigger flashcards_updated_at before update on public.flashcards for each row execute procedure public.set_updated_at();

insert into storage.buckets (id, name, public)
values ('knowledge-assets', 'knowledge-assets', false)
on conflict (id) do nothing;

create policy "knowledge_assets_select_own" on storage.objects
for select using (
  bucket_id = 'knowledge-assets'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "knowledge_assets_insert_own" on storage.objects
for insert with check (
  bucket_id = 'knowledge-assets'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "knowledge_assets_update_own" on storage.objects
for update using (
  bucket_id = 'knowledge-assets'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "knowledge_assets_delete_own" on storage.objects
for delete using (
  bucket_id = 'knowledge-assets'
  and auth.uid()::text = (storage.foldername(name))[1]
);
