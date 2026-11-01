# server-stats

A Bash script that reports basic performance stats for a Linux server: CPU, memory, and disk, with top processes planned. Built as the first project in the [roadmap.sh DevOps projects](https://roadmap.sh/devops/projects) list.

## What it reports

| Stat | Status |
|---|---|
| Total CPU usage | Done |
| Memory: used vs available, with percentage | Done |
| Disk: used vs free, with percentage (root filesystem) | Done |
| Top 5 processes by CPU | Done |
| Top 5 processes by memory | Done |
| OS version, uptime, load average, logged-in users, failed logins | Stretch |

## Requirements

- Linux (reads `/proc/meminfo`)
- Bash
- `top`, `awk`, `grep`, `tr`, `df` (all standard on most distributions)

## Usage

```bash
git clone git@github.com:ashoebb/server-stats.git
cd server-stats
chmod +x server-stats.sh
./server-stats.sh
```

Example output:

```
=== Server Stats ===
Host: devopslab01
CPU usage: 11.5%
--- Memory ---
Used: 455 MB (28.5%)
Available: 1139 MB (71.5%)
```

The script exits non-zero and writes to stderr if a required tool is missing or a stat cannot be read, so it is safe to use in other scripts.

## How it works

- **CPU:** parses the summary line from `top -bn1` by label (`id`) instead of column position.
- **Memory:** reads `MemTotal` and `MemAvailable` from `/proc/meminfo`. Used memory is total minus available, so disk cache is not counted as used.
- **Disk:** uses `df -P` for a fixed output layout and computes the percentage from used plus available space.

The reasoning behind these choices, including a bug where the script reported 100% CPU on an idle machine, is written up in [`docs/design-notes.md`](docs/design-notes.md).

## Development

Developed and tested on an Ubuntu Server 26.04 LTS VM.

```bash
shellcheck server-stats.sh
shfmt -d server-stats.sh
```

## Known limitations

- CPU usage comes from a single short `top` sample, so readings vary by a few percent between runs.
- Other `top` implementations (for example BusyBox) format the CPU line differently.
- Disk usage covers only `/`.
- `MemAvailable` requires Linux kernel 3.14 or newer.

## Roadmap

- Top 5 processes by CPU and memory
- Disk usage for every real filesystem
- A more accurate CPU reading from `/proc/stat`
- Stretch stats: OS version, uptime, load average, logged-in users, failed logins
- Tests with bats and a ShellCheck CI workflow
