#!/bin/bash

get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | tr ',' ' ' | awk '{for (i = 1; i <= NF; i++) if ($i == "id") { printf "%.1f\n", 100 - $(i-1); exit }}'
}

if ! command -v top > /dev/null 2>&1; then
    echo "Error: 'top' is required but not installed." >&2
    exit 1
fi

echo "=== Server Stats ==="
echo "Host: $(hostname)"

cpu=$(get_cpu_usage)
echo "CPU usage: ${cpu}%"
