#!/usr/bin/env bash
set -euo pipefail

usage() { echo "Usage: $0 <slug> <tier> <days> [seedData]" >&2; exit 1; }

[[ $# -lt 3 ]] && usage

SLUG="$1"
TIER="$2"
DAYS="$3"
SEED="${4:-default}"

# Validate
[[ "$SLUG" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || { echo "Error: slug must be lowercase alphanumeric with hyphens" >&2; exit 1; }
[[ "$TIER" =~ ^(small|large)$ ]] || { echo "Error: tier must be small or large" >&2; exit 1; }
[[ "$DAYS" =~ ^[0-9]+$ ]] && [[ "$DAYS" -gt 0 ]] || { echo "Error: days must be a positive integer" >&2; exit 1; }

# Calculate expiry (works on both macOS and Linux)
if date --version >/dev/null 2>&1; then
    EXPIRES=$(date -d "+${DAYS} days" +%Y-%m-%d)
else
    EXPIRES=$(date -v+"${DAYS}"d +%Y-%m-%d)
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

python3 "$SCRIPT_DIR/update_clients.py" add \
    --slug "$SLUG" \
    --tier "$TIER" \
    --expires-at "$EXPIRES" \
    --seed-data "$SEED"

cd "$SCRIPT_DIR/.."
git add "demos/clients/${SLUG}.yaml"
git commit -m "demo: add ${SLUG} (tier=${TIER}, expires=${EXPIRES})"
git push

echo "Done. Demo '${SLUG}' created and pushed. ArgoCD will sync within minutes."
