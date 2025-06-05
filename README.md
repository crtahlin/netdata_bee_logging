# Netdata Bee Logging
Script to add Bee node's /metrics endpoint to data gathered by Netdata.

## Prerequisites
- Bee node running on machine with standard settings (metrics endpoint at http://localhost:1633/metrics)
- Netdata monitoring running on machine (see https://www.netdata.cloud/)
- Machine should probably be a Linux box (tested on Ubuntu)

## Instructions
Run the script in bash.

## Consequences
Data from Bee /metrics endpoint should be visible in Netdata dashboard, as seen in screenshot:

![image](https://github.com/user-attachments/assets/7c14f381-bc0c-47f7-a74b-f4668019a06e)

## Collaborate
Open an issue with bugs or suggestions.
