"""
Mirror Ohio SoS county voter-file zips into Supabase Storage.

Run this from your laptop / a non-datacenter IP. The OH SoS APEX portal
403s GitHub Actions egress ranges, so we mirror the zips once into a
Supabase Storage bucket and have the GitHub Action read from there.

Usage:
    export SUPABASE_URL="https://YOUR-PROJECT.supabase.co"
    export SUPABASE_SERVICE_ROLE_KEY="eyJ..."
    # Optional: a specific subset; default is all 88 counties
    export OH_COUNTIES="TRUMBULL,CUYAHOGA"
    # Optional: bucket name (default: voter-files-oh)
    export OH_STORAGE_BUCKET="voter-files-oh"

    python scripts/voter_ingest/mirror_oh_to_supabase.py

After it finishes, set the GitHub secret:
    OH_VOTER_FILE_BASE_URL = https://YOUR-PROJECT.supabase.co/storage/v1/object/public/voter-files-oh
(if the bucket is public). For a private bucket, use the same path; the
ingest script will automatically attach the service-role key.
"""

from __future__ import annotations

import logging
import os
import sys
import time
from typing import Iterable

import requests

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("oh_mirror")

OH_BASE_URL = (
    "https://www6.ohiosos.gov/ords/f?p=VOTERFTP:DOWNLOAD::FILE:NO:RP:P1_TYPE,P1_NAME:CTY,"
)
OH_HOME_URL = "https://www6.ohiosos.gov/ords/f?p=VOTERFTP:HOME"

OH_ALL_COUNTIES = [
    "ADAMS", "ALLEN", "ASHLAND", "ASHTABULA", "ATHENS", "AUGLAIZE", "BELMONT", "BROWN",
    "BUTLER", "CARROLL", "CHAMPAIGN", "CLARK", "CLERMONT", "CLINTON", "COLUMBIANA",
    "COSHOCTON", "CRAWFORD", "CUYAHOGA", "DARKE", "DEFIANCE", "DELAWARE", "ERIE",
    "FAIRFIELD", "FAYETTE", "FRANKLIN", "FULTON", "GALLIA", "GEAUGA", "GREENE",
    "GUERNSEY", "HAMILTON", "HANCOCK", "HARDIN", "HARRISON", "HENRY", "HIGHLAND",
    "HOCKING", "HOLMES", "HURON", "JACKSON", "JEFFERSON", "KNOX", "LAKE", "LAWRENCE",
    "LICKING", "LOGAN", "LORAIN", "LUCAS", "MADISON", "MAHONING", "MARION", "MEDINA",
    "MEIGS", "MERCER", "MIAMI", "MONROE", "MONTGOMERY", "MORGAN", "MORROW",
    "MUSKINGUM", "NOBLE", "OTTAWA", "PAULDING", "PERRY", "PICKAWAY", "PIKE", "PORTAGE",
    "PREBLE", "PUTNAM", "RICHLAND", "ROSS", "SANDUSKY", "SCIOTO", "SENECA", "SHELBY",
    "STARK", "SUMMIT", "TRUMBULL", "TUSCARAWAS", "UNION", "VAN_WERT", "VINTON",
    "WARREN", "WASHINGTON", "WAYNE", "WILLIAMS", "WOOD", "WYANDOT",
]

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
    "Upgrade-Insecure-Requests": "1",
    "Sec-Fetch-Site": "same-origin",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-User": "?1",
    "Sec-Fetch-Dest": "document",
}


def warm_session() -> requests.Session:
    s = requests.Session()
    s.headers.update(BROWSER_HEADERS)
    log.info("warming OH session via %s", OH_HOME_URL)
    r = s.get(OH_HOME_URL, timeout=60, allow_redirects=True)
    log.info("warm-up: %s (cookies: %s)", r.status_code, ",".join(s.cookies.keys()) or "none")
    return s


def fetch_county_zip(session: requests.Session, county: str) -> bytes:
    url = f"{OH_BASE_URL}{county}"
    log.info("[%s] downloading from SoS", county)
    for attempt in range(3):
        resp = session.get(url, timeout=300, allow_redirects=True, headers={"Referer": OH_HOME_URL})
        if resp.status_code == 200 and resp.content:
            return resp.content
        log.warning("[%s] attempt %d -> %s", county, attempt + 1, resp.status_code)
        time.sleep(2 ** attempt)
    resp.raise_for_status()
    raise RuntimeError(f"unable to download {county}")


def ensure_bucket(supabase_url: str, service_key: str, bucket: str) -> None:
    """Create the storage bucket if it doesn't already exist (idempotent)."""
    url = f"{supabase_url.rstrip('/')}/storage/v1/bucket"
    headers = {
        "Authorization": f"Bearer {service_key}",
        "apikey": service_key,
        "Content-Type": "application/json",
    }
    body = {"id": bucket, "name": bucket, "public": True}
    resp = requests.post(url, json=body, headers=headers, timeout=30)
    if resp.status_code in (200, 201):
        log.info("created bucket %s (public)", bucket)
    elif resp.status_code == 409 or "already exists" in resp.text.lower():
        log.info("bucket %s already exists", bucket)
    else:
        log.warning("create bucket %s: %s %s", bucket, resp.status_code, resp.text[:200])


def upload_zip(supabase_url: str, service_key: str, bucket: str, county: str, payload: bytes) -> None:
    """Upload (upsert) a county zip into Supabase Storage."""
    key = f"{county}.zip"
    url = f"{supabase_url.rstrip('/')}/storage/v1/object/{bucket}/{key}"
    headers = {
        "Authorization": f"Bearer {service_key}",
        "apikey": service_key,
        "Content-Type": "application/zip",
        "x-upsert": "true",
        "Cache-Control": "max-age=3600",
    }
    resp = requests.post(url, data=payload, headers=headers, timeout=300)
    if resp.status_code >= 400:
        raise RuntimeError(f"upload {county}: {resp.status_code} {resp.text[:300]}")
    log.info("[%s] uploaded %.1f MB to %s/%s", county, len(payload) / 1_048_576, bucket, key)


def main() -> int:
    supabase_url = os.environ.get("SUPABASE_URL")
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not supabase_url or not service_key:
        log.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required")
        return 2

    bucket = os.environ.get("OH_STORAGE_BUCKET", "voter-files-oh")
    counties_env = os.environ.get("OH_COUNTIES")
    counties: Iterable[str] = (
        [c.strip().upper() for c in counties_env.split(",") if c.strip()]
        if counties_env else OH_ALL_COUNTIES
    )

    ensure_bucket(supabase_url, service_key, bucket)
    session = warm_session()

    ok = 0
    failed: list[str] = []
    for county in counties:
        try:
            payload = fetch_county_zip(session, county)
            upload_zip(supabase_url, service_key, bucket, county, payload)
            ok += 1
        except Exception as exc:  # noqa: BLE001
            log.exception("[%s] mirror failed: %s", county, exc)
            failed.append(county)

    log.info("done: %d uploaded, %d failed (%s)", ok, len(failed), ",".join(failed) or "none")
    public_base = f"{supabase_url.rstrip('/')}/storage/v1/object/public/{bucket}"
    log.info("set GitHub secret OH_VOTER_FILE_BASE_URL = %s", public_base)
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
