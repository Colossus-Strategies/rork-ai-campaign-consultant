# Ohio Voter File Ingest

Daily GitHub Actions worker that downloads the public Ohio Secretary of State
statewide voter file (county-by-county) and upserts it into the Supabase
schema defined in `ios/AICampaignConsultant/Services/VoterDataSchema.sql`.

## How it works

1. Workflow `.github/workflows/voter-ingest.yml` runs daily at 09:30 UTC.
2. `oh_ingest.py` fetches each of the 88 county CSV/zip files from the SoS
   download portal.
3. Each row is normalized and upserted into `public.voters` keyed by
   `(state_code, external_voterid)` via the Supabase REST API
   (PostgREST + service-role key, which bypasses RLS).
   Election-history columns (`GENERAL_…`, `PRIMARY_…`, `SPECIAL_…`) are
   exploded into `public.voter_history`.
4. After all counties land, the script calls the
   `refresh_district_voter_summary` RPC if present. If you haven't created
   that function, refresh the materialized view manually in the Supabase SQL
   editor:

   ```sql
   refresh materialized view public.district_voter_summary;
   ```

## Required GitHub secrets

| Secret | Value |
| --- | --- |
| `SUPABASE_URL` | Your project URL, e.g. `https://abcdefgh.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | The `service_role` JWT from Supabase → Project Settings → API. Bypasses RLS. Treat as secret. |

## Manual run

GitHub → Actions → **Ohio Voter File Ingest** → *Run workflow*.

- `counties`: e.g. `TRUMBULL,MAHONING` to limit (great for first-time test).
- `dry_run`: `true` to parse-only without touching the DB.

## Local run

```bash
cd scripts/voter_ingest
pip install -r requirements.txt
export SUPABASE_URL="https://<project>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."
export OH_COUNTIES="TRUMBULL"          # optional subset
export DRY_RUN=1                       # optional
python oh_ingest.py
```

## Adding a new state

1. Insert a row into `public.states` with the new state code + data-use notice.
2. Add a sibling script (e.g. `pa_ingest.py`) that produces the same
   `VoterRow` / `HistoryRow` shape with `state_code` set accordingly.
3. Wire a second job in the workflow. The schema and RLS already handle
   multi-state out of the box.

## Notes on the Ohio file format

The SoS publishes one file per county. Column names follow the
[Statewide Voter File spec](https://www.ohiosos.gov/elections/election-officials/voter-registration-statistics/).
Election-history columns appear as `GENERAL_11/05/2024`, `PRIMARY_03/19/2024`,
etc. — the parser detects them by prefix so new elections work automatically.
If Ohio ever changes a column name, update the `COL_*` constants at the top
of `oh_ingest.py`.
