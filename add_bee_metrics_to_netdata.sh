#!/bin/bash

# Define the Bee metrics endpoint
BEE_METRICS_URL="http://localhost:1633/metrics" # Corrected port
BEE_JOB_NAME="bee_node"
NETDATA_UPDATE_EVERY=5 # seconds

# --- Find Netdata config directory ---
NETDATA_CONFIG_DIR=$(netdata -W print-config 2>/dev/null | grep "config directory" | awk '{print $NF}')

if [ -z "$NETDATA_CONFIG_DIR" ]; then
    echo "Error: Could not determine Netdata configuration directory."
    echo "Please ensure Netdata is installed and try again."
    exit 1
fi

PROMETHEUS_CONFIG_FILE="$NETDATA_CONFIG_DIR/go.d/prometheus.conf"

echo "Netdata configuration directory: $NETDATA_CONFIG_DIR"
echo "Prometheus collector configuration file: $PROMETHEUS_CONFIG_FILE"

# --- Check if the prometheus.conf file exists, create if not ---
if [ ! -f "$PROMETHEUS_CONFIG_FILE" ]; then
    echo "Creating new prometheus.conf file..."
    sudo mkdir -p "$(dirname "$PROMETHEUS_CONFIG_FILE")"
    sudo touch "$PROMETHEUS_CONFIG_FILE"
    echo "jobs:" | sudo tee -a "$PROMETHEUS_CONFIG_FILE" > /dev/null
else
    # Ensure 'jobs:' exists at the start of the file if it's empty or doesn't have it
    if ! grep -q "^jobs:" "$PROMETHEUS_CONFIG_FILE"; then
        echo "Adding 'jobs:' section to prometheus.conf..."
        echo "jobs:" | sudo tee -a "$PROMETHEUS_CONFIG_FILE" > /dev/null
    fi
fi

# --- Check if Bee job already exists ---
if grep -q "name: $BEE_JOB_NAME" "$PROMETHEUS_CONFIG_FILE"; then
    echo "Bee node metrics job '$BEE_JOB_NAME' already exists in $PROMETHEUS_CONFIG_FILE."
    echo "No changes made to the configuration."
else
    echo "Adding Bee node metrics job to $PROMETHEUS_CONFIG_FILE..."
    BEE_CONFIG_BLOCK="
  - name: $BEE_JOB_NAME
    url: $BEE_METRICS_URL
    update_every: $NETDATA_UPDATE_EVERY"

    echo "$BEE_CONFIG_BLOCK" | sudo tee -a "$PROMETHEUS_CONFIG_FILE" > /dev/null

    if [ $? -eq 0 ]; then
        echo "Successfully added Bee node metrics configuration."
        echo "Restarting Netdata service to apply changes..."
        sudo systemctl restart netdata

        if [ $? -eq 0 ]; then
            echo "Netdata service restarted successfully."
            echo "You should now see Bee node metrics in your Netdata dashboard (http://<your_netdata_server_ip>:19999/ or https://app.netdata.cloud)."
        else
            echo "Failed to restart Netdata service. Please check Netdata logs for errors."
        fi
    else
        echo "Failed to write to $PROMETHEUS_CONFIG_FILE. Check permissions."
    fi
fi

echo "Script finished."
