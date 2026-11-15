-- Schema v0. Every tenant table carries household_id; member_id where a person
-- owns the row. RLS is enabled and forced on all ten tables, so the owner of the
-- table (the deploy role) is still subject to the policy.
--
-- Two settings drive the policies:
--   hopa.household_id  the tenant of a transaction (set by Database.tenant)
--   hopa.token_hash    the hash the caller already presented (set by Database.token)
-- A missing setting is NULL, and NULL never matches, so the default is deny.

create table households (
    id uuid primary key,
    name text not null,
    created_at timestamptz not null default now()
);

create table members (
    id uuid primary key,
    household_id uuid not null references households (id) on delete cascade,
    role text not null check (role in ('owner', 'member')),
    display_name text not null,
    created_at timestamptz not null default now()
);
create index members_household_idx on members (household_id);

create table devices (
    id uuid primary key,
    household_id uuid not null references households (id) on delete cascade,
    member_id uuid not null references members (id) on delete cascade,
    platform text not null check (platform in ('android', 'windows')),
    name text not null,
    public_key bytea,
    alg text,
    push_token text,
    capabilities jsonb not null default '{}'::jsonb,
    last_seen_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz not null default now()
);
create index devices_household_idx on devices (household_id);

create table pairing_sessions (
    id uuid primary key,
    household_id uuid not null references households (id) on delete cascade,
    member_id uuid not null references members (id) on delete cascade,
    code_hash bytea not null unique,
    expires_at timestamptz not null,
    claimed_at timestamptz,
    created_at timestamptz not null default now()
);

create table refresh_tokens (
    id uuid primary key,
    device_id uuid not null references devices (id) on delete cascade,
    household_id uuid not null references households (id) on delete cascade,
    token_hash bytea not null unique,
    issued_at timestamptz not null default now(),
    expires_at timestamptz not null,
    rotated_from uuid,
    revoked_at timestamptz
);
create index refresh_tokens_device_idx on refresh_tokens (device_id);

create table access_tokens (
    id uuid primary key,
    device_id uuid not null references devices (id) on delete cascade,
    household_id uuid not null references households (id) on delete cascade,
    token_hash bytea not null unique,
    expires_at timestamptz not null
);
create index access_tokens_device_idx on access_tokens (device_id);

create table tasks (
    id uuid primary key,
    household_id uuid not null references households (id) on delete cascade,
    member_id uuid not null references members (id),
    from_device uuid not null,
    to_device uuid not null,
    message_id uuid not null,
    state text not null check (state in (
        'queued', 'delivered', 'acked', 'progress', 'done', 'failed', 'cancelled'
    )),
    trace_id text not null,
    body bytea not null,
    deadline_at timestamptz not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index tasks_target_idx on tasks (to_device, state);
create index tasks_message_idx on tasks (household_id, message_id);

create table task_events (
    id bigserial primary key,
    task_id uuid not null references tasks (id) on delete cascade,
    household_id uuid not null references households (id) on delete cascade,
    member_id uuid,
    seq int not null,
    kind text not null,
    body bytea,
    at timestamptz not null,
    unique (task_id, seq)
);

create table idempotency_keys (
    household_id uuid not null references households (id) on delete cascade,
    message_id uuid not null,
    response jsonb not null,
    expires_at timestamptz not null,
    primary key (household_id, message_id)
);
create index idempotency_expiry_idx on idempotency_keys (expires_at);

create table trace_spans (
    household_id uuid not null references households (id) on delete cascade,
    trace_id text not null,
    span_id text not null,
    operation text not null,
    device_id uuid,
    task_id uuid,
    started_at timestamptz not null,
    duration_ms bigint not null,
    status text not null check (status in ('ok', 'error')),
    attributes jsonb not null default '{}'::jsonb,
    primary key (trace_id, span_id)
);
create index trace_spans_trace_idx on trace_spans (trace_id, started_at);

alter table households enable row level security;
alter table households force row level security;
create policy households_own on households
    using (id = nullif(current_setting('hopa.household_id', true), '')::uuid)
    with check (id = nullif(current_setting('hopa.household_id', true), '')::uuid);

alter table members enable row level security;
alter table members force row level security;
create policy members_own on members
    using (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid)
    with check (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);

alter table devices enable row level security;
alter table devices force row level security;
create policy devices_own on devices
    using (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid)
    with check (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);

alter table tasks enable row level security;
alter table tasks force row level security;
create policy tasks_own on tasks
    using (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid)
    with check (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);

alter table task_events enable row level security;
alter table task_events force row level security;
create policy task_events_own on task_events
    using (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid)
    with check (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);

alter table idempotency_keys enable row level security;
alter table idempotency_keys force row level security;
create policy idempotency_keys_own on idempotency_keys
    using (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid)
    with check (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);

alter table trace_spans enable row level security;
alter table trace_spans force row level security;
create policy trace_spans_own on trace_spans
    using (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid)
    with check (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);

-- Token tables are the one place the tenant cannot be known before the row is
-- read: the hash the caller presented is the only key. SELECT is therefore
-- allowed by presented hash, while INSERT/UPDATE/DELETE happen in a household
-- transaction. Two policy families, not one: a single FOR ALL policy would make
-- issuing a token impossible (no token hash is set when the row is written).
alter table access_tokens enable row level security;
alter table access_tokens force row level security;
create policy access_tokens_presented on access_tokens for select
    using (token_hash = decode(nullif(current_setting('hopa.token_hash', true), ''), 'hex'));
create policy access_tokens_tenant_select on access_tokens for select
    using (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);
create policy access_tokens_tenant_insert on access_tokens for insert
    with check (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);
create policy access_tokens_tenant_delete on access_tokens for delete
    using (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);

alter table refresh_tokens enable row level security;
alter table refresh_tokens force row level security;
create policy refresh_tokens_presented on refresh_tokens for select
    using (token_hash = decode(nullif(current_setting('hopa.token_hash', true), ''), 'hex'));
create policy refresh_tokens_tenant_select on refresh_tokens for select
    using (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);
create policy refresh_tokens_tenant_insert on refresh_tokens for insert
    with check (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);
create policy refresh_tokens_tenant_update on refresh_tokens for update
    using (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid)
    with check (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);

alter table pairing_sessions enable row level security;
alter table pairing_sessions force row level security;
create policy pairing_sessions_presented on pairing_sessions for select
    using (code_hash = decode(nullif(current_setting('hopa.token_hash', true), ''), 'hex'));
create policy pairing_sessions_tenant_select on pairing_sessions for select
    using (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);
create policy pairing_sessions_tenant_insert on pairing_sessions for insert
    with check (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);
create policy pairing_sessions_tenant_update on pairing_sessions for update
    using (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid)
    with check (household_id = nullif(current_setting('hopa.household_id', true), '')::uuid);
