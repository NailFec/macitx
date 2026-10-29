#!/bin/bash
# Remove the Caps Lock switch and restore the newest install backup, when one exists.
set -euo pipefail

USER_ID=$(id -u)
BACKUP_ROOT=${XDG_DATA_HOME:-$HOME/.local/share}/fcitx-caps-zh/backups

if [[ $USER_ID -eq 0 ]]; then
  echo "Run this as your desktop user, not as root." >&2
  exit 1
fi

if [[ ! -d $BACKUP_ROOT ]]; then
  echo "No backup directory at $BACKUP_ROOT" >&2
  exit 1
fi

latest=$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)
if [[ -z $latest ]]; then
  echo "No backup to restore." >&2
  exit 1
fi

export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$USER_ID}

systemctl --user disable --now im-caps-watch.service >/dev/null 2>&1 || true
fcitx5-remote -e >/dev/null 2>&1 || true
sleep 0.4
if pgrep -u "$USER_ID" -x fcitx5 >/dev/null; then
  kill "$(pgrep -u "$USER_ID" -x fcitx5)" || true
  sleep 0.3
fi

restore_home_file() {
  local rel=$1
  local backed=$latest/$rel
  local dest=$HOME/$rel
  if [[ -e $backed ]]; then
    mkdir -p "$(dirname "$dest")"
    cp -a "$backed" "$dest"
  fi
}

restore_home_file ".config/fcitx5/config"
restore_home_file ".config/fcitx5/profile"
restore_home_file ".config/fcitx5/conf/classicui.conf"
restore_home_file ".local/share/fcitx5/inputmethod/direct-en.conf"
restore_home_file ".local/share/fcitx5/rime/default.custom.yaml"
restore_home_file ".local/share/fcitx5/rime/rime_ice.custom.yaml"
restore_home_file ".local/bin/im-caps-tap"
restore_home_file ".local/bin/im-caps-watch"
restore_home_file ".config/systemd/user/im-caps-watch.service"

if [[ -f $latest/created.txt ]]; then
  while IFS= read -r path; do
    [[ -n $path && -e $path ]] || continue
    case $path in
      /etc/*) sudo rm -f "$path" ;;
      *) rm -f "$path" ;;
    esac
  done <"$latest/created.txt"
fi
systemctl --user daemon-reload || true

if [[ -f $latest/keyd-default.conf ]]; then
  sudo install -m 644 "$latest/keyd-default.conf" /etc/keyd/default.conf
  sudo systemctl restart keyd.service || true
elif grep -qx '/etc/keyd/default.conf' "$latest/created.txt" 2>/dev/null; then
  sudo rm -f /etc/keyd/default.conf
  sudo systemctl restart keyd.service || true
fi

if [[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; then
  fcitx5 -d >/dev/null 2>&1 || true
fi

echo "Restored $latest"
echo "Packages were left installed. User dictionaries were left in place."
