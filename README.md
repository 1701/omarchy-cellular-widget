# Cellular (markus.cellular)

An [Omarchy](https://omarchy.org/) bar widget that shows mobile broadband
(WWAN) modem and signal status, and lets you connect, disconnect, forget, or
set up a mobile data connection — without leaving the bar.

## Why a separate widget?

Omarchy's stock `omarchy.network` widget only ever shows whichever
connection currently carries the default route. If Wi-Fi is up, it shows
Wi-Fi — a WWAN/mobile connection running alongside it stays invisible. This
widget fills that gap as an independent icon, so mobile data status is
visible regardless of what else is connected.

## Requirements

- [ModemManager](https://www.freedesktop.org/wiki/Software/ModemManager/)
  installed and running (`systemctl enable --now ModemManager`)
- NetworkManager (standard on Omarchy)
- A modem NetworkManager/ModemManager can see (`mmcli -L`)

## Features

- Bar icon: signal-strength glyph (or "no signal" when disconnected),
  sized to match the other bar icons
- Popup (click the icon):
  - Operator name, connection state, signal %, access technology (e.g. LTE),
    own phone number
  - **Mobile Data** toggle — connects/disconnects the active profile
    (`nmcli connection up/down`)
  - **Forget connection** — deletes the NetworkManager profile, behind a
    confirmation dialog (destructive, no automatic undo)
  - **Set Up Mobile Data** — reappears whenever no profile exists, and
    recreates one

## Installation

```sh
git clone https://github.com/1701/omarchy-cellular-widget.git \
  ~/.config/omarchy/plugins/markus.cellular
omarchy plugin enable markus.cellular --section right
```

## Configuration

The APN and connection name used by "Set Up Mobile Data" are hardcoded in
`Cellular.qml`'s `setupConnection()` — edit that command for your carrier:

```qml
function setupConnection() {
  ...
  actionProc.command = ["bash", "-c",
    "nmcli connection add type gsm ifname cdc-wdm0 con-name '1&1 Mobile' apn internet && nmcli connection up '1&1 Mobile'"]
  ...
}
```

Replace `'1&1 Mobile'` and `apn internet` with your own carrier's connection
name and APN. `ifname cdc-wdm0` assumes a single modem exposing that device
name (check yours with `mmcli -m 0` under "ports").

## Files

| File                    | Purpose                                             |
| ------------------------ | ---------------------------------------------------- |
| `manifest.json`          | Plugin metadata (Omarchy plugin schema)             |
| `Cellular.qml`           | Bar icon + popup UI                                 |
| `cellular-status.sh`     | Polls `mmcli`/`nmcli` for modem/connection state    |

## License

No license specified — ask the author before reuse beyond personal use.
