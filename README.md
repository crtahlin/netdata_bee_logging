# Netdata Bee Logging
Script to add Bee node's /metrics endpoint to data gathered by Netdata.

## Prerequisites
- Bee node running on machine with standard settings (metrics endpoint at http://localhost:1633/metrics)
- Netdata monitoring running on machine (see https://www.netdata.cloud/)
- Machine should probably be a Linux box (tested on Ubuntu)

## Instructions
- Make it executable: `chmod +x add_bee_metrics_to_netdata.sh`
- See what it would write: `sudo ./add_bee_metrics_to_netdata.sh --dry-run`
- Run it: `sudo ./add_bee_metrics_to_netdata.sh`
- Several bee nodes on one machine: run it once per API port, e.g.
  `sudo ./add_bee_metrics_to_netdata.sh --url http://localhost:1733/metrics --name bee_node_2`

## What it does
- Adds one job to Netdata's Prometheus collector (`go.d/prometheus.conf`), keeping existing jobs; the
  file is backed up and replaced atomically. Re-running it with the same job name changes nothing.
- Raises the job's series limits: bee publishes about 1,600 time series, and with Netdata's default
  limit of 2,000 a node that grows past it would not be collected at all.
- Skips `bee_localstore_leveldb_stats` (about 450 series of database internals, above Netdata's
  per-metric limit anyway).
- Restarts Netdata and waits until the job's charts (`prometheus_<name>.*`) appear.

Tested with Netdata v2.12 (nightly) and bee 2.8.2 on Ubuntu 24.04.

## Consequences
Data from Bee /metrics endpoint should be visible in Netdata dashboard, as seen in screenshot:

![image](https://github.com/user-attachments/assets/7c14f381-bc0c-47f7-a74b-f4668019a06e)

## Collaborate
Open an issue with bugs or suggestions.
