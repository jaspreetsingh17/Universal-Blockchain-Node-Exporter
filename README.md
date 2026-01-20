# Universal Blockchain Node Exporter

A Prometheus-compatible monitoring solution that exports blockchain node metrics, including real-time block height tracking. Works with any EVM-compatible blockchain (Ethereum, Polygon, Arbitrum, Optimism, etc.).

![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)
![Node Exporter](https://img.shields.io/badge/Node_Exporter-1.10.2-blue?style=for-the-badge)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

## Features

- **Automatic Node Exporter Installation** – Installs the latest Prometheus Node Exporter (v1.10.2)
- **Block Height Metrics** – Custom metric exporter that fetches block height every 5 seconds
- **EVM Compatible** – Works with any blockchain using `eth_blockNumber` JSON-RPC method
- **Hex/Decimal Support** – Automatically handles both hexadecimal and decimal block heights
- **Systemd Integration** – Runs as managed systemd services with automatic restart
- **Prometheus Ready** – Metrics exposed in standard Prometheus text format

## Prerequisites

- **Operating System**: Linux (Ubuntu/Debian recommended)
- **Privileges**: Root access required
- **Dependencies**: `curl`, `wget`, `jq`, `tar`
- **Network**: Blockchain node running with JSON-RPC enabled on port `8545`

## Quick Start

### 1. Download and Run

```bash

# Make it executable
chmod +x install.sh

# Run with root privileges
sudo ./install.sh
```

### 2. Configure the Script

Before running, edit the script to configure two things:

#### A. Set Your Blockchain Name (Line 51)

```bash
# Find and modify this line
RAW_BLOCKCHAIN_NAME="blockchain_name"

# Change to your blockchain, e.g.:
RAW_BLOCKCHAIN_NAME="ethereum"
```

#### B. Set Your RPC Curl Command (Line 60)

The script contains a placeholder curl command that you **must customize** for your blockchain:

```bash
# Find this line
BLOCK_HEIGHT_RAW=$(curl 2>/dev/null)

# Replace with your blockchain's RPC call, for example:
```

**EVM Chains (Ethereum, Polygon, Arbitrum, etc.):**
```bash
BLOCK_HEIGHT_RAW=$(curl -s -X POST http://127.0.0.1:8545 \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    | jq -r '.result' 2>/dev/null)
```

**Solana:**
```bash
BLOCK_HEIGHT_RAW=$(curl -s -X POST http://127.0.0.1:8899 \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","id":1,"method":"getBlockHeight"}' \
    | jq -r '.result' 2>/dev/null)
```

**Cosmos-based Chains:**
```bash
BLOCK_HEIGHT_RAW=$(curl -s http://127.0.0.1:26657/status \
    | jq -r '.result.sync_info.latest_block_height' 2>/dev/null)
```

> **Note**: The script sanitizes the blockchain name for Prometheus compatibility (replaces special characters with underscores).

## Installation Details

The script installs the following components:

| Component | Path | Description |
|-----------|------|-------------|
| Node Exporter | `/usr/local/bin/node_exporter` | Prometheus metrics exporter |
| Block Height Script | `/opt/block_get/block_get.sh` | Custom block height fetcher |
| Metrics Output | `/opt/block_get/*.prom` | Prometheus text format metrics |

### Systemd Services

| Service | Description |
|---------|-------------|
| `node_exporter.service` | Main Prometheus node exporter (port 9100) |
| `block_get.service` | One-shot block height fetcher |
| `block_get.timer` | Timer triggering block fetch every 5 seconds |

## Metrics

### Accessing Metrics

Once installed, metrics are available at:

```
http://<server-ip>:9100/metrics
```

### Block Height Metric

The custom block height metric follows this format:

```prometheus
# TYPE <blockchain_name>block_height
<blockchain_name>block_height <block_number>
```

**Example:**
```prometheus
# TYPE ethereum_block_height
ethereum_block_height 19234567
```

## Service Management

```bash
# Check service status
sudo systemctl status node_exporter
sudo systemctl status block_get.timer

# View logs
sudo journalctl -u node_exporter -f
sudo journalctl -u block_get.service -f

# Restart services
sudo systemctl restart node_exporter
sudo systemctl restart block_get.timer

# Stop services
sudo systemctl stop node_exporter
sudo systemctl stop block_get.timer

# Disable services
sudo systemctl disable node_exporter
sudo systemctl disable block_get.timer
```

## Prometheus Configuration

Add this target to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'blockchain-node'
    static_configs:
      - targets: ['<server-ip>:9100']
    scrape_interval: 15s
```

### Example Grafana Query

```promql
# Current block height
<blockchain_name>block_height

# Block height increase rate (blocks per minute)
rate(<blockchain_name>block_height[1m]) * 60
```

## Uninstallation

To remove all installed components:

```bash
# Stop and disable services
sudo systemctl stop node_exporter block_get.timer block_get.service
sudo systemctl disable node_exporter block_get.timer block_get.service

# Remove systemd files
sudo rm /etc/systemd/system/node_exporter.service
sudo rm /etc/systemd/system/block_get.service
sudo rm /etc/systemd/system/block_get.timer

# Reload systemd
sudo systemctl daemon-reload

# Remove installed files
sudo rm /usr/local/bin/node_exporter
sudo rm -rf /opt/block_get
```

## Security Considerations

- The script runs Node Exporter as root (for systemd collector access)
- Port `9100` is exposed – consider firewall rules for production

<p align="center">
  Made for the blockchain community
</p>
