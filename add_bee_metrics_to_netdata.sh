#!/bin/bash
# Add a bee node's /metrics endpoint to Netdata's Prometheus collector (go.d "prometheus" module).
#
#   sudo ./add_bee_metrics_to_netdata.sh [--dry-run] [--url URL] [--name NAME]
#
# Defaults: URL http://localhost:1633/metrics, job name bee_node. Run once per bee API port
# (give each a different --name). Safe to re-run: an existing job with the same name is left as it is.
#
# What it writes: one job in <netdata config>/go.d/prometheus.conf. The file is backed up first and
# replaced atomically. The job raises Netdata's series limits (bee publishes about 1,600 series; with
# the default limit of 2,000 a node that grows past it would be dropped entirely) and skips
# bee_localstore_leveldb_stats (about 450 series of database internals, above the per-metric limit).
# After the restart the script waits until Netdata's local API shows the job's charts.
set -euo pipefail

URL="http://localhost:1633/metrics"
NAME="bee_node"
DRY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1; shift ;;
        --url) URL=$2; shift 2 ;;
        --name) NAME=$2; shift 2 ;;
        -h|--help) sed -n 2,13p "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

# --- find Netdata's config directory ---
CONF_DIR=""
for d in /etc/netdata /opt/netdata/etc/netdata /usr/local/etc/netdata; do
    [ -d "$d" ] && { CONF_DIR=$d; break; }
done
[ -n "$CONF_DIR" ] || { echo "Netdata config directory not found (is Netdata installed?)" >&2; exit 1; }
FILE="$CONF_DIR/go.d/prometheus.conf"
echo "Netdata config: $CONF_DIR; collector file: $FILE"

# --- is the endpoint reachable? ---
if ! curl -fsS -m 10 "$URL" -o /dev/null; then
    echo "Cannot read $URL: is bee running and is its API on this address?" >&2
    exit 1
fi
SERIES=$(curl -fsS -m 10 "$URL" | grep -vc '^#' || true)
echo "Endpoint OK: $SERIES time series"

if [ -f "$FILE" ] && grep -qE "^[[:space:]]*-[[:space:]]*name:[[:space:]]*$NAME[[:space:]]*$" "$FILE"; then
    echo "Job '$NAME' already exists in $FILE; nothing changed."
    exit 0
fi

JOB="  - name: $NAME
    url: $URL
    update_every: 10
    timeout: 10
    max_time_series: 3000
    max_time_series_per_metric: 250
    selector:
      deny:
        - bee_localstore_leveldb_stats*"

# --- build the new file content (existing jobs kept; comments kept) ---
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
if [ -f "$FILE" ] && grep -qE '^jobs:' "$FILE"; then
    cat "$FILE" > "$TMP"
    printf '%s\n' "$JOB" >> "$TMP"
elif [ -f "$FILE" ]; then
    # a file without an active 'jobs:' list (e.g. only comments): keep it, add the list at the end
    cat "$FILE" > "$TMP"
    printf '\njobs:\n%s\n' "$JOB" >> "$TMP"
else
    printf 'jobs:\n%s\n' "$JOB" > "$TMP"
fi

if [ $DRY = 1 ]; then
    echo "--- dry run: $FILE would become ---"
    cat "$TMP"
    exit 0
fi

# --- install: back up, write atomically, restart, check ---
mkdir -p "$(dirname "$FILE")"
if [ -f "$FILE" ]; then
    cp -a "$FILE" "$FILE.bak-$(date +%Y%m%d%H%M%S)"
    echo "Backup: $FILE.bak-*"
fi
install -m 644 "$TMP" "$FILE.new"
chown --reference="$CONF_DIR" "$FILE.new" 2>/dev/null || true
mv "$FILE.new" "$FILE"

systemctl restart netdata
echo "Netdata restarted; waiting for the job's charts ..."
for i in $(seq 1 18); do
    n=$(curl -fsS -m 5 http://127.0.0.1:19999/api/v1/charts 2>/dev/null \
        | grep -o "\"prometheus_${NAME}\.[^\"]*\":" | sort -u | wc -l || true)
    if [ "${n:-0}" -gt 0 ]; then
        echo "OK: $n charts for job '$NAME' (prometheus_$NAME.*), visible in the local dashboard and Netdata Cloud."
        exit 0
    fi
    sleep 5
done
echo "Warning: no charts for '$NAME' after 90 s; check 'journalctl -u netdata | grep $NAME'." >&2
exit 1
