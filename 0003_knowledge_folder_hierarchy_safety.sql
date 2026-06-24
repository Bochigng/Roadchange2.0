-- Knowledge folder hierarchy: cycle prevention + consistent ordering (idempotent).
-- Schema already includes parent_folder_id from 0002; this migration hardens invariants.

create or replace function public.knowledge_folders_prevent_cycle()
returns trigger
language plpgsql
as $$
begin
  if new.parent_folder_id is null then
    return new;
  end if;

  if new.parent_folder_id = new.id then
    raise exception 'knowledge_folders: folder cannot reference itself as parent';
  end if;

  if exists (
    with recursive upstream as (
      select id, parent_folder_id
      from public.knowledge_folders
      where id = new.parent_folder_id
        and user_id = new.user_id
      union all
      select f.id, f.parent_folder_id
      from public.knowledge_folders f
      inner join upstream u on f.id = u.parent_folder_id
      where f.user_id = new.user_id
    )
    select 1 from upstream where id = new.id
  ) then
    raise exception 'knowledge_folders: circular parent chain is not allowed';
  end if;

  return new;
end;
$$;

drop trigger if exists knowledge_folders_prevent_cycle on public.knowledge_folders;
create trigger knowledge_folders_prevent_cycle
before insert or update of parent_folder_id, id, user_id
on public.knowledge_folders
for each row
execute procedure public.knowledge_folders_prevent_cycle();

comment on column public.knowledge_folders.parent_folder_id is
  'Self-referential hierarchy; null = archive root. ON DELETE CASCADE removes subtree; knowledge_entries.folder_id set null.';
