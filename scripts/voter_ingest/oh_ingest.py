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
  OH_VOTER_FILE_BASE_URL       Optional mirror base URL. When set, county zips
                               are fetched as `{base}/{COUNTY}.zip` instead of
                               from the Ohio SoS portal. Use this to point at
                               a Supabase Storage bucket (or any HTTPS host)
                               that mirrors the SoS zips, bypassing the SoS
                               anti-bot 403 on GitHub Actions IPs.
  OH_COMBINED_FILE             Optional path to a single CSV containing rows
                               for ALL counties at once (e.g.
                               ohio_voters_combined.csv). When set, the
                               script streams the file, groups rows by their
                               COUNTY_ID column, and upserts per-county in
                               batches — no per-county splitting needed.
  OH_COMBINED_URL              Optional HTTPS URL to download the combined
                               file from before ingesting. Accepts either a
                               plain `.csv` or a `.zip` containing one CSV.
                               Works with Supabase Storage signed URLs and
                               private buckets (the service-role key is sent
                               as a bearer token when the URL points at
                               `/storage/v1/`).
  OH_SUPABASE_STORAGE_URL      Alias of OH_COMBINED_URL. Use this when pasting
                               a Supabase Storage signed URL (e.g.
                               .../storage/v1/object/sign/Voter%20Data/
                               ohio_voters_combined.csv.zip). If both are set,
                               OH_SUPABASE_STORAGE_URL wins.
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


def _load_dotenv_files() -> None:
    """Auto-load `.env` files (without overriding already-set env vars).

    Looks in (in order): the script directory, its parent (scripts/), and the
    current working directory. This makes `OH_SUPABASE_STORAGE_URL=...` in a
    local `.env` Just Work without forcing the user to `export` it manually.
    """
    here = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(here, ".env"),
        os.path.join(os.path.dirname(here), ".env"),
        os.path.join(os.getcwd(), ".env"),
    ]
    seen: set[str] = set()
    for path in candidates:
        path = os.path.abspath(path)
        if path in seen or not os.path.isfile(path):
            continue
        seen.add(path)
        try:
            with open(path, "r", encoding="utf-8") as fh:
                for raw in fh:
                    line = raw.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    if line.lower().startswith("export "):
                        line = line[7:].lstrip()
                    k, _, v = line.partition("=")
                    k = k.strip()
                    v = v.strip().strip('"').strip("'")
                    if k and k not in os.environ:
                        os.environ[k] = v
            log.info("loaded env from %s", path)
        except Exception as exc:  # noqa: BLE001
            log.warning("could not read %s: %s", path, exc)


_load_dotenv_files()

OH_BASE_URL = os.environ.get(
    "OH_BASE_URL",
    "https://www6.ohiosos.gov/ords/f?p=VOTERFTP:DOWNLOAD::FILE:NO:RP:P1_TYPE,P1_NAME:CTY,",
)

# When set, county files are fetched from this mirror (e.g. Supabase Storage)
# instead of the Ohio SoS portal. Expected layout: `{base}/{COUNTY}.zip`.
OH_MIRROR_BASE_URL = os.environ.get("OH_VOTER_FILE_BASE_URL", "").rstrip("/")

# When set, county files are read from this local directory instead of any
# network source. Expected layout: `{dir}/{COUNTY}.zip` (case-insensitive),
# or a single `.csv` with the same stem.
# NOTE: these names are kept here purely as documentation. The actual values
# are resolved fresh inside main() via _resolve_sources() so that env vars set
# after import (e.g. through a .env loader or a wrapping script) are still
# picked up. Do NOT read these globals elsewhere — call _resolve_sources().
OH_LOCAL_DIR = ""
OH_COMBINED_FILE = ""
OH_COMBINED_URL = ""


def _resolve_sources() -> dict[str, str]:
    """Resolve all source-selection env vars at call time.

    Returns a dict with the chosen values plus a `chosen` key indicating which
    source the script will use: one of `combined_url`, `combined_file`,
    `local_dir`, `mirror`, or `sos`.
    """
    local_dir     = os.environ.get("OH_LOCAL_DIR", "").strip()
    combined_file = os.environ.get("OH_COMBINED_FILE", "").strip()
    combined_url  = (
        os.environ.get("OH_SUPABASE_STORAGE_URL", "").strip()
        or os.environ.get("OH_COMBINED_URL", "").strip()
    )
    mirror_base   = os.environ.get("OH_VOTER_FILE_BASE_URL", "").strip().rstrip("/")

    if combined_url:
        chosen = "combined_url"
    elif combined_file:
        chosen = "combined_file"
    elif local_dir:
        chosen = "local_dir"
    elif mirror_base:
        chosen = "mirror"
    else:
        chosen = "sos"

    return {
        "chosen": chosen,
        "combined_url": combined_url,
        "combined_file": combined_file,
        "local_dir": local_dir,
        "mirror_base": mirror_base,
    }

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
    "Accept": (
        "text/html,application/xhtml+xml,application/xml;q=0.9,"
        "application/zip,application/octet-stream,*/*;q=0.8"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "Upgrade-Insecure-Requests": "1",
    "Sec-Fetch-Site": "same-origin",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-User": "?1",
    "Sec-Fetch-Dest": "document",
}

OH_HOME_URL = "https://www6.ohiosos.gov/ords/f?p=VOTERFTP:HOME"

_OH_SESSION: requests.Session | None = None


def _get_oh_session() -> requests.Session:
    """Return a requests.Session warmed up against the OH SoS APEX portal.

    Oracle APEX (the platform behind www6.ohiosos.gov) refuses any request
    that doesn't carry a valid ORA_WWV_* session cookie, returning 403 for
    direct hits on f?p=VOTERFTP:DOWNLOAD URLs. We have to GET the public
    HOME page first so APEX issues us those cookies, then reuse the session.
    """
    global _OH_SESSION
    if _OH_SESSION is not None:
        return _OH_SESSION

    s = requests.Session()
    s.headers.update(BROWSER_HEADERS)
    log.info("warming up OH SoS session via %s", OH_HOME_URL)
    try:
        r = s.get(OH_HOME_URL, timeout=60, allow_redirects=True)
        log.info("OH session warm-up: %s (cookies: %s)", r.status_code, ",".join(s.cookies.keys()) or "none")
    except requests.RequestException as exc:
        log.warning("OH session warm-up failed: %s (continuing anyway)", exc)
    _OH_SESSION = s
    return s


def fetch_county(county: str) -> bytes:
    """Download a single county voter file (zip or csv).

    Prefers a local directory (OH_LOCAL_DIR) if set, then the
    OH_VOTER_FILE_BASE_URL mirror, otherwise hits the Ohio SoS portal
    directly (which 403s GitHub Actions IPs).
    """
    local_dir = os.environ.get("OH_LOCAL_DIR", "").strip()
    mirror_base = os.environ.get("OH_VOTER_FILE_BASE_URL", "").strip().rstrip("/")
    if local_dir:
        return _fetch_from_local_dir(county, local_dir)

    if mirror_base:
        return _fetch_from_mirror(county, mirror_base)

    url = f"{OH_BASE_URL}{county}"
    log.info("downloading %s", url)
    session = _get_oh_session()

    last_exc: Exception | None = None
    for attempt in range(3):
        try:
            resp = session.get(
                url,
                timeout=180,
                allow_redirects=True,
                headers={"Referer": OH_HOME_URL},
            )
        except requests.RequestException as exc:
            last_exc = exc
            log.warning("[%s] attempt %d network error: %s", county, attempt + 1, exc)
            time.sleep(2 ** attempt)
            continue

        if resp.status_code == 403:
            # Session may have expired or never validated — re-warm and retry.
            log.warning("[%s] attempt %d -> 403; re-warming session", county, attempt + 1)
            global _OH_SESSION
            _OH_SESSION = None
            session = _get_oh_session()
            time.sleep(1 + attempt)
            last_exc = requests.HTTPError(f"403 Forbidden for {url}")
            continue

        if resp.status_code >= 500 or resp.status_code == 429:
            last_exc = requests.HTTPError(f"{resp.status_code} for {url}")
            log.warning("[%s] attempt %d -> %s; retrying", county, attempt + 1, resp.status_code)
            time.sleep(2 ** attempt)
            continue

        resp.raise_for_status()
        return resp.content

    if last_exc:
        raise last_exc
    raise RuntimeError(f"unable to download {county}")


def _fetch_from_local_dir(county: str, local_dir: str = "") -> bytes:
    """Read a county voter file from a local directory."""
    base = os.path.expanduser(local_dir or os.environ.get("OH_LOCAL_DIR", ""))
    candidates = [
        os.path.join(base, f"{county}.zip"),
        os.path.join(base, f"{county.lower()}.zip"),
        os.path.join(base, f"{county}.CSV"),
        os.path.join(base, f"{county}.csv"),
        os.path.join(base, f"{county.lower()}.csv"),
    ]
    for path in candidates:
        if os.path.isfile(path):
            log.info("reading (local) %s", path)
            with open(path, "rb") as f:
                return f.read()
    raise FileNotFoundError(
        f"no local file for {county} in {base} (tried {', '.join(os.path.basename(c) for c in candidates)})"
    )


def _fetch_from_mirror(county: str, mirror_base: str = "") -> bytes:
    """Pull a county zip from the configured mirror (e.g. Supabase Storage)."""
    base = (mirror_base or os.environ.get("OH_VOTER_FILE_BASE_URL", "")).rstrip("/")
    url = f"{base}/{county}.zip"
    log.info("downloading (mirror) %s", url)

    headers: dict[str, str] = {}
    # If the mirror is a private Supabase Storage bucket, the service-role key
    # also works as a bearer token against `/storage/v1/object/...` URLs.
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if service_key and "/storage/v1/" in url:
        headers["Authorization"] = f"Bearer {service_key}"
        headers["apikey"] = service_key

    last_exc: Exception | None = None
    for attempt in range(3):
        try:
            resp = requests.get(url, headers=headers, timeout=180)
        except requests.RequestException as exc:
            last_exc = exc
            log.warning("[%s] mirror attempt %d network error: %s", county, attempt + 1, exc)
            time.sleep(2 ** attempt)
            continue

        if resp.status_code == 404:
            raise requests.HTTPError(f"404 Not Found for {url} — is the zip uploaded to the mirror?")

        if resp.status_code >= 500 or resp.status_code == 429:
            last_exc = requests.HTTPError(f"{resp.status_code} for {url}")
            log.warning("[%s] mirror attempt %d -> %s; retrying", county, attempt + 1, resp.status_code)
            time.sleep(2 ** attempt)
            continue

        resp.raise_for_status()
        return resp.content

    if last_exc:
        raise last_exc
    raise RuntimeError(f"unable to download {county} from mirror")


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


def _flush_voter_buffer(
    client: SupabaseRest,
    voter_buf: list[VoterRow],
    history_buf: list[tuple[str, HistoryRow]],
) -> tuple[int, int]:
    """Upsert one buffered batch of voters + their history. Returns (v, h)."""
    if not voter_buf:
        return 0, 0

    voter_payloads = [_voter_payload(v) for v in voter_buf]
    returned = client.upsert(
        "voters", voter_payloads,
        on_conflict="state_code,external_voterid",
        returning=True,
    )
    v_count = len(voter_buf)

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
    h_count = 0
    if history_payloads:
        for i in range(0, len(history_payloads), BATCH_SIZE):
            chunk = history_payloads[i:i + BATCH_SIZE]
            client.upsert(
                "voter_history", chunk,
                on_conflict="voter_id,election_date",
                returning=False,
            )
            h_count += len(chunk)

    voter_buf.clear()
    history_buf.clear()
    return v_count, h_count


def upsert_county(client: SupabaseRest, county: str, rows: Iterable[tuple[VoterRow, list[HistoryRow]]]) -> tuple[int, int]:
    """Upsert one county's voters + history via REST. Returns (voters, history)."""
    voter_count = 0
    history_count = 0

    voter_buf: list[VoterRow] = []
    history_buf: list[tuple[str, HistoryRow]] = []

    for voter, history in rows:
        voter_buf.append(voter)
        for h in history:
            history_buf.append((voter.external_voterid, h))
        if len(voter_buf) >= BATCH_SIZE:
            v, h = _flush_voter_buffer(client, voter_buf, history_buf)
            voter_count += v
            history_count += h

    v, h = _flush_voter_buffer(client, voter_buf, history_buf)
    voter_count += v
    history_count += h
    log.info("[%s] upserted %d voters, %d history rows", county, voter_count, history_count)
    return voter_count, history_count


def _iter_combined_csv(path: str) -> Iterator[dict[str, str]]:
    """Stream rows from a single combined CSV (all counties in one file).

    Transparently handles both raw `.csv` and `.zip` containing one CSV.
    """
    expanded = os.path.expanduser(path)
    log.info("reading combined file %s", expanded)
    if zipfile.is_zipfile(expanded):
        with zipfile.ZipFile(expanded) as zf:
            csv_names = [n for n in zf.namelist() if n.lower().endswith(".csv")]
            if not csv_names:
                raise RuntimeError(f"no CSV inside zip: {expanded}")
            for name in csv_names:
                log.info("reading combined CSV entry %s", name)
                with zf.open(name) as f:
                    reader = csv.DictReader(io.TextIOWrapper(f, encoding="utf-8-sig", errors="replace"))
                    for row in reader:
                        yield row
        return
    with open(expanded, "r", encoding="utf-8-sig", errors="replace", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            yield row


def download_combined_url(url: str) -> str:
    """Download the combined file from a URL to a local temp path; return that path.

    Streams to disk so we don't load the (potentially huge) payload into RAM.
    Sends Supabase auth headers when the URL targets `/storage/v1/`.
    """
    import tempfile
    from urllib.parse import urlparse

    parsed = urlparse(url)
    name = os.path.basename(parsed.path) or "ohio_voters_combined"
    suffix = ".zip" if name.lower().endswith(".zip") else ".csv"
    tmp_dir = tempfile.gettempdir()
    out_path = os.path.join(tmp_dir, f"oh_combined_{int(time.time())}{suffix}")

    headers: dict[str, str] = {}
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if service_key and "/storage/v1/" in url:
        headers["Authorization"] = f"Bearer {service_key}"
        headers["apikey"] = service_key

    log.info("downloading combined file %s -> %s", url, out_path)
    last_exc: Exception | None = None
    for attempt in range(3):
        try:
            with requests.get(url, headers=headers, timeout=600, stream=True) as resp:
                if resp.status_code == 404:
                    raise requests.HTTPError(f"404 Not Found for {url}")
                if resp.status_code >= 500 or resp.status_code == 429:
                    last_exc = requests.HTTPError(f"{resp.status_code} for {url}")
                    log.warning("combined download attempt %d -> %s; retrying", attempt + 1, resp.status_code)
                    time.sleep(2 ** attempt)
                    continue
                resp.raise_for_status()
                bytes_written = 0
                with open(out_path, "wb") as f:
                    for chunk in resp.iter_content(chunk_size=1024 * 1024):
                        if not chunk:
                            continue
                        f.write(chunk)
                        bytes_written += len(chunk)
                log.info("downloaded %d bytes to %s", bytes_written, out_path)
                return out_path
        except requests.RequestException as exc:
            last_exc = exc
            log.warning("combined download attempt %d network error: %s", attempt + 1, exc)
            time.sleep(2 ** attempt)

    if last_exc:
        raise last_exc
    raise RuntimeError(f"unable to download combined file from {url}")


def ingest_combined_file(
    client: SupabaseRest,
    path: str,
    county_filter: set[str] | None,
    run_id: str,
) -> tuple[int, int, int]:
    """Stream a single combined CSV and upsert per-county in batches.

    Returns (total_voters, total_history, failed_county_count).
    """
    # Per-county streaming buffers — flushed individually when they hit BATCH_SIZE.
    voter_bufs: dict[str, list[VoterRow]] = {}
    history_bufs: dict[str, list[tuple[str, HistoryRow]]] = {}
    started_by_county: dict[str, str] = {}
    totals_by_county: dict[str, tuple[int, int]] = {}

    total_v = 0
    total_h = 0

    def _start(county: str) -> None:
        if county not in voter_bufs:
            voter_bufs[county] = []
            history_bufs[county] = []
            started_by_county[county] = datetime.now(timezone.utc).isoformat()
            totals_by_county[county] = (0, 0)

    def _flush(county: str) -> None:
        nonlocal total_v, total_h
        v, h = _flush_voter_buffer(client, voter_bufs[county], history_bufs[county])
        cv, ch = totals_by_county[county]
        totals_by_county[county] = (cv + v, ch + h)
        total_v += v
        total_h += h

    raw_rows = _iter_combined_csv(path)
    seen_rows = 0
    for raw in raw_rows:
        seen_rows += 1
        # Combined CSVs may carry the county on each row; fall back to UNKNOWN.
        county = (_nz(raw.get(COL_COUNTY_NAME)) or "UNKNOWN").upper().replace(" ", "_")
        if county_filter and county not in county_filter:
            continue

        ext_id = _nz(raw.get(COL_SOS_ID))
        if not ext_id:
            continue

        # Reuse the same per-row parser as the per-county path.
        for voter, history in parse_rows(county, [raw]):
            _start(county)
            voter_bufs[county].append(voter)
            for h in history:
                history_bufs[county].append((voter.external_voterid, h))
            if len(voter_bufs[county]) >= BATCH_SIZE:
                _flush(county)

        if seen_rows % 50000 == 0:
            log.info("combined: scanned %d rows (%d counties touched so far)", seen_rows, len(voter_bufs))

    # Final flush for every county we touched.
    for county in list(voter_bufs.keys()):
        if voter_bufs[county]:
            _flush(county)
        cv, ch = totals_by_county[county]
        log.info("[%s] upserted %d voters, %d history rows", county, cv, ch)
        log_run(
            client, run_id=run_id, county=county, status="success",
            rows_upserted=cv, history_upserted=ch,
            started_at=started_by_county[county],
            ended_at=datetime.now(timezone.utc).isoformat(),
        )

    log.info("combined ingest complete: %d rows scanned, %d counties", seen_rows, len(voter_bufs))
    return total_v, total_h, 0


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

    # Resolve all source-selection env vars fresh, so anything set after import
    # (e.g. via a .env loader or a wrapping shell script) is honored.
    src = _resolve_sources()

    # Diagnostic dump so the user can see exactly what the script sees.
    def _mask(v: str) -> str:
        if not v:
            return "<unset>"
        return v if len(v) <= 80 else v[:60] + "…" + v[-12:]
    log.info("env: OH_SUPABASE_STORAGE_URL=%s", _mask(os.environ.get("OH_SUPABASE_STORAGE_URL", "")))
    log.info("env: OH_COMBINED_URL=%s",         _mask(os.environ.get("OH_COMBINED_URL", "")))
    log.info("env: OH_COMBINED_FILE=%s",        _mask(os.environ.get("OH_COMBINED_FILE", "")))
    log.info("env: OH_LOCAL_DIR=%s",            _mask(os.environ.get("OH_LOCAL_DIR", "")))
    log.info("env: OH_VOTER_FILE_BASE_URL=%s",  _mask(os.environ.get("OH_VOTER_FILE_BASE_URL", "")))
    log.info("resolved source = %s", src["chosen"])

    if src["chosen"] == "combined_url":
        log.info(
            "OH_SUPABASE_STORAGE_URL/OH_COMBINED_URL is set — skipping per-county SoS downloads and ingesting the combined file only"
        )
        source = f"combined_url={_mask(src['combined_url'])}"
    elif src["chosen"] == "combined_file":
        source = f"combined={src['combined_file']}"
    elif src["chosen"] == "local_dir":
        source = f"local={src['local_dir']}"
    elif src["chosen"] == "mirror":
        source = f"mirror={src['mirror_base']}"
    else:
        source = "source=ohiosos.gov"
    log.info("starting OH ingest for %d counties (dry_run=%s, %s)", len(counties), DRY_RUN, source)
    started = time.monotonic()
    total_voters = 0
    total_history = 0

    # Combined-CSV path: stream one giant file and route rows by county.
    combined_path = ""
    if src["chosen"] == "combined_url":
        try:
            combined_path = download_combined_url(src["combined_url"])
        except Exception as exc:  # noqa: BLE001
            log.exception("failed to download combined URL")
            return 1
    elif src["chosen"] == "combined_file":
        combined_path = src["combined_file"]

    if combined_path:
        if not os.path.isfile(os.path.expanduser(combined_path)):
            log.error("combined file does not exist: %s", combined_path)
            return 2

        county_filter: set[str] | None = None
        if counties_env:
            county_filter = {c for c in counties}
            log.info("combined: filtering to %d counties", len(county_filter))

        if DRY_RUN:
            counts: dict[str, int] = {}
            for raw in _iter_combined_csv(combined_path):
                county = (_nz(raw.get(COL_COUNTY_NAME)) or "UNKNOWN").upper().replace(" ", "_")
                if county_filter and county not in county_filter:
                    continue
                counts[county] = counts.get(county, 0) + 1
            for c, n in sorted(counts.items()):
                log.info("[%s] %d rows (dry run)", c, n)
            return 0

        client = SupabaseRest(supabase_url, service_key)
        run_id = str(uuid.uuid4())
        overall_started_iso = datetime.now(timezone.utc).isoformat()
        try:
            total_v, total_h, failed = ingest_combined_file(client, combined_path, county_filter, run_id)
        except Exception as exc:  # noqa: BLE001
            log.exception("combined ingest failed")
            log_run(
                client, run_id=run_id, county=None, status="failed",
                error=f"combined: {exc}"[:500],
                started_at=overall_started_iso,
                ended_at=datetime.now(timezone.utc).isoformat(),
            )
            return 1

        try_refresh_materialized_view(client)
        log_run(
            client, run_id=run_id, county=None,
            status="success" if failed == 0 else "failed",
            rows_upserted=total_v, history_upserted=total_h,
            error=None if failed == 0 else f"{failed} county failures",
            started_at=overall_started_iso,
            ended_at=datetime.now(timezone.utc).isoformat(),
        )
        elapsed = time.monotonic() - started
        log.info("done (combined): %d voters, %d history rows in %.1fs", total_v, total_h, elapsed)
        return 0

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
