-- Migration 0008: Bug fixes
-- Run in Supabase Dashboard → SQL Editor (all statements are idempotent)

-- ============================================================
-- FIX 1: Root-level folder name uniqueness
-- PostgreSQL treats NULL != NULL so the existing UNIQUE constraint on
-- (user_id, parent_folder_id, name) does NOT prevent two root folders
-- from sharing a name. Add a partial index for the null-parent case.
-- ============================================================
create unique index if not exists knowledge_folders_root_name_unique
  on public.knowledge_folders (user_id, name)
  where parent_folder_id is null;


-- ============================================================
-- FIX 2: Ensure storage bucket exists with sensible limits
-- ============================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'knowledge-assets',
  'knowledge-assets',
  false,
  52428800,
  array[
    'image/jpeg','image/png','image/gif','image/webp',
    'application/pdf','text/plain','text/markdown',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
on conflict (id) do update set
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;


-- ============================================================
-- FIX 3: Re-apply storage RLS policies idempotently
-- (original migration may have been cut off mid-file)
-- ============================================================
drop policy if exists "knowledge_assets_select_own" on storage.objects;
drop policy if exists "knowledge_assets_insert_own" on storage.objects;
drop policy if exists "knowledge_assets_update_own" on storage.objects;
drop policy if exists "knowledge_assets_delete_own" on storage.objects;

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


-- ============================================================
-- FIX 4: Add missing profiles INSERT policy
-- handle_new_user trigger uses SECURITY DEFINER so signup works,
-- but any direct client-side profile insert fails without this.
-- ============================================================
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);
