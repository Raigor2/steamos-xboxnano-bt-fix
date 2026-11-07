#!/bin/bash
# =============================================================================
# xbox-bt-fix.sh — Persistent Xbox Wireless Controller Bluetooth fix for SteamOS
#
# Sets "Privacy = device" in /etc/bluetooth/main.conf and installs a systemd
# service that re-applies it on EVERY boot, before Bluetooth starts. If a
# SteamOS update resets main.conf, the next boot fixes it automatically.
#
# Usage (in Konsole, Desktop Mode):
#   chmod +x xbox-bt-fix.sh
#   sudo ./xbox-bt-fix.sh install     # install + apply now
#   sudo ./xbox-bt-fix.sh status      # check that everything is in place
#   sudo ./xbox-bt-fix.sh uninstall   # remove the service (keeps setting)
# =============================================================================

set -euo pipefail

CONF="/etc/bluetooth/main.conf"
HELPER_DIR="/var/lib/xbox-bt-fix"
HELPER="$HELPER_DIR/apply.sh"
UNIT="/etc/systemd/system/xbox-bt-privacy.service"
BACKUP="$HELPER_DIR/main.conf.original"

die() { echo "ERROR: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run with sudo:  sudo $0 ${1:-install}"

install_fix() {
    mkdir -p "$HELPER_DIR"

    # One-time backup of the original config
    if [ -f "$CONF" ] && [ ! -f "$BACKUP" ]; then
        cp "$CONF" "$BACKUP"
        echo "Backed up original config to $BACKUP"
    fi

    # --- Helper that does the actual edit (idempotent, safe to run every boot)
    cat > "$HELPER" <<'EOF'
#!/bin/bash
CONF="/etc/bluetooth/main.conf"
mkdir -p /etc/bluetooth

# No config at all -> create a minimal one
if [ ! -f "$CONF" ]; then
    printf '[General]\nPrivacy = device\n' > "$CONF"
    exit 0
fi

# Already correct -> nothing to do
if grep -qE '^[[:space:]]*Privacy[[:space:]]*=[[:space:]]*device[[:space:]]*$' "$CONF"; then
    exit 0
fi

if grep -qE '^[[:space:]]*#?[[:space:]]*Privacy[[:space:]]*=' "$CONF"; then
    # Replace the existing (commented or not) Privacy line
    sed -i -E 's/^[[:space:]]*#?[[:space:]]*Privacy[[:space:]]*=.*/Privacy = device/' "$CONF"
elif grep -q '^\[General\]' "$CONF"; then
    # Add it right under [General]
    sed -i '/^\[General\]/a Privacy = device' "$CONF"
else
    # No [General] section -> add one
    printf '\n[General]\nPrivacy = device\n' >> "$CONF"
fi
EOF
    chmod 755 "$HELPER"

    # --- systemd unit: runs before bluetooth.service on every boot
    cat > "$UNIT" <<EOF
[Unit]
Description=Set BlueZ Privacy=device for Xbox Wireless Controllers
Before=bluetooth.service

[Service]
Type=oneshot
ExecStart=$HELPER

[Install]
WantedBy=bluetooth.service
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xbox-bt-privacy.service
    "$HELPER"
    systemctl restart bluetooth

    echo
    echo "Installed. Current setting:"
    grep -nE '^[[:space:]]*Privacy' "$CONF" || true
    echo
    echo "Next: in Bluetooth settings, FORGET the controller and pair it again"
    echo "(hold the pair button on top until the Xbox logo flashes fast)."
}

status_fix() {
    echo "Config line:"
    grep -nE '^[[:space:]]*#?[[:space:]]*Privacy' "$CONF" 2>/dev/null || echo "  (none found)"
    echo
    echo "Service enabled: $(systemctl is-enabled xbox-bt-privacy.service 2>/dev/null || echo no)"
    echo "Helper present:  $([ -x "$HELPER" ] && echo yes || echo no)"
    echo "Bluetooth:       $(systemctl is-active bluetooth 2>/dev/null || echo unknown)"
}

uninstall_fix() {
    systemctl disable xbox-bt-privacy.service 2>/dev/null || true
    rm -f "$UNIT"
    systemctl daemon-reload
    echo "Service removed. main.conf was left as-is."
    if [ -f "$BACKUP" ]; then
        echo "To restore the original config:"
        echo "  sudo cp $BACKUP $CONF && sudo systemctl restart bluetooth"
    fi
}

case "${1:-install}" in
    install)   install_fix ;;
    status)    status_fix ;;
    uninstall) uninstall_fix ;;
    *)         die "Unknown option '$1'. Use: install | status | uninstall" ;;
esac
