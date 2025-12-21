#!/bin/bash
# Run hourly in sudo crontab
# updates.prom i scraped by node_exporter to provide stats to grafana dashboard.

apt update > /dev/null 2>&1
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable)

echo "system_pending_updates $UPDATES" > /var/lib/node_exporter/updates.prom
