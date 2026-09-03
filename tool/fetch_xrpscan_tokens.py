#!/usr/bin/env python3
"""Regenerate assets/tokens/xrpscan_tokens.json from XRPSCAN.

Source: https://xrpscan.com/tokens
API:    https://api.xrpscan.com/api/v1/tokens
"""

from __future__ import annotations

import argparse
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "assets" / "tokens" / "xrpscan_tokens.json"

HEADERS = {
    "User-Agent": "xrpl-mobile-wallet/1.0 (token catalog build; +https://xrpscan.com/tokens)",
    "Accept": "application/json",
}


def fetch_page(offset: int, limit: int) -> list:
    url = (
        "https://api.xrpscan.com/api/v1/tokens"
        f"?sort=score&direction=desc&limit={limit}&offset={offset}"
    )
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.load(resp)
    if not isinstance(data, list):
        raise RuntimeError(f"Unexpected response type: {type(data)}")
    return data


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pages", type=int, default=5, help="Pages of 100 tokens")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    entries: list[dict] = []
    seen: set[tuple[str, str]] = set()
    limit = 100
    for page in range(args.pages):
        offset = page * limit
        data = fetch_page(offset, limit)
        if not data:
            break
        for t in data:
            currency = (t.get("currency") or "").strip()
            issuer = (t.get("issuer") or "").strip()
            code = (t.get("code") or "").strip()
            meta = t.get("meta") or {}
            token_meta = meta.get("token") or {}
            name = (token_meta.get("name") or code or "").strip()
            if not currency or not issuer:
                continue
            key = (currency.upper(), issuer)
            if key in seen:
                continue
            seen.add(key)
            entries.append(
                {
                    "currency": currency,
                    "issuer": issuer,
                    "code": code or currency,
                    "name": name or code or currency,
                }
            )

    # Ensure mainnet RLUSD is present.
    rlusd = {
        "currency": "524C555344000000000000000000000000000000",
        "issuer": "rMxCKbEDwqr76QuheSUMdEGf4B9xJ8m5De",
        "code": "RLUSD",
        "name": "Ripple USD",
    }
    if (rlusd["currency"].upper(), rlusd["issuer"]) not in seen:
        entries.insert(0, rlusd)

    out = {
        "source": "https://api.xrpscan.com/api/v1/tokens",
        "docs": "https://xrpscan.com/tokens",
        "fetchedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "entries": entries,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(entries)} entries → {args.out}")


if __name__ == "__main__":
    main()
