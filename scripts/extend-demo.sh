#!/usr/bin/env bash
set -euo pipefail

usage() { echo "Usage: $0 <slug> <days>" >&2; exit 1; }

[[ $# -lt 2 ]] && usage

SLUG="$1"
DAYS="$2"

[[ "$DAYS" =~ ^[0-9]+$ ]] && [[ "$DAYS" -gt 0 ]] || { echo "Error: days must be a positive integer" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

python3 "$SCRIPT_DIR/update_clients.py" extend --slug "$SLUG" --days "$DAYS"

cd "$SCRIPT_DIR/.."
git add "demos/clients/${SLUG}.yaml"
git commit -m "demo: extend ${SLUG} by ${DAYS} days"
git push

echo "Done. Demo '${SLUG}' extended. ArgoCD will sync within minutes."
