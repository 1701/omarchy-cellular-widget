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

## Getting the modem working at all

The widget only shows what ModemManager/NetworkManager already know about —
if your modem never gets that far, no icon or config change here will help.
Two issues are common enough to check first (this is what it took on a
ThinkPad with a Quectel EM05-G; the same two checks apply broadly):

1. **ModemManager isn't installed by default on Omarchy.** Only
   `libmm-glib` (a library some other package pulls in as a dependency)
   ships by default — the actual daemon does not. Without it, NetworkManager
   never sees the modem as a `gsm` device at all, no matter how correctly
   the kernel enumerated it.

   ```sh
   sudo pacman -S modemmanager
   sudo systemctl enable --now ModemManager
   ```

2. **FCC unlock.** Many USB WWAN modules (Quectel, Fibocom, etc.) ship in a
   radio-locked state until a host-side "unlock" step runs, per US FCC
   modular-transmitter rules. ModemManager already ships the unlock scripts
   for known modems — under `/usr/share/ModemManager/fcc-unlock.available.d/`
   — nothing to write yourself. It only *enables* one automatically for USB
   IDs it recognizes, though, and newer hardware revisions often report a
   different ID than the one ModemManager's database expects. Symptom: the
   modem is visible (`mmcli -L`) but refuses to come up, e.g.
   `AT+CFUN=1` → `+CME ERROR: 3`, or ModemManager logs
   `Cannot power-up: sotware radio switch is OFF` — easy to mistake for a
   hardware/BIOS radio-kill switch, but it isn't one.

   Check your modem's USB ID and whether a matching script is merely
   un-enabled:

   ```sh
   lsusb | grep -iE 'qualcomm|quectel|fibocom'  # find vendor:product, e.g. 2c7c:0313
   ls /usr/share/ModemManager/fcc-unlock.available.d/   # is your ID listed?
   ls /etc/ModemManager/fcc-unlock.d/                   # is it enabled here?
   ```

   If the ID exists in `available.d` but not in `fcc-unlock.d`, enable it
   with a symlink and restart ModemManager:

   ```sh
   sudo ln -s /usr/share/ModemManager/fcc-unlock.available.d/2c7c:0313 \
     /etc/ModemManager/fcc-unlock.d/2c7c:0313
   sudo systemctl restart ModemManager
   ```

   (Swap `2c7c:0313` for your own modem's actual USB ID.)

Once `mmcli -L` shows the modem and `mmcli -m 0` reports a `registered` or
`connected` state, create a NetworkManager profile for your carrier (see
[Configuration](#configuration) below) and the widget will pick it up.

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
