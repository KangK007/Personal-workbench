-- 个人工作台云端同步表：每个账号只能访问自己的记录。
create table if not exists public.workspace_records (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  kind text not null,
  payload jsonb not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (user_id, id, kind)
);

alter table public.workspace_records enable row level security;

create policy "用户只能读取自己的工作台记录"
  on public.workspace_records for select
  using (auth.uid() = user_id);

create policy "用户只能新增自己的工作台记录"
  on public.workspace_records for insert
  with check (auth.uid() = user_id);

create policy "用户只能更新自己的工作台记录"
  on public.workspace_records for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "用户只能删除自己的工作台记录"
  on public.workspace_records for delete
  using (auth.uid() = user_id);

create index if not exists workspace_records_updated_at_idx
  on public.workspace_records(user_id, updated_at);
