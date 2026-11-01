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

get_top_cpu() {
    ps -eo pid,pcpu,pmem,comm --sort=-pcpu | head -n 6
}

get_top_mem() {
    ps -eo pid,pcpu,pmem,comm --sort=-pmem | head -n 6
}

echo "--- Top 5 by CPU ---"
get_top_cpu
echo "--- Top 5 by memory ---"
get_top_mem

get_os_version() {
    grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"'
}

get_load_average() {
    awk '{print $1 " (1m), " $2 " (5m), " $3 " (15m)"}' /proc/loadavg
}

get_logged_in_users() {
    who | wc -l
}

get_failed_logins() {
    if ! command -v lastb > /dev/null 2>&1 || [ ! -r /var/log/btmp ]; then
        echo "unavailable (run as root)"
        return 0
    fi
    lastb | grep -cv -e '^$' -e '^btmp' || true
}

echo "--- System ---"
echo "OS: $(get_os_version)"
echo "Uptime: $(uptime -p)"
echo "Load average: $(get_load_average)"
echo "Logged-in users: $(get_logged_in_users)"
echo "Failed logins: $(get_failed_logins)"
