#!/usr/bin/env python3
"""
vault_rotation.py — Vault lease renewal and secret rotation orchestrator
Renews leases expiring within threshold, logs all rotation events
Usage: python vault_rotation.py --vault-addr https://vault:8200 --threshold-hours 24
"""
import argparse
import json
import logging
import os
import sys
import time
from datetime import datetime, timezone

import hvac

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [vault_rotation] %(message)s"
)
log = logging.getLogger(__name__)


def get_vault_client(addr, token=None, role=None):
    client = hvac.Client(url=addr)
    if token:
        client.token = token
    elif role:
        # Kubernetes auth
        with open("/var/run/secrets/kubernetes.io/serviceaccount/token") as f:
            jwt = f.read()
        resp = client.auth.kubernetes.login(role=role, jwt=jwt)
        client.token = resp["auth"]["client_token"]
        log.info(f"Authenticated via Kubernetes auth, role={role}")
    else:
        client.token = os.environ.get("VAULT_TOKEN")
    if not client.is_authenticated():
        raise RuntimeError("Vault authentication failed")
    return client


def list_leases(client, prefix):
    try:
        resp = client.sys.list_leases(prefix=prefix)
        return resp.get("data", {}).get("keys", [])
    except Exception as e:
        log.warning(f"Could not list leases under {prefix}: {e}")
        return []


def renew_lease(client, lease_id, increment=3600):
    try:
        resp = client.sys.renew_lease(lease_id=lease_id, increment=increment)
        ttl = resp.get("lease_duration", 0)
        log.info(f"Renewed lease {lease_id} — new TTL: {ttl}s")
        return {"lease_id": lease_id, "status": "renewed", "new_ttl": ttl}
    except Exception as e:
        log.error(f"Failed to renew lease {lease_id}: {e}")
        return {"lease_id": lease_id, "status": "failed", "error": str(e)}


def lookup_lease_ttl(client, lease_id):
    try:
        resp = client.sys.read_lease(lease_id=lease_id)
        return resp.get("data", {}).get("ttl", 99999)
    except Exception:
        return 99999


def main():
    parser = argparse.ArgumentParser(description="Vault Lease Rotation Orchestrator")
    parser.add_argument("--vault-addr",       default=os.environ.get("VAULT_ADDR", "http://localhost:8200"))
    parser.add_argument("--vault-token",      default=os.environ.get("VAULT_TOKEN"))
    parser.add_argument("--k8s-role",         default=None,  help="Vault Kubernetes auth role")
    parser.add_argument("--lease-prefix",     default="",    help="Lease path prefix to scan")
    parser.add_argument("--threshold-hours",  type=int, default=24, help="Renew leases expiring within N hours")
    parser.add_argument("--dry-run",          action="store_true")
    args = parser.parse_args()

    threshold_seconds = args.threshold_hours * 3600
    log.info(f"Vault rotation starting — addr={args.vault_addr}, threshold={args.threshold_hours}h, dry_run={args.dry_run}")

    client = get_vault_client(args.vault_addr, args.vault_token, args.k8s_role)

    leases = list_leases(client, args.lease_prefix)
    log.info(f"Found {len(leases)} leases under prefix '{args.lease_prefix}'")

    results = []
    renewed = 0
    skipped = 0
    failed  = 0

    for lease_key in leases:
        lease_id = f"{args.lease_prefix}{lease_key}"
        ttl = lookup_lease_ttl(client, lease_id)

        if ttl <= threshold_seconds:
            log.info(f"Lease {lease_id} TTL={ttl}s — below threshold, renewing")
            if args.dry_run:
                log.info(f"DRY RUN — would renew {lease_id}")
                results.append({"lease_id": lease_id, "status": "dry_run", "ttl": ttl})
            else:
                result = renew_lease(client, lease_id)
                results.append(result)
                if result["status"] == "renewed":
                    renewed += 1
                else:
                    failed += 1
        else:
            skipped += 1

    summary = {
        "timestamp":  datetime.now(timezone.utc).isoformat(),
        "total":      len(leases),
        "renewed":    renewed,
        "skipped":    skipped,
        "failed":     failed,
        "results":    results,
    }

    print(json.dumps(summary, indent=2))
    log.info(f"Done — renewed={renewed}, skipped={skipped}, failed={failed}")

    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
