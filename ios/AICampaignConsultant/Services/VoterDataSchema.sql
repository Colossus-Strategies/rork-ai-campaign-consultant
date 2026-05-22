-- =====================================================================
-- Colossus Campaign OS — Voter Data Module
-- Run this in Supabase SQL editor ONCE to provision the voter database.
-- v1: Ohio only. Schema is state-agnostic; add states by inserting into
-- `states` and loading rows tagged with the new state_code.
-- =====================================================================

create extension if not exists pg_trgm;
create extension if not exists postgis;

-- ---------------------------------------------------------------------
-- Lookup: states the app currently supports
-- ---------------------------------------------------------------------
create table if not exists public.states (
  state_code text primary key,
  name text not null,
  data_use_notice text not null
);

insert into public.states (state_code, name, data_use_notice) values
('OH',
 'Ohio',
 'Ohio voter registration data is a public record provided by the Ohio Secretary of State. '
 'Per Ohio Revised Code §3503.13 and §111.41, this data may be used for election, '
 'governmental, or political purposes only and MAY NOT be used for any commercial '
 'solicitation. Misuse may constitute a criminal offense. By acknowledging, you confirm '
 'you will use this data solely for your declared campaign and will not redistribute or '
 'sell it.')
on conflict (state_code) do update set
  name = excluded.name,
  data_use_notice = excluded.data_use_notice;

-- ---------------------------------------------------------------------
-- Voters
-- ---------------------------------------------------------------------
create table if not exists public.voters (
  id uuid primary key default gen_random_uuid(),
  state_code text not null references public.states(state_code),
  external_voterid text not null,
  first_name text,
  middle_name text,
  last_name text,
  suffix text,
  dob date,
  registration_date date,
  party_affiliation text,
  voter_status text,
  county text,
  precinct_code text,
  congressional_district text,
  state_senate_district text,
  state_rep_district text,
  residential_address text,
  city text,
  zip text,
  geom geography(Point, 4326),
  updated_at timestamptz not null default now(),
  unique (state_code, external_voterid)
);

create index if not exists voters_last_name_trgm  on public.voters using gin (last_name gin_trgm_ops);
create index if not exists voters_first_name_trgm on public.voters using gin (first_name gin_trgm_ops);
create index if not exists voters_state_cong on public.voters (state_code, congressional_district);
create index if not exists voters_state_sen  on public.voters (state_code, state_senate_district);
create index if not exists voters_state_rep  on public.voters (state_code, state_rep_district);
create index if not exists voters_state_cty  on public.voters (state_code, county);
create index if not exists voters_precinct   on public.voters (state_code, precinct_code);
create index if not exists voters_geom_gist  on public.voters using gist (geom);

-- ---------------------------------------------------------------------
-- Vote history
-- ---------------------------------------------------------------------
create table if not exists public.voter_history (
  voter_id uuid not null references public.voters(id) on delete cascade,
  election_date date not null,
  election_type text not null, -- GENERAL / PRIMARY / SPECIAL
  party_voted text,
  primary key (voter_id, election_date)
);
create index if not exists voter_history_voter on public.voter_history (voter_id);
create index if not exists voter_history_date  on public.voter_history (election_date desc);

-- ---------------------------------------------------------------------
-- Audit log: every voter-data read by an authenticated candidate
-- ---------------------------------------------------------------------
create table if not exists public.voter_access_audit (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  race_id uuid,
  query_type text not null,
  filters jsonb not null default '{}'::jsonb,
  result_count int not null default 0,
  accessed_at timestamptz not null default now()
);
create index if not exists voter_audit_user_time on public.voter_access_audit (user_id, accessed_at desc);

-- ---------------------------------------------------------------------
-- Compliance ack column on candidate_profiles
-- ---------------------------------------------------------------------
alter table public.candidate_profiles
  add column if not exists voter_data_ack_at timestamptz,
  add column if not exists voter_data_ack_version text;

-- ---------------------------------------------------------------------
-- Helper: maps the candidate's profile.state ("Ohio" or "OH") to a
-- normalized two-letter code used by the voters table.
-- ---------------------------------------------------------------------
create or replace function public.normalize_state_code(s text)
returns text language sql immutable as $$
  select case upper(coalesce(s, ''))
    when 'OHIO' then 'OH'
    when 'OH' then 'OH'
    else upper(coalesce(s, ''))
  end
$$;

-- ---------------------------------------------------------------------
-- Helper: does the calling candidate have access to this voter row?
-- Scoped by candidate_profiles.race_id + candidate_profiles.district.
-- ---------------------------------------------------------------------
create or replace function public.candidate_can_see_voter(v public.voters)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.candidate_profiles cp
    where cp.id = auth.uid()
      and cp.voter_data_ack_at is not null
      and normalize_state_code(cp.state) = v.state_code
      and case cp.race_id
        when 'statewide' then true
        when 'congress'  then v.congressional_district = cp.district
        when 'state'     then v.state_rep_district = cp.district
                              or v.state_senate_district = cp.district
        when 'county'    then upper(v.county) = upper(cp.district)
        when 'local'     then upper(v.county) = upper(cp.district)
        else false
      end
  )
$$;

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.voters             enable row level security;
alter table public.voter_history      enable row level security;
alter table public.voter_access_audit enable row level security;
alter table public.states             enable row level security;

-- Allow anon/unauthenticated audit rows (user_id may be null) since the app
-- runs voter RPCs with the anon JWT after we dropped the sign-in wall.
alter table public.voter_access_audit alter column user_id drop not null;

drop policy if exists "states readable" on public.states;
create policy "states readable" on public.states for select using (true);

drop policy if exists "voters scoped read" on public.voters;
create policy "voters scoped read" on public.voters
  for select using (public.candidate_can_see_voter(voters));

drop policy if exists "voter history scoped read" on public.voter_history;
create policy "voter history scoped read" on public.voter_history
  for select using (
    exists (
      select 1 from public.voters v
      where v.id = voter_history.voter_id
        and public.candidate_can_see_voter(v)
    )
  );

drop policy if exists "audit owner read" on public.voter_access_audit;
create policy "audit owner read" on public.voter_access_audit
  for select using (auth.uid() is not null and auth.uid() = user_id);

-- Permissive insert: allow either the owning authenticated user or anon
-- callers (where auth.uid() is null and user_id must also be null).
drop policy if exists "audit owner insert" on public.voter_access_audit;
create policy "audit owner insert" on public.voter_access_audit
  for insert with check (
    (auth.uid() is null and user_id is null)
    or auth.uid() = user_id
  );

-- ---------------------------------------------------------------------
-- Materialized view: daily-refreshed district summary per candidate
-- (We refresh by district key. The view holds rollups for every active
--  district; the RPC layer picks the row matching the caller's profile.)
-- ---------------------------------------------------------------------
create materialized view if not exists public.district_voter_summary as
select
  state_code,
  congressional_district,
  state_senate_district,
  state_rep_district,
  county,
  count(*)::int as total_voters,
  count(*) filter (where voter_status = 'ACTIVE')::int as active_voters,
  count(*) filter (where voter_status = 'CONFIRMATION')::int as confirmation_voters,
  count(*) filter (where voter_status = 'CANCELLED')::int as cancelled_voters,
  count(*) filter (where party_affiliation in ('D','DEM','DEMOCRAT'))::int as dem_count,
  count(*) filter (where party_affiliation in ('R','REP','REPUBLICAN'))::int as rep_count,
  count(*) filter (where party_affiliation is null or party_affiliation in ('','U','UNAFFILIATED','I','IND','INDEPENDENT'))::int as una_count,
  count(*) filter (where party_affiliation not in ('D','DEM','DEMOCRAT','R','REP','REPUBLICAN','','U','UNAFFILIATED','I','IND','INDEPENDENT'))::int as other_count
from public.voters
group by state_code, congressional_district, state_senate_district, state_rep_district, county;

create index if not exists dvs_keys on public.district_voter_summary
  (state_code, congressional_district, state_senate_district, state_rep_district, county);

-- Schedule with Supabase cron (pg_cron) or the GitHub Actions ingest job:
--   refresh materialized view concurrently public.district_voter_summary;

-- =====================================================================
-- RPCs called by the iOS app. All run as the calling user (security
-- invoker) so RLS applies. Each one logs to voter_access_audit.
-- =====================================================================

-- Resolves the caller's effective district scope as a single row.
create or replace function public.candidate_scope()
returns table (
  state_code text,
  race_id text,
  district text
) language sql stable security invoker as $$
  select normalize_state_code(state), race_id, district
  from public.candidate_profiles
  where id = auth.uid()
$$;

-- 1) District summary card data
create or replace function public.get_district_summary()
returns jsonb language plpgsql security invoker as $$
declare
  s_code text; r_id text; dist text; payload jsonb;
begin
  select state_code, race_id, district into s_code, r_id, dist
  from public.candidate_scope();

  with scoped as (
    select * from public.voters v
    where public.candidate_can_see_voter(v)
  ),
  agg as (
    select
      count(*)::int as total,
      max(updated_at) as last_refresh,
      count(*) filter (where voter_status = 'ACTIVE')::int as active,
      count(*) filter (where voter_status = 'CONFIRMATION')::int as confirmation,
      count(*) filter (where voter_status = 'CANCELLED')::int as cancelled,
      count(*) filter (where party_affiliation in ('D','DEM','DEMOCRAT'))::int as dem,
      count(*) filter (where party_affiliation in ('R','REP','REPUBLICAN'))::int as rep,
      count(*) filter (where party_affiliation is null or party_affiliation in ('','U','UNAFFILIATED','I','IND','INDEPENDENT'))::int as una,
      count(*) filter (where party_affiliation not in ('D','DEM','DEMOCRAT','R','REP','REPUBLICAN','','U','UNAFFILIATED','I','IND','INDEPENDENT'))::int as other
    from scoped
  )
  select jsonb_build_object(
    'state_code', s_code,
    'race_id', r_id,
    'district', dist,
    'total_voters', a.total,
    'last_refresh_at', a.last_refresh,
    'status', jsonb_build_object('active', a.active, 'confirmation', a.confirmation, 'cancelled', a.cancelled),
    'party',  jsonb_build_object('democrat', a.dem, 'republican', a.rep, 'unaffiliated', a.una, 'other', a.other)
  ) into payload
  from agg a;

  insert into public.voter_access_audit (user_id, query_type, filters, result_count)
  values (auth.uid(), 'district_summary', '{}'::jsonb, coalesce((payload->>'total_voters')::int, 0));

  return payload;
end $$;

-- 2) Party breakdown
create or replace function public.get_party_breakdown(by text default 'overall')
returns jsonb language plpgsql security invoker as $$
declare payload jsonb;
begin
  if by = 'precinct' then
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into payload
    from (
      select precinct_code,
             count(*) filter (where party_affiliation in ('D','DEM','DEMOCRAT'))::int as dem,
             count(*) filter (where party_affiliation in ('R','REP','REPUBLICAN'))::int as rep,
             count(*)::int as total
      from public.voters v
      where public.candidate_can_see_voter(v)
      group by precinct_code
      order by total desc
      limit 50
    ) t;
  elsif by = 'age' then
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into payload
    from (
      select bucket,
             count(*) filter (where party_affiliation in ('D','DEM','DEMOCRAT'))::int as dem,
             count(*) filter (where party_affiliation in ('R','REP','REPUBLICAN'))::int as rep,
             count(*)::int as total
      from (
        select party_affiliation,
               case
                 when dob is null then 'Unknown'
                 when extract(year from age(dob)) < 25 then '18-24'
                 when extract(year from age(dob)) < 35 then '25-34'
                 when extract(year from age(dob)) < 45 then '35-44'
                 when extract(year from age(dob)) < 55 then '45-54'
                 when extract(year from age(dob)) < 65 then '55-64'
                 else '65+'
               end as bucket
        from public.voters v
        where public.candidate_can_see_voter(v)
      ) b
      group by bucket
      order by bucket
    ) t;
  else
    select jsonb_build_object(
      'democrat', count(*) filter (where party_affiliation in ('D','DEM','DEMOCRAT')),
      'republican', count(*) filter (where party_affiliation in ('R','REP','REPUBLICAN')),
      'unaffiliated', count(*) filter (where party_affiliation is null or party_affiliation in ('','U','UNAFFILIATED','I','IND','INDEPENDENT')),
      'other', count(*) filter (where party_affiliation not in ('D','DEM','DEMOCRAT','R','REP','REPUBLICAN','','U','UNAFFILIATED','I','IND','INDEPENDENT'))
    ) into payload
    from public.voters v
    where public.candidate_can_see_voter(v);
  end if;

  insert into public.voter_access_audit (user_id, query_type, filters, result_count)
  values (auth.uid(), 'party_breakdown', jsonb_build_object('by', by), 0);

  return coalesce(payload, '{}'::jsonb);
end $$;

-- 3) Turnout history (last N generals + N primaries)
create or replace function public.get_turnout_history(election_count int default 4)
returns jsonb language plpgsql security invoker as $$
declare payload jsonb;
begin
  with scoped as (
    select id from public.voters v where public.candidate_can_see_voter(v)
  ),
  totals as (
    select (select count(*) from scoped)::int as total
  ),
  generals as (
    select election_date, count(distinct vh.voter_id)::int as voted
    from public.voter_history vh
    join scoped s on s.id = vh.voter_id
    where vh.election_type = 'GENERAL'
    group by election_date
    order by election_date desc
    limit election_count
  ),
  primaries as (
    select election_date, count(distinct vh.voter_id)::int as voted
    from public.voter_history vh
    join scoped s on s.id = vh.voter_id
    where vh.election_type = 'PRIMARY'
    group by election_date
    order by election_date desc
    limit election_count
  )
  select jsonb_build_object(
    'eligible', (select total from totals),
    'generals',  coalesce((select jsonb_agg(row_to_json(g) order by g.election_date) from generals g), '[]'::jsonb),
    'primaries', coalesce((select jsonb_agg(row_to_json(p) order by p.election_date) from primaries p), '[]'::jsonb)
  ) into payload;

  insert into public.voter_access_audit (user_id, query_type, filters, result_count)
  values (auth.uid(), 'turnout_history', jsonb_build_object('election_count', election_count), 0);

  return payload;
end $$;

-- 4) Top precincts
create or replace function public.get_top_precincts(metric text default 'voter_count')
returns jsonb language plpgsql security invoker as $$
declare payload jsonb;
begin
  if metric = 'turnout_rate' then
    with scoped as (
      select v.id, v.precinct_code from public.voters v where public.candidate_can_see_voter(v)
    ),
    elections as (
      select distinct election_date from public.voter_history
      where election_type = 'GENERAL' order by election_date desc limit 4
    )
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into payload
    from (
      select s.precinct_code,
             count(distinct s.id)::int as voter_count,
             round(100.0 * count(distinct vh.voter_id) /
                   nullif(count(distinct s.id) * (select count(*) from elections), 0), 1) as turnout_rate
      from scoped s
      left join public.voter_history vh
        on vh.voter_id = s.id
       and vh.election_date in (select election_date from elections)
      group by s.precinct_code
      order by turnout_rate desc nulls last
      limit 5
    ) t;
  else
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into payload
    from (
      select precinct_code, count(*)::int as voter_count
      from public.voters v
      where public.candidate_can_see_voter(v)
      group by precinct_code
      order by voter_count desc
      limit 5
    ) t;
  end if;

  insert into public.voter_access_audit (user_id, query_type, filters, result_count)
  values (auth.uid(), 'top_precincts', jsonb_build_object('metric', metric), 0);

  return coalesce(payload, '[]'::jsonb);
end $$;

-- 5) Find voters (filterable list)
-- filters: { party, age_min, age_max, status, turnout_min, turnout_max, precinct, search }
create or replace function public.find_voters(filters jsonb default '{}'::jsonb, page int default 0, page_size int default 50)
returns jsonb language plpgsql security invoker as $$
declare
  payload jsonb;
  total int;
  off int := greatest(page, 0) * greatest(page_size, 1);
begin
  with scoped as (
    select
      v.*,
      case when v.dob is null then null
           else extract(year from age(v.dob))::int end as age,
      (
        select count(*) from public.voter_history vh
        where vh.voter_id = v.id
          and vh.election_date >= (current_date - interval '10 years')
      )::int as turnout_score
    from public.voters v
    where public.candidate_can_see_voter(v)
  ),
  filtered as (
    select * from scoped
    where (filters->>'party' is null or party_affiliation ilike (filters->>'party')||'%')
      and (filters->>'status' is null or voter_status = (filters->>'status'))
      and (filters->>'precinct' is null or precinct_code = (filters->>'precinct'))
      and (filters->>'age_min' is null or age >= (filters->>'age_min')::int)
      and (filters->>'age_max' is null or age <= (filters->>'age_max')::int)
      and (filters->>'turnout_min' is null or turnout_score >= (filters->>'turnout_min')::int)
      and (filters->>'turnout_max' is null or turnout_score <= (filters->>'turnout_max')::int)
      and (filters->>'search' is null or
           (first_name ilike '%'||(filters->>'search')||'%' or
            last_name  ilike '%'||(filters->>'search')||'%'))
  )
  select count(*) into total from filtered;

  select jsonb_build_object(
    'total', total,
    'page', page,
    'page_size', page_size,
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', f.id,
        'first_name', f.first_name,
        'last_name', f.last_name,
        'age', f.age,
        'party', f.party_affiliation,
        'status', f.voter_status,
        'precinct', f.precinct_code,
        'address', f.residential_address,
        'city', f.city,
        'zip', f.zip,
        'turnout_score', f.turnout_score
      ))
      from (select * from filtered order by last_name, first_name limit page_size offset off) f
    ), '[]'::jsonb)
  ) into payload;

  insert into public.voter_access_audit (user_id, query_type, filters, result_count)
  values (auth.uid(), 'find_voters', filters, total);

  return payload;
end $$;

-- 6) Voter detail (single row + history)
create or replace function public.get_voter_detail(voter_id uuid)
returns jsonb language plpgsql security invoker as $$
declare payload jsonb;
begin
  select jsonb_build_object(
    'voter', row_to_json(v),
    'history', coalesce((
      select jsonb_agg(row_to_json(h) order by h.election_date desc)
      from public.voter_history h where h.voter_id = v.id
    ), '[]'::jsonb)
  ) into payload
  from public.voters v
  where v.id = voter_id
    and public.candidate_can_see_voter(v);

  insert into public.voter_access_audit (user_id, query_type, filters, result_count)
  values (auth.uid(), 'voter_detail', jsonb_build_object('voter_id', voter_id), case when payload is null then 0 else 1 end);

  return coalesce(payload, '{}'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- Ingest run history. Populated by the GitHub Actions ingest worker.
-- One row per (run, county) so silent county-level failures are visible.
-- ---------------------------------------------------------------------
create table if not exists public.voter_ingest_runs (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null,
  state_code text not null,
  county text,
  status text not null,                 -- running / success / failed / skipped
  rows_upserted int not null default 0,
  history_upserted int not null default 0,
  error text,
  started_at timestamptz not null default now(),
  ended_at timestamptz
);
create index if not exists ingest_runs_run     on public.voter_ingest_runs (run_id);
create index if not exists ingest_runs_started on public.voter_ingest_runs (started_at desc);

alter table public.voter_ingest_runs enable row level security;

drop policy if exists "ingest runs readable" on public.voter_ingest_runs;
create policy "ingest runs readable" on public.voter_ingest_runs
  for select using (
    exists (
      select 1 from public.candidate_profiles cp
      where cp.id = auth.uid()
        and normalize_state_code(cp.state) = voter_ingest_runs.state_code
    )
  );

-- Summary RPC: most recent run + per-county counts. Read by the app to
-- surface ingest history and flag failures.
create or replace function public.get_ingest_status(limit_runs int default 5)
returns jsonb language sql security invoker as $func$
  with recent as (
    select run_id, min(started_at) as started_at, max(ended_at) as ended_at,
           sum(rows_upserted)::int as rows_upserted,
           sum(history_upserted)::int as history_upserted,
           count(*) filter (where status = 'failed' and county is not null)::int as failed_counties,
           count(*) filter (where status = 'success' and county is not null)::int as success_counties,
           count(*) filter (where county is not null)::int as total_counties
    from public.voter_ingest_runs
    where state_code = (select normalize_state_code(state) from public.candidate_profiles where id = auth.uid())
    group by run_id
    order by started_at desc
    limit greatest(limit_runs, 1)
  )
  select coalesce(jsonb_agg(row_to_json(r) order by r.started_at desc), '[]'::jsonb)
  from recent r;
$func$;

-- Per-county detail for a specific run (for the tap-through view).
create or replace function public.get_ingest_run_detail(run uuid)
returns jsonb language sql security invoker as $func$
  select coalesce(jsonb_agg(jsonb_build_object(
    'county', county,
    'status', status,
    'rows_upserted', rows_upserted,
    'history_upserted', history_upserted,
    'error', error,
    'started_at', started_at,
    'ended_at', ended_at
  ) order by
    case when status = 'failed' then 0 else 1 end,
    county nulls last
  ), '[]'::jsonb)
  from public.voter_ingest_runs
  where run_id = run
    and county is not null
    and state_code = (select normalize_state_code(state) from public.candidate_profiles where id = auth.uid());
$func$;

-- 7) Build a targeting list. Goal in (door_knock, phone_bank, persuasion, custom).
create or replace function public.build_targeting_list(goal text, filters jsonb default '{}'::jsonb, page_size int default 500)
returns jsonb language plpgsql security invoker as $$
declare merged jsonb := filters;
begin
  if goal = 'door_knock' then
    merged := merged
      || jsonb_build_object('turnout_min', coalesce((filters->>'turnout_min')::int, 3), 'status', 'ACTIVE');
  elsif goal = 'phone_bank' then
    merged := merged
      || jsonb_build_object('turnout_min', 1, 'turnout_max', 3, 'status', 'ACTIVE');
  elsif goal = 'persuasion' then
    merged := merged
      || jsonb_build_object('turnout_max', 2, 'status', 'ACTIVE');
  end if;

  return public.find_voters(merged, 0, page_size);
end $$;
