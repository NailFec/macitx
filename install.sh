#!/bin/bash
# Install the Caps Lock Chinese/English setup for the user who runs this script.
# Run it from a terminal inside the graphical session. sudo is only used for
# packages, the input group, and the system keyd service.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
USER_NAME=$(id -un)
USER_ID=$(id -u)
BACKUP=${XDG_DATA_HOME:-$HOME/.local/share}/fcitx-caps-zh/backups/$(date +%Y%m%d-%H%M%S)
CREATED=$BACKUP/created.txt

if [[ $USER_ID -eq 0 ]]; then
  echo "Run this as your desktop user, not as root." >&2
  exit 1
fi

need_pkgs=()
for pkg in fcitx5 fcitx5-rime fcitx5-gtk fcitx5-qt keyd noto-fonts-cjk; do
  if ! pacman -Q "$pkg" >/dev/null 2>&1; then
    need_pkgs+=("$pkg")
  fi
done
if ((${#need_pkgs[@]})); then
  echo "Installing: ${need_pkgs[*]}"
  sudo pacman -S --needed --noconfirm "${need_pkgs[@]}"
fi

if [[ ! -f /usr/share/rime-data/rime_ice_suggestion.yaml || ! -f /usr/share/rime-data/rime_ice.schema.yaml ]]; then
  if pacman -Si rime-ice-git >/dev/null 2>&1; then
    echo "Installing rime-ice-git"
    sudo pacman -S --needed --noconfirm rime-ice-git
  fi
fi
if [[ ! -f /usr/share/rime-data/rime_ice_suggestion.yaml ]]; then
  echo "The full 雾凇拼音 package is missing (/usr/share/rime-data/rime_ice_suggestion.yaml)." >&2
  echo "On Arch, enable archlinuxcn and install rime-ice-git. The pinyin-only package is not enough." >&2
  exit 1
fi

mkdir -p "$BACKUP"
touch "$CREATED"

backup_file() {
  local src=$1
  if [[ -e $src ]]; then
    mkdir -p "$BACKUP/$(dirname "${src#$HOME/}")"
    cp -a "$src" "$BACKUP/${src#$HOME/}"
  else
    echo "$src" >>"$CREATED"
  fi
}

install_user_file() {
  local src=$1 dest=$2 mode=$3
  backup_file "$dest"
  mkdir -p "$(dirname "$dest")"
  install -m "$mode" "$src" "$dest"
}

grab_session_env() {
  local pid=$1 item
  [[ -n $pid && -r /proc/$pid/environ ]] || return 0
  while IFS= read -r -d '' item; do
    case $item in
      WAYLAND_DISPLAY=* | DISPLAY=* | XDG_RUNTIME_DIR=* | DBUS_SESSION_BUS_ADDRESS=* | XDG_CURRENT_DESKTOP=* | XDG_SESSION_TYPE=* | XDG_SESSION_DESKTOP=*)
        export "$item"
        ;;
    esac
  done <"/proc/$pid/environ"
}

FCITX_PID=$(pgrep -n -u "$USER_ID" -x fcitx5 || true)
NIRI_PID=$(pgrep -n -u "$USER_ID" -x niri || true)
grab_session_env "${FCITX_PID:-}"
grab_session_env "${NIRI_PID:-}"
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$USER_ID}

install_user_file "$ROOT/config/fcitx5/inputmethod/direct-en.conf" "$HOME/.local/share/fcitx5/inputmethod/direct-en.conf" 644
install_user_file "$ROOT/config/rime/default.custom.yaml" "$HOME/.local/share/fcitx5/rime/default.custom.yaml" 644
install_user_file "$ROOT/config/rime/rime_ice.custom.yaml" "$HOME/.local/share/fcitx5/rime/rime_ice.custom.yaml" 644
install_user_file "$ROOT/bin/im-caps-tap" "$HOME/.local/bin/im-caps-tap" 755
install_user_file "$ROOT/bin/im-caps-watch" "$HOME/.local/bin/im-caps-watch" 755
install_user_file "$ROOT/systemd/user/im-caps-watch.service" "$HOME/.config/systemd/user/im-caps-watch.service" 644

if [[ -f /etc/keyd/default.conf ]]; then
  sudo cp -a /etc/keyd/default.conf "$BACKUP/keyd-default.conf"
  sudo chown "$USER_NAME:$(id -gn)" "$BACKUP/keyd-default.conf"
else
  echo "/etc/keyd/default.conf" >>"$CREATED"
fi
if sudo find /etc/keyd -name '*.conf' ! -name 'default.conf' -print -quit 2>/dev/null | grep -q .; then
  echo "Other files in /etc/keyd are left in place. keyd loads all of them; remove any other capslock binding."
fi
sudo install -d -m 755 /etc/keyd
sudo install -m 644 "$ROOT/config/keyd/default.conf" /etc/keyd/default.conf
sudo systemctl enable --now keyd.service
sudo systemctl restart keyd.service

if ! id -nG "$USER_NAME" | tr ' ' '\n' | grep -qx input; then
  sudo usermod -aG input "$USER_NAME"
  echo "Added $USER_NAME to the input group. Log out and back in so the Caps Lock watcher can read the keyboard."
fi

fcitx5-remote -e >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -u "$USER_ID" -x fcitx5 >/dev/null || break
  sleep 0.2
done
if pgrep -u "$USER_ID" -x fcitx5 >/dev/null; then
  kill "$(pgrep -u "$USER_ID" -x fcitx5)" || true
  sleep 0.3
fi

# fcitx writes its profile on exit, so replace these only after the process is gone.
install_user_file "$ROOT/config/fcitx5/config" "$HOME/.config/fcitx5/config" 644
install_user_file "$ROOT/config/fcitx5/conf/classicui.conf" "$HOME/.config/fcitx5/conf/classicui.conf" 644
install_user_file "$ROOT/config/fcitx5/profile" "$HOME/.config/fcitx5/profile" 644

rime_deployer --build "$HOME/.local/share/fcitx5/rime" /usr/share/rime-data "$HOME/.local/share/fcitx5/rime/build"

if [[ -z ${WAYLAND_DISPLAY:-} && -z ${DISPLAY:-} ]]; then
  echo "No Wayland or X11 display in this shell. Start fcitx from the desktop session, then run: systemctl --user restart im-caps-watch.service" >&2
else
  fcitx5 -d >/dev/null 2>&1 || true
fi

systemctl --user daemon-reload
systemctl --user enable --now im-caps-watch.service

echo
echo "Installed. Backup: $BACKUP"
echo "Focus a text field. A short Caps Lock press toggles 中 and 英 under the cursor."
echo "Hold Caps Lock for caps lock. Shift, Ctrl, and Ctrl+Space do not switch languages."
