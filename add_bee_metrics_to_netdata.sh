#!/bin/bash

# Define the Bee metrics endpoint
BEE_METRICS_URL="http://localhost:1633/metrics"
BEE_JOB_NAME="bee_node"
NETDATA_UPDATE_EVERY=5 # seconds

# --- Find Netdata config directory ---
NETDATA_CONFIG_DIR=""

# Attempt to find it using common locations
if [ -d "/etc/netdata" ]; then
    NETDATA_CONFIG_DIR="/etc/netdata"
elif [ -d "/opt/netdata/etc/netdata" ]; then
    NETDATA_CONFIG_DIR="/opt/netdata/etc/netdata"
elif [ -d "/usr/local/etc/netdata" ]; then
    NETDATA_CONFIG_DIR="/usr/local/etc/netdata"
else
    # Fallback if common directories are not found
    echo "Warning: Could not automatically determine Netdata configuration directory."
    echo "Please provide it manually. Common locations are /etc/netdata or /opt/netdata/etc/netdata."
    read -p "Enter Netdata config directory (e.g., /etc/netdata): " MANUAL_CONFIG_DIR
    if [ -d "$MANUAL_CONFIG_DIR" ]; then
        NETDATA_CONFIG_DIR="$MANUAL_CONFIG_DIR"
    else
        echo "Error: The provided directory '$MANUAL_CONFIG_DIR' does not exist or is not a directory."
        echo "Please ensure Netdata is installed and running, and provide the correct path."
        exit 1
    fi
fi

PROMETHEUS_CONFIG_FILE="$NETDATA_CONFIG_DIR/go.d/prometheus.conf"

echo "Using Netdata configuration directory: $NETDATA_CONFIG_DIR"
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
        # Add 'jobs:' at the beginning of the file if it's not there
        (echo "jobs:"; cat "$PROMETHEUS_CONFIG_FILE") | sudo tee "$PROMETHEUS_CONFIG_FILE" > /dev/null
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

    # Using tee -a to append the block
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
