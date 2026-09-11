#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "Error: install.sh requires root privileges. Please run with sudo: sudo ./install.sh" >&2
  exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

install -d -m 755 /etc/systemd/system-sleep
install -m 755 "$SCRIPT_DIR/system-sleep/zram-hibernate" /etc/systemd/system-sleep/zram-hibernate

install -d -m 755 /etc/tmpfiles.d
install -m 644 "$SCRIPT_DIR/tmpfiles.d/hibernation.conf" /etc/tmpfiles.d/hibernation.conf
systemd-tmpfiles --create /etc/tmpfiles.d/hibernation.conf 2>/dev/null || true

install -d -m 755 /etc/systemd/logind.conf.d
install -m 644 "$SCRIPT_DIR/logind.conf.d/30-plugged-in.conf" /etc/systemd/logind.conf.d/30-plugged-in.conf

install -d -m 755 /usr/local/bin
install -m 755 "$SCRIPT_DIR/bin/omarchy-system-wake" /usr/local/bin/omarchy-system-wake

install -d -m 755 "$USER_HOME/.local/bin"
install -m 755 -o "$REAL_USER" -g "$REAL_USER" "$SCRIPT_DIR/bin/omarchy-ac-keep-awake" "$USER_HOME/.local/bin/omarchy-ac-keep-awake"

install -d -m 755 "$USER_HOME/.config/systemd/user/omarchy-sleep-lock.service.d"
install -m 644 -o "$REAL_USER" -g "$REAL_USER" "$SCRIPT_DIR/systemd/wake.conf" "$USER_HOME/.config/systemd/user/omarchy-sleep-lock.service.d/wake.conf"

install -d -m 755 "$USER_HOME/.config/systemd/user"
install -m 644 -o "$REAL_USER" -g "$REAL_USER" "$SCRIPT_DIR/systemd/omarchy-ac-keep-awake.service" "$USER_HOME/.config/systemd/user/omarchy-ac-keep-awake.service"

systemctl restart systemd-logind 2>/dev/null || true

if [[ -d "/run/user/$(id -u "$REAL_USER")" ]]; then
  USER_ID=$(id -u "$REAL_USER")
  sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$USER_ID" systemctl --user daemon-reload 2>/dev/null || true
  sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$USER_ID" systemctl --user enable --now omarchy-ac-keep-awake.service 2>/dev/null || true
fi

echo "Installation complete. Hibernate, wake, and AC keep-awake optimizations installed."
