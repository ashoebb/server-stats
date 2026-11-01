#!/bin/bash

get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | tr ',' ' ' | awk '{for (i = 1; i <= NF; i++) if ($i == "id") { printf "%.1f\n", 100 - $(i-1); exit }}'
}
get_memory_usage() {
    awk '
        /^MemTotal:/     { total = $2 }
        /^MemAvailable:/ { avail = $2 }
        END {
            if (total == 0 || avail == "") exit 1
            used = total - avail
            printf "Used: %.0f MB (%.1f%%)\n", used / 1024, used / total * 100
            printf "Available: %.0f MB (%.1f%%)\n", avail / 1024, avail / total * 100
        }
    ' /proc/meminfo
}
if ! command -v top > /dev/null 2>&1; then
    echo "Error: 'top' is required but not installed." >&2
    exit 1
fi

echo "=== Server Stats ==="
echo "Host: $(hostname)"

cpu=$(get_cpu_usage)
echo "CPU usage: ${cpu}%"

echo "--- Memory ---"
get_memory_usage || { echo "Error: could not read memory stats." >&2; exit 1; }

get_disk_usage() {
    df -P -k / | awk 'NR == 2 {
        used = $3; avail = $4
        if (used + avail == 0) exit 1
        printf "Used: %.1f GB (%.1f%%)\n", used / 1048576, used / (used + avail) * 100
        printf "Free: %.1f GB (%.1f%%)\n", avail / 1048576, avail / (used + avail) * 100
    }'
}

echo "--- Disk (/) ---"
get_disk_usage || { echo "Error: could not read disk stats." >&2; exit 1; }
get_disk_usage() {
    df -P -k / | awk '
        NR == 2 && $3 + $4 > 0 {
            used = $3; avail = $4
            printf "Used: %.1f GB (%.1f%%)\n", used / 1048576, used / (used + avail) * 100
            printf "Free: %.1f GB (%.1f%%)\n", avail / 1048576, avail / (used + avail) * 100
            ok = 1
        }
        END { exit !ok }
    '
}

echo "--- Disk (/) ---"
get_disk_usage || { echo "Error: could not read disk stats." >&2; exit 1; }
