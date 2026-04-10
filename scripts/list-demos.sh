#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JSON=$(python3 "$SCRIPT_DIR/update_clients.py" list)

if [[ "$JSON" == "[]" ]]; then
    echo "No demos configured."
    exit 0
fi

# Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

printf "%-20s %-8s %-12s %-12s %s\n" "SLUG" "TIER" "EXPIRES" "DAYS LEFT" "K8S STATUS"
printf "%-20s %-8s %-12s %-12s %s\n" "----" "----" "-------" "---------" "----------"

echo "$JSON" | python3 -c "
import json, sys
for d in json.load(sys.stdin):
    print(f\"{d['slug']}|{d['tier']}|{d['expiresAt']}|{d['daysLeft']}\")
" | while IFS='|' read -r slug tier expires days; do
    # K8s status
    ns="demo-${slug}"
    if kubectl get ns "$ns" >/dev/null 2>&1; then
        running=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -c "Running" || true)
        if [[ "$running" -gt 0 ]]; then
            status="${GREEN}running${NC}"
        else
            status="${CYAN}scaled-to-zero${NC}"
        fi
    else
        status="${RED}missing${NC}"
    fi

    # Days coloring
    if [[ "$days" -lt 0 ]]; then
        days_display="${RED}EXPIRED${NC}"
    elif [[ "$days" -le 7 ]]; then
        days_display="${YELLOW}${days}${NC}"
    else
        days_display="${GREEN}${days}${NC}"
    fi

    printf "%-20s %-8s %-12s %-12b %b\n" "$slug" "$tier" "$expires" "$days_display" "$status"
done
