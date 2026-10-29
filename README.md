# macitx

Mac + fcitx: A MacOS input method experience for fcitx5.

Caps Lock switches Chinese and English for fcitx5 and [雾凇拼音](https://github.com/iDvel/rime-ice). A short press toggles the language. Holding it is caps lock. The current language shows as **中** or **英** just under the text cursor.

Shift, Ctrl, Ctrl+Shift, and Ctrl+Space do not change the language.

This is the setup used on a niri Wayland session. It is packaged so the same files can be installed on another Arch machine.

## Behavior

| Action | Result |
| --- | --- |
| Caps Lock, released within 300ms | Toggle 中 / 英 |
| Caps Lock, held | Caps lock |
| Focus a text field | Show 中 or 英 under the caret for about a second |
| New window | Starts in English |
| Each window | Remembers its own Chinese/English state |

Rime itself stays in Chinese mode. The language switch is fcitx turning Rime on and off, so two windows can differ. Shift is not a second switch inside Rime.

The caret mark is fcitx's own input-method popup, not a desktop notification. English is a small keyboard entry whose label is 英. Chinese is the first character of the schema name, so 雾凇拼音 is shown as 中·雾凇拼音 and the badge is 中.

## Requirements

- Arch Linux or a derivative that uses pacman (tested on CachyOS)
- A graphical session. Run the installer from a terminal on that session so fcitx inherits Wayland
- The full 雾凇拼音 data package, `rime-ice-git` from archlinuxcn. The pinyin-only package does not ship `rime_ice_suggestion.yaml`
- These packages, installed by `install.sh` when they are missing: `fcitx5`, `fcitx5-rime`, `fcitx5-gtk`, `fcitx5-qt`, `keyd`, `noto-fonts-cjk`

Your user needs to read `/dev/input`. The installer adds you to the `input` group when you are not already in it. That change applies after the next login.

## Install

```bash
git clone https://github.com/YOU/fcitx-caps-zh.git
cd fcitx-caps-zh
./install.sh
```

`install.sh` asks for sudo to install packages, write `/etc/keyd/default.conf`, and start the system `keyd` service. Everything else is installed in your home directory.

It backs up files it replaces under `~/.local/share/fcitx-caps-zh/backups/<timestamp>/`. It does not copy or delete Rime's user dictionary or sync history.

Then focus a text field and tap Caps Lock.

## How it fits together

1. **keyd** grabs the keyboard. A short Caps Lock emits F14. A hold of 300ms emits a real Caps Lock.
2. **niri does not deliver F14 to fcitx**, so fcitx's own hotkey never fires. `im-caps-watch` reads keyd's virtual keyboard and runs `fcitx5-remote -t` on that F14.
3. **fcitx** draws 中 or 英 at the caret when the input method changes and when a text field is focused.
4. **Rime** is configured so Shift, Ctrl, and Caps Lock do not also toggle its internal ascii mode.

If your compositor does deliver F14 to fcitx, one tap would toggle twice and look like a no-op. Disable the watcher and let fcitx handle F14:

```bash
systemctl --user disable --now im-caps-watch.service
```

`TriggerKeys` in `config/fcitx5/config` is already F14.

## Files the installer writes

| Source | Installed to |
| --- | --- |
| `config/keyd/default.conf` | `/etc/keyd/default.conf` |
| `config/fcitx5/config` | `~/.config/fcitx5/config` |
| `config/fcitx5/profile` | `~/.config/fcitx5/profile` |
| `config/fcitx5/conf/classicui.conf` | `~/.config/fcitx5/conf/classicui.conf` |
| `config/fcitx5/inputmethod/direct-en.conf` | `~/.local/share/fcitx5/inputmethod/direct-en.conf` |
| `config/rime/default.custom.yaml` | `~/.local/share/fcitx5/rime/default.custom.yaml` |
| `config/rime/rime_ice.custom.yaml` | `~/.local/share/fcitx5/rime/rime_ice.custom.yaml` |
| `bin/im-caps-tap`, `bin/im-caps-watch` | `~/.local/bin/` |
| `systemd/user/im-caps-watch.service` | `~/.config/systemd/user/` |

The profile replaces the Default input-method group with `direct-en` and `rime`. Other fcitx groups in an existing profile are not preserved. The previous profile is in the backup directory.

To change the hold time, edit the `300` in `config/keyd/default.conf`, reinstall or copy it to `/etc/keyd/default.conf`, and run `sudo systemctl restart keyd`.

## Uninstall

```bash
./uninstall.sh
```

This stops the watcher, restores the newest backup, and restarts keyd and fcitx. Packages stay installed. The user dictionary stays in place.
