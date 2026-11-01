# Design Notes: server-stats

Decisions, bugs, and tradeoffs behind `server-stats.sh`. Written as the project grew, so each section records what was chosen, why, and what was rejected.

## Environment

- Developed on an Ubuntu Server 26.04 LTS VM (minimized, headless) and accessed over SSH.
- A real VM was chosen over the host OS or a container so the script runs against a real kernel, `/proc`, and init system.
- Linted with ShellCheck, formatted with shfmt.
- Work is committed in small steps and pushed to GitHub over an SSH key.

## CPU usage

### Requirement

Report total CPU usage as a single percentage (100 minus idle).

### Approach

Parse the CPU summary line from `top` in batch mode:

```bash
top -bn1 | grep "Cpu(s)" | tr ',' ' ' | awk '{for (i = 1; i <= NF; i++) if ($i == "id") { printf "%.1f\n", 100 - $(i-1); exit }}'
```

- `top -bn1`: batch mode, one iteration.
- `grep "Cpu(s)"`: keep only the CPU summary line.
- `tr ',' ' '`: replace commas with spaces so every number and label is its own whitespace-separated field.
- `awk`: find the field equal to `id` (idle) and take the field before it; print `100 - idle` with one decimal.

### Bug found: positional parsing breaks when idle is 100%

The first version used `awk '{print 100 - $8}'`, assuming the idle value is always field 8. That holds for lines like:

```
%Cpu(s):  4.0 us,  0.0 sy,  0.0 ni, 96.0 id,  0.0 wa, ...
```

When idle reaches `100.0`, `top` drops the padding space and the number glues onto the previous label:

```
%Cpu(s):  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa, ...
```

`ni,100.0` becomes a single field, every later field shifts left by one, and `$8` becomes the label `id,`. awk converts a non-numeric string to `0` without warning, so `100 - 0` printed `100`. The script reported 100% CPU used on a completely idle machine.

The bad line was reproduced on demand by sampling `top` repeatedly and filtering for `ni,100`.

### Fix and lesson

Parse by label, not by position. Replacing commas with spaces separates the glued fields, and anchoring on `id` finds the idle value wherever it sits.

General lesson: positional parsing of human-oriented output is fragile, and awk fails silently on non-numeric input.

### Verification

After the fix, the script was run 30 times in a row on the idle VM. Six samples reported `0.0%` (the fully idle case that used to print `100`), the rest fell between 3.8% and 9.1%, and no run reported `100.0%`.

### Known limitations

- **Short sample.** `top -bn1` measures over a very short window, so readings vary run to run (roughly 4% to 12% on an idle VM). A more accurate method reads the counters in `/proc/stat` twice, about one second apart, and computes the difference. Planned as a later refinement.
- **Format dependence.** Other `top` implementations (for example BusyBox) print the CPU line differently. If no `id` field is found, the function prints nothing and the script shows an empty value. Open question: fail loudly with a non-zero exit instead of printing a blank.

## Memory usage

### Requirement

Report free vs used memory, with percentages.

### Approach

Read `/proc/meminfo` directly and look values up by name:

- `MemTotal`: all installed RAM.
- `MemAvailable`: memory a new program could realistically get, including disk cache the kernel will give back.
- Used = `MemTotal - MemAvailable`; percentage = used / `MemTotal`.

On the test VM this gave about 455 MB used of 1594 MB (28.5%), matching `free -m`.

### Decisions

- **`/proc/meminfo` over `free -m`.** `free` is a formatted view of the same data, and its layout and its definition of "used" have changed between versions (older versions counted cache as used). Reading named fields avoids the positional-parsing problem from the CPU bug.
- **`MemAvailable` over `MemFree`.** Linux fills spare RAM with cache, so `MemFree` looks small on a healthy machine and would give a misleading "almost full" picture. The output labels the figure "Available", not "Free", on purpose.
- **Fail loudly.** If either field is missing, the function exits non-zero and the script prints an error to stderr instead of a wrong number. The failure path was tested by renaming the field being read.
- **Swap left out.** The requirement is about RAM. Swap in use is a useful warning sign and is a candidate for a stretch stat.

### Known limitations

- Linux only, which fits the "any Linux server" goal.
- `MemAvailable` exists only on kernels 3.14 and newer; older systems hit the error path.

## Disk usage

### Requirement

Report free vs used disk space, with percentages.

### Approach

Report the root filesystem (`/`) using `df -P -k /`. The `-P` flag forces the fixed POSIX layout, so reading by column is safe here, unlike the `top` output. The percentage is computed from `Used + Available`, not the `Size` column, because ext4 reserves a slice of space for root and `Size` is larger than the two combined. This also matches the `Use%` that `df` itself reports.

### Open design question

Reporting only `/` can hide a nearly full partition elsewhere (for example a separate `/var`). The options considered:

| Option | Tradeoff |
|---|---|
| Only `/` | Simple, but misses other partitions |
| Every real filesystem, one line each | Honest picture, but needs filtering of virtual filesystems (`df -P -x tmpfs -x devtmpfs`) |
| One grand total | Hides a full partition inside the average |

Current choice: `/` only. Planned improvement: one line per real filesystem.

## Script conventions

- Dependencies are checked with `command -v`; errors go to stderr and exit non-zero.
- Functions print only their value, so callers capture it with `$(...)`.
- Each function is defined before the line that calls it, because bash reads the file top to bottom.
- Open: add `set -euo pipefail`, and check how it interacts with `grep` returning non-zero in a pipeline.

## Workflow lessons

- Commit before experimenting. `git checkout <file>` discards uncommitted work with no undo; it wiped an unsaved function once, and the fix was to commit first and break things second.
- Preview before deleting. `sed -n 'A,Bp'` shows the lines that `sed -i 'A,Bd'` is about to remove.
- Verify against the source of truth. Output was checked against `free -m` and `df -h` instead of trusted.

## Roadmap

- [x] CPU usage
- [x] Memory: free vs used, with percentage
- [x] Disk: free vs used, with percentage (root filesystem; multi-filesystem support planned)
- [x] Top 5 processes by CPU
- [x] Top 5 processes by memory
- [x] Stretch: OS version, uptime, load average, active sessions, failed logins
- [ ] Read `/proc/stat` twice for a more accurate CPU reading
