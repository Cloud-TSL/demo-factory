#!/usr/bin/env python3
"""Demo factory client management helper.

Works with individual YAML files per client in demos/clients/{slug}.yaml.
Each file contains: slug, tier, expiresAt, seedData.
"""

import argparse
import datetime
import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

CLIENTS_DIR = Path(__file__).resolve().parent.parent / "demos" / "clients"


def load_all():
    clients = []
    if not CLIENTS_DIR.exists():
        return clients
    for f in sorted(CLIENTS_DIR.glob("*.yaml")):
        with open(f) as fh:
            data = yaml.safe_load(fh)
            if data and "slug" in data:
                clients.append(data)
    return clients


def client_path(slug):
    return CLIENTS_DIR / f"{slug}.yaml"


def cmd_add(args):
    path = client_path(args.slug)
    if path.exists():
        print(f"Error: slug '{args.slug}' already exists at {path}", file=sys.stderr)
        sys.exit(1)
    CLIENTS_DIR.mkdir(parents=True, exist_ok=True)
    data = {
        "slug": args.slug,
        "tier": args.tier,
        "expiresAt": args.expires_at,
        "seedData": args.seed_data,
    }
    with open(path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    print(f"Added demo: {args.slug} (tier={args.tier}, expires={args.expires_at})")


def cmd_extend(args):
    path = client_path(args.slug)
    if not path.exists():
        print(f"Error: slug '{args.slug}' not found", file=sys.stderr)
        sys.exit(1)
    with open(path) as f:
        data = yaml.safe_load(f)
    current = data["expiresAt"]
    if isinstance(current, str):
        current_date = datetime.date.fromisoformat(current)
    else:
        current_date = current
    new_date = current_date + datetime.timedelta(days=args.days)
    data["expiresAt"] = new_date.isoformat()
    with open(path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    print(f"Extended {args.slug}: {current} -> {data['expiresAt']}")


def cmd_list(args):
    clients = load_all()
    today = datetime.date.today()
    result = []
    for c in clients:
        exp = c["expiresAt"]
        if isinstance(exp, str):
            exp_date = datetime.date.fromisoformat(exp)
        else:
            exp_date = exp
        result.append({
            "slug": c["slug"],
            "tier": c["tier"],
            "expiresAt": exp_date.isoformat(),
            "daysLeft": (exp_date - today).days,
            "seedData": c.get("seedData", "default"),
        })
    print(json.dumps(result))


def cmd_expire(args):
    today = datetime.date.today()
    expired = []
    for f in sorted(CLIENTS_DIR.glob("*.yaml")):
        with open(f) as fh:
            data = yaml.safe_load(fh)
        if not data or "expiresAt" not in data:
            continue
        exp = data["expiresAt"]
        if isinstance(exp, str):
            exp_date = datetime.date.fromisoformat(exp)
        else:
            exp_date = exp
        if exp_date < today:
            expired.append(data["slug"])
            f.unlink()
    if not expired:
        sys.exit(0)
    print(",".join(expired))


def main():
    parser = argparse.ArgumentParser(description="Demo factory client manager")
    sub = parser.add_subparsers(dest="command", required=True)

    p_add = sub.add_parser("add")
    p_add.add_argument("--slug", required=True)
    p_add.add_argument("--tier", required=True, choices=["small", "large"])
    p_add.add_argument("--expires-at", required=True)
    p_add.add_argument("--seed-data", default="default")

    p_ext = sub.add_parser("extend")
    p_ext.add_argument("--slug", required=True)
    p_ext.add_argument("--days", required=True, type=int)

    sub.add_parser("list")
    sub.add_parser("expire")

    args = parser.parse_args()
    {"add": cmd_add, "extend": cmd_extend, "list": cmd_list, "expire": cmd_expire}[args.command](args)


if __name__ == "__main__":
    main()
