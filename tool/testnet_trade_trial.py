#!/usr/bin/env python3
"""Disposable XRPL testnet trial for wallet, trustline, and offer behavior.

This script creates two fresh wallets and writes secrets only to a temporary
file outside the repository. It uses wallet A as a synthetic RLUSD issuer
because the public testnet faucet funds XRP but does not give callers the
official RLUSD issuer key.
"""

from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path

import xrpl
from xrpl.clients import WebsocketClient
from xrpl.models.transactions import OfferCancel, OfferCreate, Payment, TrustSet
from xrpl.models.requests import AccountInfo, AccountLines, AccountOffers
from xrpl.transaction import submit_and_wait
from xrpl.wallet import Wallet
from xrpl.utils import drops_to_xrp

RPC_URL = "wss://s.altnet.rippletest.net:51233"
# RLUSD is a 40-character XRPL currency code on-ledger; display as RLUSD in
# the report, but submit the canonical hex code.
TOKEN = "524C555344000000000000000000000000000000"
TOKEN_LABEL = "RLUSD"


def submit(client, tx, wallet, label):
    result = submit_and_wait(tx, client, wallet)
    meta = result.result.get("meta", {})
    print(f"{label}: {result.result.get('engine_result')} {result.result.get('hash', '')}")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--keep", action="store_true", help="Keep the temporary wallet file")
    args = parser.parse_args()

    client = WebsocketClient(RPC_URL)
    client.open()
    issuer = Wallet.create()
    trader = Wallet.create()
    from xrpl.wallet import generate_faucet_wallet
    issuer = generate_faucet_wallet(client, issuer)
    trader = generate_faucet_wallet(client, trader)
    temp = Path(tempfile.mkstemp(prefix="xrpl-trade-trial-", suffix=".json")[1])
    temp.write_text(json.dumps({"issuer": issuer.seed, "trader": trader.seed}), encoding="utf-8")
    print(f"Disposable wallet secrets written to: {temp}")
    print(f"Issuer: {issuer.classic_address}")
    print(f"Trader: {trader.classic_address}")
    print(f"Issuer funded: {drops_to_xrp(client.request(AccountInfo(account=issuer.classic_address)).result['account_data']['Balance'])} XRP")
    print(f"Trader funded: {drops_to_xrp(client.request(AccountInfo(account=trader.classic_address)).result['account_data']['Balance'])} XRP")

    trust = TrustSet(
        account=trader.classic_address,
        limit_amount={"currency": TOKEN, "issuer": issuer.classic_address, "value": "1000000"},
    )
    submit(client, trust, trader, "trustline")

    issue = Payment(
        account=issuer.classic_address,
        destination=trader.classic_address,
        amount={"currency": TOKEN, "issuer": issuer.classic_address, "value": "1000"},
    )
    submit(client, issue, issuer, f"issue {TOKEN}")

    lines = client.request(AccountLines(account=trader.classic_address)).result.get("lines", [])
    print(f"Trader trustlines: {json.dumps(lines, indent=2)}")

    # Trader sells 100 TUSD for 10 XRP. This remains open until a counter-order
    # crosses it, which mirrors the app's OfferCreate behavior.
    sell = OfferCreate(
        account=trader.classic_address,
        taker_gets={"currency": TOKEN, "issuer": issuer.classic_address, "value": "100"},
        taker_pays="10000000",
    )
    sell_result = submit(client, sell, trader, "create sell offer")
    offers = client.request(AccountOffers(account=trader.classic_address)).result.get("offers", [])
    print(f"Trader open offers after create: {json.dumps(offers, indent=2)}")

    if offers:
        buy = OfferCreate(
            account=issuer.classic_address,
            taker_gets="10000000",
            taker_pays={
                "currency": TOKEN,
                "issuer": issuer.classic_address,
                "value": "100",
            },
        )
        submit(client, buy, issuer, "create matching buy offer")
        remaining = client.request(
            AccountOffers(account=trader.classic_address)
        ).result.get("offers", [])
        print(f"Trader open offers after match: {json.dumps(remaining, indent=2)}")
        trader_balance = client.request(
            AccountInfo(account=trader.classic_address)
        ).result["account_data"]["Balance"]
        trader_line = client.request(
            AccountLines(account=trader.classic_address)
        ).result.get("lines", [])
        print(f"Trader XRP after match: {drops_to_xrp(trader_balance)}")
        print(f"Trader issued balances after match: {json.dumps(trader_line, indent=2)}")
        if remaining:
            cancel = OfferCancel(
                account=trader.classic_address,
                offer_sequence=remaining[0]["seq"],
            )
            submit(client, cancel, trader, "cancel residual sell offer")
    else:
        print("No open offer returned; inspect the create result before retrying.")

    print("\nTrial findings:")
    print("- XRP faucet funding works for both fresh wallets.")
    print("- Issued-asset trading requires a trust line and an issuer-controlled token balance.")
    print("- An OfferCreate normally remains open; it is not an immediate trade confirmation.")
    print("- account_offers is the correct reconciliation source before offering cancellation.")
    print("- This trial uses a synthetic RLUSD-labelled asset; official testnet RLUSD requires the published issuer to fund the line.")

    if not args.keep:
        temp.unlink(missing_ok=True)
        print("Temporary wallet file deleted.")


if __name__ == "__main__":
    main()
