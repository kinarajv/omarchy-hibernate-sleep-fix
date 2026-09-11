#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Error: uninstall.sh requires root privileges. Please run with sudo: sudo ./uninstall.sh" >&2
  exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

if [[ -d "/run/user/$(id -u "$REAL_USER")" ]]; then
  USER_ID=$(id -u "$REAL_USER")
  sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$USER_ID" systemctl --user disable --now omarchy-ac-keep-awake.service 2>/dev/null || true
fi

rm -f /etc/systemd/system-sleep/zram-hibernate
rm -f /etc/tmpfiles.d/hibernation.conf
rm -f /etc/systemd/logind.conf.d/30-plugged-in.conf
rm -f /etc/omarchy/wake.conf
rm -f /usr/local/bin/omarchy-system-wake
rm -f "$USER_HOME/.local/bin/omarchy-ac-keep-awake"
rm -f "$USER_HOME/.config/systemd/user/omarchy-sleep-lock.service.d/wake.conf"
rm -f "$USER_HOME/.config/systemd/user/omarchy-ac-keep-awake.service"

systemctl restart systemd-logind 2>/dev/null || true

if [[ -d "/run/user/$(id -u "$REAL_USER")" ]]; then
  USER_ID=$(id -u "$REAL_USER")
  sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$USER_ID" systemctl --user daemon-reload 2>/dev/null || true
fi

echo "Uninstallation complete. Reverted all hibernation and sleep configurations."
