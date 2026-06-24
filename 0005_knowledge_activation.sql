-- Knowledge Vault activation: concepts, reviews, graph edges, roadmap requirements, velocity
-- Extends existing flashcards with optional knowledge_concept_id (additive).

create table if not exists public.knowledge_concepts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  folder_id uuid references public.knowledge_folders(id) on delete set null,
  concept_name text not null,
  mastery_score smallint not null default 1 check (mastery_score between 1 and 5),
  mastery_updated_at timestamptz not null default now(),
  difficulty_level smallint not null default 3 check (difficulty_level between 1 and 5),
  related_concepts uuid[] not null default array[]::uuid[],
  first_learned_date date not null default current_date,
  last_reviewed_date date,
  retention_score smallint not null default 50 check (retention_score between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists knowledge_concepts_root_name_unique on public.knowledge_concepts(user_id, lower(concept_name)) where folder_id is null;
create unique index if not exists knowledge_concepts_folder_name_unique on public.knowledge_concepts(user_id, folder_id, lower(concept_name)) where folder_id is not null;

create index if not exists knowledge_concepts_user_folder_idx on public.knowledge_concepts(user_id, folder_id);
create index if not exists knowledge_concepts_user_name_idx on public.knowledge_concepts(user_id, lower(concept_name));

create table if not exists public.knowledge_reviews (
  id uuid primary key default gen_random_uuid(),
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  review_date date not null default current_date,
  mastery_rating smallint not null check (mastery_rating between 1 and 5),
  review_type text not null default 'self_assessment' check (review_type in ('self_assessment', 'deep_work_session', 'flashcard')),
  notes text,
  focus_session_id uuid references public.focus_sessions(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists knowledge_reviews_concept_idx on public.knowledge_reviews(concept_id, review_date desc);
create index if not exists knowledge_reviews_user_idx on public.knowledge_reviews(user_id, review_date desc);

create table if not exists public.concept_relationships (
  id uuid primary key default gen_random_uuid(),
  concept_id_1 uuid not null references public.knowledge_concepts(id) on delete cascade,
  concept_id_2 uuid not null references public.knowledge_concepts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  relationship_type text not null check (
    relationship_type in ('builds_on', 'relates_to', 'contrasts_with', 'enables', 'part_of')
  ),
  strength numeric(4,3) not null default 0.7 check (strength >= 0 and strength <= 1),
  created_at timestamptz not null default now(),
  check (concept_id_1 <> concept_id_2),
  unique (concept_id_1, concept_id_2, relationship_type)
);

create index if not exists concept_relationships_a_idx on public.concept_relationships(concept_id_1);
create index if not exists concept_relationships_b_idx on public.concept_relationships(concept_id_2);
create index if not exists concept_relationships_user_idx on public.concept_relationships(user_id);

create table if not exists public.roadmap_concept_requirements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  roadmap_id uuid not null references public.roadmaps(id) on delete cascade,
  milestone_id uuid not null references public.milestones(id) on delete cascade,
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  required_mastery_level smallint not null default 3 check (required_mastery_level between 1 and 5),
  created_at timestamptz not null default now(),
  unique (milestone_id, concept_id)
);

create index if not exists roadmap_concept_req_milestone_idx on public.roadmap_concept_requirements(milestone_id);

create table if not exists public.learning_velocity (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  days_to_mastery integer check (days_to_mastery is null or days_to_mastery >= 0),
  learning_speed text not null default 'normal' check (learning_speed in ('fast', 'normal', 'slow')),
  subject_area text not null default 'general',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, concept_id)
);

create index if not exists learning_velocity_user_idx on public.learning_velocity(user_id);

alter table public.flashcards add column if not exists knowledge_concept_id uuid references public.knowledge_concepts(id) on delete set null;
create index if not exists flashcards_concept_idx on public.flashcards(user_id, knowledge_concept_id);

alter table public.knowledge_concepts enable row level security;
alter table public.knowledge_reviews enable row level security;
alter table public.concept_relationships enable row level security;
alter table public.roadmap_concept_requirements enable row level security;
alter table public.learning_velocity enable row level security;

create policy "knowledge_concepts_all_own" on public.knowledge_concepts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "knowledge_reviews_all_own" on public.knowledge_reviews for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "concept_relationships_all_own" on public.concept_relationships for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "roadmap_concept_requirements_all_own" on public.roadmap_concept_requirements for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "learning_velocity_all_own" on public.learning_velocity for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create trigger knowledge_concepts_updated_at before update on public.knowledge_concepts for each row execute procedure public.set_updated_at();
create trigger learning_velocity_updated_at before update on public.learning_velocity for each row execute procedure public.set_updated_at();
