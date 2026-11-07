# SteamOS Xbox Controller Bluetooth Fix

A persistent fix for Xbox Wireless Controllers that pair once on a Steam Deck (SteamOS) but then won't reconnect, keep blinking, or randomly drop.

## The problem

Newer Xbox Wireless Controllers (Series X|S, and older models on updated firmware) connect over Bluetooth Low Energy. After pairing, they often reconnect using a randomized **resolvable private address**. With BlueZ's default `Privacy = off`, SteamOS can fail to match that address to the paired controller and ignores it.

## The fix

Set `Privacy = device` in `/etc/bluetooth/main.conf`. This puts the Bluetooth adapter in device privacy mode, so it accepts paired devices whether they use their real address or a private one.

This script also installs a small systemd service that re-applies the setting on **every boot, before Bluetooth starts**. If a SteamOS update resets the config, the next reboot fixes it automatically.

## Install

In Desktop Mode, open **Konsole**.

1. If you've never set a `sudo` password, set one first:
   ```bash
   passwd
   ```
2. Download and run the installer:
   ```bash
   curl -LO https://raw.githubusercontent.com/Raigor2/steamos-xboxnano-bt-fix/main/xbox-bt-fix.sh
   chmod +x xbox-bt-fix.sh
   sudo ./xbox-bt-fix.sh install
   ```
3. In Bluetooth settings, **forget** the controller, then pair it again (hold the pair button on top until the Xbox logo flashes fast).

## Commands

| Command | What it does |
|---|---|
| `sudo ./xbox-bt-fix.sh install` | Applies the fix now and installs the boot service |
| `sudo ./xbox-bt-fix.sh status` | Shows the current setting, service state, and Bluetooth state |
| `sudo ./xbox-bt-fix.sh uninstall` | Removes the boot service (leaves the config as-is and tells you how to restore the backup) |

## FAQ

**Do I need to reinstall after a SteamOS update?**
Usually no. Normal updates keep changes in `/etc`, and the boot service re-applies the setting anyway. After a factory reset or reimage, set your `sudo` password again and re-run `install`. If in doubt, run `status`.

**Does it work in both Desktop Mode and Gaming Mode?**
Yes. Both modes use the same system Bluetooth service.

**Do I need developer mode or `steamos-readonly disable`?**
No. The script only writes to `/etc` and `/var`, which are writable on SteamOS. Nothing in the read-only `/usr` is touched.

## What the script changes

| Path | Purpose |
|---|---|
| `/etc/bluetooth/main.conf` | Sets `Privacy = device` |
| `/etc/systemd/system/xbox-bt-privacy.service` | Re-applies the setting before Bluetooth starts on each boot |
| `/var/lib/xbox-bt-fix/apply.sh` | The idempotent helper the service runs |
| `/var/lib/xbox-bt-fix/main.conf.original` | One-time backup of your original config |

## License

MIT. See [LICENSE](LICENSE).
