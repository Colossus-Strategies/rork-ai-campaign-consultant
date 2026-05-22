"""
Ohio Secretary of State voter file ingest — REST API edition.

Pulls the public statewide voter snapshot (county CSVs) from the OH SoS portal,
normalizes it to the Colossus schema, and upserts into Supabase via the
PostgREST REST API using the service-role key. No direct Postgres connection
is required, so this runs anywhere that can reach https://*.supabase.co.

Environment:
  SUPABASE_URL                 e.g. https://abcdefgh.supabase.co
  SUPABASE_SERVICE_ROLE_KEY    service_role JWT (bypasses RLS)
  OH_COUNTIES                  Optional comma-separated county filter.
                               Defaults to all 88 Ohio counties.
  OH_BASE_URL                  Override for the SoS download host.
  DRY_RUN                      "1" to skip writes.

Schema reference: ios/AICampaignConsultant/Services/VoterDataSchema.sql
"""

from __future__ import annotations

import csv
import io
import json
import logging
import os
import sys
import time
import uuid
import zipfile
from dataclasses import dataclass, asdict
from datetime import date, datetime, timezone
from typing import Any, Iterable, Iterator

import requests
from dateutil.parser import parse as parse_date

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("oh_ingest")

OH_BASE_URL = os.environ.get(
    "OH_BASE_URL",
    "https://www6.ohiosos.gov/ords/f?p=VOTERFTP:DOWNLOAD::FILE:NO:RP:P1_TYPE,P1_NAME:CTY,",
)

OH_ALL_COUNTIES = [
    "ADAMS","ALLEN","ASHLAND","ASHTABULA","ATHENS","AUGLAIZE","BELMONT","BROWN",
    "BUTLER","CARROLL","CHAMPAIGN","CLARK","CLERMONT","CLINTON","COLUMBIANA",
    "COSHOCTON","CRAWFORD","CUYAHOGA","DARKE","DEFIANCE","DELAWARE","ERIE",
    "FAIRFIELD","FAYETTE","FRANKLIN","FULTON","GALLIA","GEAUGA","GREENE",
    "GUERNSEY","HAMILTON","HANCOCK","HARDIN","HARRISON","HENRY","HIGHLAND",
    "HOCKING","HOLMES","HURON","JACKSON","JEFFERSON","KNOX","LAKE","LAWRENCE",
    "LICKING","LOGAN","LORAIN","LUCAS","MADISON","MAHONING","MARION","MEDINA",
    "MEIGS","MERCER","MIAMI","MONROE","MONTGOMERY","MORGAN","MORROW",
    "MUSKINGUM","NOBLE","OTTAWA","PAULDING","PERRY","PICKAWAY","PIKE","PORTAGE",
    "PREBLE","PUTNAM","RICHLAND","ROSS","SANDUSKY","SCIOTO","SENECA","SHELBY",
    "STARK","SUMMIT","TRUMBULL","TUSCARAWAS","UNION","VAN_WERT","VINTON",
    "WARREN","WASHINGTON","WAYNE","WILLIAMS","WOOD","WYANDOT",
]

BATCH_SIZE = 1000
DRY_RUN = os.environ.get("DRY_RUN") == "1"

# ---------------------------------------------------------------------------
# Ohio SoS column mapping
# ---------------------------------------------------------------------------

COL_SOS_ID         = "SOS_VOTERID"
COL_FIRST          = "FIRST_NAME"
COL_MIDDLE         = "MIDDLE_NAME"
COL_LAST           = "LAST_NAME"
COL_SUFFIX         = "SUFFIX"
COL_DOB            = "DATE_OF_BIRTH"
COL_REG_DATE       = "REGISTRATION_DATE"
COL_PARTY          = "PARTY_AFFILIATION"
COL_STATUS         = "VOTER_STATUS"
COL_COUNTY         = "COUNTY_NUMBER"
COL_COUNTY_NAME    = "COUNTY_ID"
COL_PRECINCT       = "PRECINCT_CODE"
COL_CONG_DIST      = "CONGRESSIONAL_DISTRICT"
COL_STATE_SEN_DIST = "STATE_SENATE_DISTRICT"
COL_STATE_REP_DIST = "STATE_REPRESENTATIVE_DISTRICT"
COL_ADDR           = "RESIDENTIAL_ADDRESS1"
COL_CITY           = "RESIDENTIAL_CITY"
COL_ZIP            = "RESIDENTIAL_ZIP"

# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------


@dataclass
class VoterRow:
    state_code: str
    external_voterid: str
    first_name: str | None
    middle_name: str | None
    last_name: str | None
    suffix: str | None
    dob: str | None
    registration_date: str | None
    party_affiliation: str | None
    voter_status: str | None
    county: str | None
    precinct_code: str | None
    congressional_district: str | None
    state_senate_district: str | None
    state_rep_district: str | None
    residential_address: str | None
    city: str | None
    zip: str | None


@dataclass
class HistoryRow:
    external_voterid: str
    election_date: str
    election_type: str  # GENERAL / PRIMARY / SPECIAL
    party_voted: str | None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _safe_date_str(value: str | None) -> str | None:
    if not value:
        return None
    try:
        return parse_date(value).date().isoformat()
    except (ValueError, TypeError, OverflowError):
        return None


def _nz(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip()
    return value or None


def _classify_election(col: str) -> tuple[str, str] | None:
    """Detects election-history columns of the form '<TYPE>_<MM/DD/YYYY>'."""
    if "_" not in col:
        return None
    prefix, rest = col.split("_", 1)
    prefix_upper = prefix.upper()
    if prefix_upper not in ("GENERAL", "PRIMARY", "SPECIAL"):
        return None
    parsed = _safe_date_str(rest)
    if not parsed:
        return None
    return prefix_upper, parsed


BROWSER_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "application/zip,application/octet-stream,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www6.ohiosos.gov/ords/f?p=VOTERFTP:HOME",
}


def fetch_county(county: str) -> bytes:
    """Download a single county voter file (zip or csv) from the OH SoS portal."""
    url = f"{OH_BASE_URL}{county}"
    log.info("downloading %s", url)
    resp = requests.get(url, timeout=180, stream=True, headers=BROWSER_HEADERS, allow_redirects=True)
    resp.raise_for_status()
    return resp.content


def iter_csv_from_zip(payload: bytes) -> Iterator[dict[str, str]]:
    """Yield CSV rows out of the SoS county download (zip-of-csv or raw csv)."""
    try:
        with zipfile.ZipFile(io.BytesIO(payload)) as zf:
            csv_names = [n for n in zf.namelist() if n.lower().endswith(".csv")]
            if not csv_names:
                raise RuntimeError("no CSV inside zip")
            for name in csv_names:
                with zf.open(name) as f:
                    reader = csv.DictReader(io.TextIOWrapper(f, encoding="utf-8-sig", errors="replace"))
                    yield from reader
    except zipfile.BadZipFile:
        reader = csv.DictReader(io.StringIO(payload.decode("utf-8-sig", errors="replace")))
        yield from reader


def parse_rows(county: str, raw_rows: Iterable[dict[str, str]]) -> Iterator[tuple[VoterRow, list[HistoryRow]]]:
    for raw in raw_rows:
        ext_id = _nz(raw.get(COL_SOS_ID))
        if not ext_id:
            continue

        voter = VoterRow(
            state_code="OH",
            external_voterid=ext_id,
            first_name=_nz(raw.get(COL_FIRST)),
            middle_name=_nz(raw.get(COL_MIDDLE)),
            last_name=_nz(raw.get(COL_LAST)),
            suffix=_nz(raw.get(COL_SUFFIX)),
            dob=_safe_date_str(raw.get(COL_DOB)),
            registration_date=_safe_date_str(raw.get(COL_REG_DATE)),
            party_affiliation=_nz(raw.get(COL_PARTY)),
            voter_status=_nz(raw.get(COL_STATUS)),
            county=_nz(raw.get(COL_COUNTY_NAME)) or county,
            precinct_code=_nz(raw.get(COL_PRECINCT)),
            congressional_district=_nz(raw.get(COL_CONG_DIST)),
            state_senate_district=_nz(raw.get(COL_STATE_SEN_DIST)),
            state_rep_district=_nz(raw.get(COL_STATE_REP_DIST)),
            residential_address=_nz(raw.get(COL_ADDR)),
            city=_nz(raw.get(COL_CITY)),
            zip=_nz(raw.get(COL_ZIP)),
        )

        history: list[HistoryRow] = []
        for col_name, value in raw.items():
            if not value or not _nz(value):
                continue
            classified = _classify_election(col_name)
            if not classified:
                continue
            etype, edate = classified
            history.append(HistoryRow(
                external_voterid=ext_id,
                election_date=edate,
                election_type=etype,
                party_voted=_nz(value),
            ))

        yield voter, history


# ---------------------------------------------------------------------------
# Supabase REST client
# ---------------------------------------------------------------------------


class SupabaseRest:
    def __init__(self, url: str, service_key: str):
        self.base = url.rstrip("/") + "/rest/v1"
        self.session = requests.Session()
        self.session.headers.update({
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json",
        })

    def upsert(
        self,
        table: str,
        rows: list[dict[str, Any]],
        on_conflict: str,
        returning: bool = False,
    ) -> list[dict[str, Any]]:
        """POST to /rest/v1/{table} with on_conflict resolution.

        Returns the representation rows if `returning=True`, else [].
        """
        if not rows:
            return []
        prefer_parts = ["resolution=merge-duplicates"]
        prefer_parts.append("return=representation" if returning else "return=minimal")
        headers = {"Prefer": ",".join(prefer_parts)}
        params = {"on_conflict": on_conflict}
        url = f"{self.base}/{table}"

        # Retry transient errors a few times.
        last_exc: Exception | None = None
        for attempt in range(4):
            try:
                resp = self.session.post(
                    url, params=params, headers=headers,
                    data=json.dumps(rows, default=str), timeout=180,
                )
            except requests.RequestException as exc:
                last_exc = exc
                log.warning("POST %s attempt %d failed: %s", table, attempt + 1, exc)
                time.sleep(2 ** attempt)
                continue

            if resp.status_code >= 500 or resp.status_code == 429:
                last_exc = RuntimeError(f"{resp.status_code}: {resp.text[:300]}")
                log.warning("POST %s attempt %d -> %s; retrying", table, attempt + 1, resp.status_code)
                time.sleep(2 ** attempt)
                continue

            if resp.status_code >= 400:
                raise RuntimeError(f"{table} upsert failed: {resp.status_code} {resp.text[:500]}")

            if returning:
                try:
                    return resp.json()
                except ValueError:
                    return []
            return []

        raise RuntimeError(f"{table} upsert exhausted retries: {last_exc}")


# ---------------------------------------------------------------------------
# Upsert orchestration
# ---------------------------------------------------------------------------


def _voter_payload(v: VoterRow) -> dict[str, Any]:
    payload = asdict(v)
    payload["updated_at"] = datetime.now(timezone.utc).isoformat()
    return payload


def upsert_county(client: SupabaseRest, county: str, rows: Iterable[tuple[VoterRow, list[HistoryRow]]]) -> tuple[int, int]:
    """Upsert one county's voters + history via REST. Returns (voters, history)."""
    voter_count = 0
    history_count = 0

    voter_buf: list[VoterRow] = []
    history_buf: list[tuple[str, HistoryRow]] = []  # (external_voterid, row)

    def flush() -> None:
        nonlocal voter_count, history_count
        if not voter_buf:
            return

        voter_payloads = [_voter_payload(v) for v in voter_buf]
        returned = client.upsert(
            "voters", voter_payloads,
            on_conflict="state_code,external_voterid",
            returning=True,
        )
        voter_count += len(voter_buf)

        id_map: dict[str, str] = {}
        for row in returned:
            ext = row.get("external_voterid")
            vid = row.get("id")
            if ext and vid:
                id_map[ext] = vid

        history_payloads = [
            {
                "voter_id": id_map[ext_id],
                "election_date": h.election_date,
                "election_type": h.election_type,
                "party_voted": h.party_voted,
            }
            for ext_id, h in history_buf
            if ext_id in id_map
        ]
        if history_payloads:
            # Chunk history so we don't ship 30k rows in one request.
            for i in range(0, len(history_payloads), BATCH_SIZE):
                chunk = history_payloads[i:i + BATCH_SIZE]
                client.upsert(
                    "voter_history", chunk,
                    on_conflict="voter_id,election_date",
                    returning=False,
                )
                history_count += len(chunk)

        voter_buf.clear()
        history_buf.clear()

    for voter, history in rows:
        voter_buf.append(voter)
        for h in history:
            history_buf.append((voter.external_voterid, h))
        if len(voter_buf) >= BATCH_SIZE:
            flush()

    flush()
    log.info("[%s] upserted %d voters, %d history rows", county, voter_count, history_count)
    return voter_count, history_count


# ---------------------------------------------------------------------------
# Ingest run logging
# ---------------------------------------------------------------------------


def log_run(client: SupabaseRest, **kw: Any) -> None:
    """Best-effort insert into voter_ingest_runs."""
    payload = {
        "run_id": kw["run_id"],
        "state_code": kw.get("state_code", "OH"),
        "county": kw.get("county"),
        "status": kw["status"],
        "rows_upserted": kw.get("rows_upserted", 0),
        "history_upserted": kw.get("history_upserted", 0),
        "error": kw.get("error"),
        "started_at": kw["started_at"],
        "ended_at": kw.get("ended_at"),
    }
    try:
        # Plain insert (no conflict target needed) — POST without Prefer merge.
        resp = client.session.post(
            f"{client.base}/voter_ingest_runs",
            data=json.dumps(payload, default=str),
            headers={"Prefer": "return=minimal"},
            timeout=60,
        )
        if resp.status_code >= 400:
            log.warning("voter_ingest_runs insert failed: %s %s", resp.status_code, resp.text[:300])
    except Exception as exc:  # noqa: BLE001
        log.warning("failed to log ingest run: %s", exc)


def try_refresh_materialized_view(client: SupabaseRest) -> None:
    """Refresh district_voter_summary via RPC if exposed; otherwise no-op."""
    url = f"{client.base}/rpc/refresh_district_voter_summary"
    try:
        resp = client.session.post(url, data="{}", timeout=120)
        if resp.status_code < 400:
            log.info("refreshed district_voter_summary via RPC")
            return
        if resp.status_code == 404:
            log.warning(
                "RPC refresh_district_voter_summary not found — skipping MV refresh. "
                "Run `refresh materialized view public.district_voter_summary;` "
                "in Supabase SQL editor after the ingest finishes."
            )
            return
        log.warning("MV refresh RPC failed: %s %s", resp.status_code, resp.text[:300])
    except Exception as exc:  # noqa: BLE001
        log.warning("MV refresh RPC error: %s", exc)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main() -> int:
    supabase_url = os.environ.get("SUPABASE_URL")
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not supabase_url or not service_key:
        log.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required")
        return 2

    counties_env = os.environ.get("OH_COUNTIES")
    counties = [c.strip().upper() for c in counties_env.split(",") if c.strip()] if counties_env else OH_ALL_COUNTIES

    log.info("starting OH ingest for %d counties (dry_run=%s)", len(counties), DRY_RUN)
    started = time.monotonic()
    total_voters = 0
    total_history = 0

    if DRY_RUN:
        for county in counties:
            try:
                payload = fetch_county(county)
            except requests.HTTPError as exc:
                log.warning("[%s] download failed: %s", county, exc)
                continue
            count = sum(1 for _ in parse_rows(county, iter_csv_from_zip(payload)))
            log.info("[%s] parsed %d rows (dry run)", county, count)
        return 0

    client = SupabaseRest(supabase_url, service_key)
    run_id = str(uuid.uuid4())
    failed_counties = 0

    for county in counties:
        started_at = datetime.now(timezone.utc).isoformat()
        try:
            payload = fetch_county(county)
        except requests.HTTPError as exc:
            log.warning("[%s] download failed: %s", county, exc)
            failed_counties += 1
            log_run(
                client, run_id=run_id, county=county, status="failed",
                error=f"download: {exc}",
                started_at=started_at,
                ended_at=datetime.now(timezone.utc).isoformat(),
            )
            continue
        try:
            rows = parse_rows(county, iter_csv_from_zip(payload))
            v, h = upsert_county(client, county, rows)
            total_voters += v
            total_history += h
            log_run(
                client, run_id=run_id, county=county, status="success",
                rows_upserted=v, history_upserted=h,
                started_at=started_at,
                ended_at=datetime.now(timezone.utc).isoformat(),
            )
        except Exception as exc:  # noqa: BLE001
            log.exception("[%s] ingest failed", county)
            failed_counties += 1
            log_run(
                client, run_id=run_id, county=county, status="failed",
                error=f"upsert: {exc}"[:500],
                started_at=started_at,
                ended_at=datetime.now(timezone.utc).isoformat(),
            )

    try_refresh_materialized_view(client)

    overall_started = datetime.fromtimestamp(
        time.time() - (time.monotonic() - started), tz=timezone.utc
    ).isoformat()
    log_run(
        client, run_id=run_id, county=None,
        status="failed" if failed_counties == len(counties) else "success",
        rows_upserted=total_voters, history_upserted=total_history,
        error=f"{failed_counties} county failures" if failed_counties else None,
        started_at=overall_started,
        ended_at=datetime.now(timezone.utc).isoformat(),
    )

    elapsed = time.monotonic() - started
    log.info("done: %d voters, %d history rows in %.1fs", total_voters, total_history, elapsed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
