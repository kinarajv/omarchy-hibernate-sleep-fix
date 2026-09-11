# Omarchy Hibernate & Sleep Fix

Comprehensive systemd and kernel optimizations for Arch Linux / Omarchy that fix hibernation snapshot memory errors (`-ENOMEM`), eliminate 25+ second page-thrashing delays, resolve post-resume black screens, and keep the system awake when connected to AC power.

---

## Overview

Modern Linux systems using compressed RAM swap (`zram`) alongside Wayland compositors (`Hyprland` / `Quickshell`) frequently face three interrelated power-management failures during hibernation and suspend:

1. **Snapshot Failure (`-ENOMEM`)**: When hibernating, the Linux kernel attempts to freeze processes and write a memory snapshot to disk. Because `zram` is resident in physical RAM at high swap priority, anonymous pages swap into RAM rather than NVMe/SSD, exhausting remaining memory and causing hibernation to abort with Error `-12`.
2. **Slow Hibernation (25–35 Seconds)**: When `/sys/power/image_size` defaults to `0`, `shrink_all_memory()` forcefully evicts and writes out clean disk caches and pages down to zero, stalling the CPU in a continuous thrashing loop.
3. **Black Screen on Resume**: Hyprland or display servers fail to re-enable DPMS or restore display brightness after waking from deep sleep or lid close, leaving users stranded on an unresponsive black display.
4. **Unwanted Sleep on AC**: Connecting a laptop to external power or docking displays often triggers sleep on lid close or after brief idle timeouts.

This repository bundles modular configuration files and drop-in services to solve all four issues cleanly.

---

## What This Fix Solves

| Issue | Technical Root Cause | Resolution |
| :--- | :--- | :--- |
| **Hibernation aborts (`-ENOMEM`)** | `/dev/zram0` (priority 100) traps anonymous memory in RAM during snapshot creation. | `system-sleep/zram-hibernate` disables zram before hibernation and restores it immediately upon resume. |
| **30-second hibernation delay** | `image_size = 0` triggers aggressive cache thrashing before writing the image. | `tmpfiles.d/hibernation.conf` sets `/sys/power/image_size` to a safe 6 GB target and enables 8 compression threads. |
| **Black screen after wake** | DPMS remains disabled and backlight brightness is unasserted on compositor wake. | `bin/omarchy-system-wake` and `systemd/wake.conf` re-enable DPMS and restore display/keyboard brightness on unlock. |
| **Sleep while plugged in** | Default `systemd-logind` suspends on lid close regardless of power source. | `logind.conf.d/30-plugged-in.conf` ignores lid switch on AC/dock, and `omarchy-ac-keep-awake` inhibits idle sleep. |

---

## Repository Structure

```text
omarchy-hibernate-sleep-fix/
├── bin/
│   ├── omarchy-ac-keep-awake         # AC power presence monitor using systemd-inhibit
│   └── omarchy-system-wake           # Restores DPMS, display brightness, and clamshell state
├── logind.conf.d/
│   └── 30-plugged-in.conf            # Instructs systemd-logind to ignore lid switch on AC/dock
├── system-sleep/
│   └── zram-hibernate                # Disables zram before hibernate and re-enables on resume
├── systemd/
│   ├── omarchy-ac-keep-awake.service # User systemd unit for AC idle inhibition
│   └── wake.conf                     # Drop-in for omarchy-sleep-lock.service
├── install.sh                        # Automated system and user unit installation script
├── uninstall.sh                      # Clean revert script
└── README.md
```

---

## Installation

### Automatic Install
Run the installation script with `sudo`:

```bash
git clone https://github.com/<your-username>/omarchy-hibernate-sleep-fix.git
cd omarchy-hibernate-sleep-fix
sudo ./install.sh
```

The installer performs the following actions:
1. Installs `/etc/systemd/system-sleep/zram-hibernate` (mode `0755`).
2. Applies kernel power parameters via `/etc/tmpfiles.d/hibernation.conf`.
3. Installs `/etc/systemd/logind.conf.d/30-plugged-in.conf` and reloads `systemd-logind`.
4. Deploys `/usr/local/bin/omarchy-system-wake` for display restoration.
5. Installs user-level scripts into `~/.local/bin/` and enables `omarchy-ac-keep-awake.service`.

---

## Verification & Health Check

### 1. Verify Kernel Power Settings
Confirm the optimized image size and compression threads are loaded:

```bash
cat /sys/power/image_size
cat /sys/power/hibernate_compression_threads
```

Expected values:
- `image_size`: `6032873881` (~6 GB)
- `hibernate_compression_threads`: `8` (or matching your CPU core count)

### 2. Verify ZRAM Sleep Hook
Simulate the pre-hibernate action:

```bash
sudo /etc/systemd/system-sleep/zram-hibernate pre hibernate
swapon --show
```

Verify that `/dev/zram0` is temporarily deactivated. Then run the post-resume hook:

```bash
sudo /etc/systemd/system-sleep/zram-hibernate post hibernate
swapon --show
```

Verify that `/dev/zram0` is back online with its original priority.

### 3. Verify AC Keep-Awake Service
Check that the user service is running and inhibiting sleep when plugged in:

```bash
systemctl --user status omarchy-ac-keep-awake.service
systemd-inhibit --list
```

Look for `omarchy-ac-keep-awake` in the active inhibitor list when AC power is attached.

---

## Troubleshooting

### Hibernate still fails with "No space left on device"
Ensure your swap partition or swapfile is at least the size of your current RAM footprint:
```bash
swapon --show
free -h
```
If using a Btrfs swapfile, confirm the resume offset is configured in your kernel bootloader parameters:
```bash
cat /sys/power/resume
cat /sys/power/resume_offset
```

### Display stays dark after resuming from suspend
Run the wake script manually from a TTY or SSH session to test hardware control:
```bash
/usr/local/bin/omarchy-system-wake
```
If your brightness controller uses a non-standard device, check:
```bash
brightnessctl -l
```

---

## Uninstallation

To remove all installed files, hooks, and services, run:

```bash
sudo ./uninstall.sh
```

All modified power parameters, drop-in services, and sleep hooks will be completely reverted.

---

## License

MIT License.
