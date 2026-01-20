#!/bin/bash
# ==============================================================
# Universal Blockchain Node Exporter + Block Height Metric (root)
# ==============================================================
# Installs node_exporter and creates a sanitized custom metric
# that exports the current block height every 5 seconds.
# ==============================================================
set -e

echo " Installing Node Exporter + block_get metric service..."

# --- 1️ Install Node Exporter ---
cd /tmp
NODE_EXPORTER_VERSION="1.10.2"

echo " Downloading Node Exporter v${NODE_EXPORTER_VERSION}..."
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
chmod +x /usr/local/bin/node_exporter
rm -rf node_exporter-${NODE_EXPORTER_VERSION}*

echo " Node Exporter installed."

# --- 2️ Prepare directories ---
mkdir -p /opt/block_get

# --- 3️ Node Exporter systemd service ---
cat <<'EOF' >/etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter (runs as root)
After=network.target

[Service]
ExecStart=/usr/local/bin/node_exporter \
  --collector.systemd \
  --collector.textfile.directory=/opt/block_get \
  --web.listen-address=:9100
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# --- 4️ block_get metric script ---
cat <<'EOF' >/opt/block_get/block_get.sh
#!/bin/bash
# block_get.sh - Universal blockchain metric exporter

#  Define blockchain name (underscores only)
RAW_BLOCKCHAIN_NAME="blockchain_name"

# Sanitize blockchain name for Prometheus (replace invalid chars with underscores)
BLOCKCHAIN_NAME=$(echo "$RAW_BLOCKCHAIN_NAME" | tr -cs 'a-zA-Z0-9_' '_')

METRICS_DIR="/opt/block_get"
METRICS_FILE="${METRICS_DIR}/${BLOCKCHAIN_NAME}block_height.prom"

# --- Fetch block height (auto-detect hex or decimal) ---
BLOCK_HEIGHT_RAW=$(curl 2>/dev/null)

# Handle Ethereum-style hex values or plain numbers
if [[ "$BLOCK_HEIGHT_RAW" =~ ^0x[0-9a-fA-F]+$ ]]; then
  # Convert from hex to decimal
  BLOCK_HEIGHT=$((BLOCK_HEIGHT_RAW))
elif [[ "$BLOCK_HEIGHT_RAW" =~ ^[0-9]+$ ]]; then
  # Already decimal
  BLOCK_HEIGHT="$BLOCK_HEIGHT_RAW"
else
  # Invalid or null result
  BLOCK_HEIGHT=0
fi

# Write metric in valid Prometheus text format
if [[ "$BLOCK_HEIGHT" =~ ^[0-9]+$ ]]; then
  {
    echo "# TYPE ${BLOCKCHAIN_NAME}block_height"
    echo "${BLOCKCHAIN_NAME}block_height ${BLOCK_HEIGHT}"
  } > "${METRICS_FILE}"
else
  {
    echo "# ${BLOCKCHAIN_NAME}block_height Block height fetch failed"
  } > "${METRICS_FILE}"
fi
EOF

chmod +x /opt/block_get/block_get.sh
echo "✅ Created /opt/block_get/block_get.sh"

# --- 5️ Systemd service to run script ---
cat <<'EOF' >/etc/systemd/system/block_get.service
[Unit]
Description=Export blockchain block height metric
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/block_get/block_get.sh
Restart=on-failure
EOF

# --- 6️ Timer to run every 5 seconds ---
cat <<'EOF' >/etc/systemd/system/block_get.timer
[Unit]
Description=Run blockchain block height exporter every 5 seconds

[Timer]
OnBootSec=5s
OnUnitActiveSec=5s
AccuracySec=1s
Unit=block_get.service

[Install]
WantedBy=timers.target
EOF

# --- 7️ Enable and start everything ---
systemctl daemon-reload
systemctl enable --now node_exporter
systemctl enable --now block_get.timer
systemctl restart node_exporter
systemctl restart block_get.service
systemctl restart block_get.timer
echo " Waiting for services to start..."

sleep 2
echo " Services enabled and running."

# --- 8️ Test output ---
echo " Running initial metric update..."
/opt/block_get/block_get.sh
cat /opt/block_get/*.prom || true

echo
echo " Installation complete!"
echo "Node Exporter listening on: http://<server-ip>:9100/metrics"
echo "Prometheus target example: http://<server-ip>:9100"
echo " Cleaned up installation script..."
# --- 9️ Self-delete script ---
SCRIPT_PATH=$(readlink -f /proc/$$/fd/255 2>/dev/null)

if [[ -n "$SCRIPT_PATH" ]]; then
    rm -f "$SCRIPT_PATH"
else
    echo " Could not auto-detect script path. Delete manually if needed."
fi
