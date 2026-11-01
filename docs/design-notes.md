# Design Notes: server-stats

Decisions and tradeoffs behind `server-stats.sh`, written as the project grows.

## Environment

- Developed on an Ubuntu Server 26.04 LTS VM (minimized, headless) and accessed over SSH.
- A real VM was chosen over the host OS or a container so the script runs against a real kernel, `/proc`, and init system.
- Linted with ShellCheck, formatted with shfmt.

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

### Known limitations

- **Short sample.** `top -bn1` measures over a very short window, so readings vary run to run (roughly 4% to 12% on an idle VM). A more accurate method reads the counters in `/proc/stat` twice, about one second apart, and computes the difference. Planned as a later refinement.
- **Format dependence.** Other `top` implementations (for example BusyBox) print the CPU line differently. If no `id` field is found, the function prints nothing and the script shows an empty value. Open question: fail loudly with a non-zero exit instead of printing a blank.
- **Verification pending.** Confirm the fix by running the script about 30 times and checking that fully idle samples report `0.0%`, never `100`.

## Script conventions

- Dependencies are checked with `command -v`; errors go to stderr and exit non-zero.
- Functions print only their value, so callers capture it with `$(...)`.
- Open: add `set -euo pipefail`, and check how it interacts with `grep` returning non-zero in a pipeline.

## Roadmap

- [x] CPU usage
- [x] Memory: free vs used, with percentage
- [x] Disk: free vs used, with percentage
- [x] Top 5 processes by CPU
- [x] Top 5 processes by memory
- [x] Stretch: OS version, uptime, load average, logged-in users, failed logins
