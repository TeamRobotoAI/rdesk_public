#!/usr/bin/env bash
# ==============================================================================
#  R-Desk — Complete Permission Setup Script
#  Fixes ALL permissions needed for:
#    • Screen capture (X11 + Wayland/PipeWire)
#    • Mouse control & synchronous movement (uinput + XTest)
#    • Keyboard injection (uinput + XTest)
#    • Wayland shortcut inhibition
#
#  Run as a NORMAL USER (not root). sudo is called internally.
#  Usage: bash setup.sh
#
#  After running, LOG OUT and LOG BACK IN (or reboot) for group changes
#  to take effect in your desktop session.
# ==============================================================================
set -euo pipefail

# ─── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}  ✔ ${NC}$*"; }
info() { echo -e "${CYAN}  ➤ ${NC}$*"; }
warn() { echo -e "${YELLOW}  ⚠ ${NC}$*"; }
err()  { echo -e "${RED}  ✖ ${NC}$*"; }
sep()  { echo -e "${BOLD}──────────────────────────────────────────────────────${NC}"; }

# ─── Root guard ────────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  err "Do NOT run as root. Run as your normal user: bash setup.sh"
  exit 1
fi

echo -e "\n${BOLD}${CYAN}R-Desk Permission Setup — $(date)${NC}"
sep

# ──────────────────────────────────────────────────────────────────────────────
# 1. DETECT DISPLAY SERVER
# ──────────────────────────────────────────────────────────────────────────────
sep
echo -e "${BOLD}[1/8] Detecting display server…${NC}"

WAYLAND_SESSION="${WAYLAND_DISPLAY:-}"
X11_SESSION="${DISPLAY:-}"

if [[ -n "$WAYLAND_SESSION" ]]; then
  info "Wayland detected  (WAYLAND_DISPLAY=$WAYLAND_SESSION)"
  DISPLAY_SERVER="wayland"
elif [[ -n "$X11_SESSION" ]]; then
  info "X11 detected      (DISPLAY=$X11_SESSION)"
  DISPLAY_SERVER="x11"
else
  warn "No display detected (headless?). Continuing anyway."
  DISPLAY_SERVER="unknown"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 2. LOAD & PERSIST uinput KERNEL MODULE
#    Required for: mouse movement, mouse click, keyboard injection on Wayland
#    and as the primary backend on X11 for this app.
# ──────────────────────────────────────────────────────────────────────────────
sep
echo -e "${BOLD}[2/8] Loading uinput kernel module…${NC}"

if sudo modprobe uinput 2>/dev/null; then
  ok "uinput module loaded"
else
  warn "modprobe uinput failed — module may not be available on this kernel."
fi

# Persist across reboots
MODULES_LOAD_FILE="/etc/modules-load.d/rdesk-uinput.conf"
if [[ ! -f "$MODULES_LOAD_FILE" ]] || ! grep -q "^uinput" "$MODULES_LOAD_FILE" 2>/dev/null; then
  echo "uinput" | sudo tee "$MODULES_LOAD_FILE" > /dev/null
  ok "uinput persisted → $MODULES_LOAD_FILE"
else
  ok "uinput already persisted in $MODULES_LOAD_FILE"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 3. INSTALL UDEV RULE FOR /dev/uinput
#    Grants read/write access to the 'input' group AND to any logged-in user
#    via uaccess tag (seat-based access — works without group on some DEs).
# ──────────────────────────────────────────────────────────────────────────────
sep
echo -e "${BOLD}[3/8] Installing udev rules for /dev/uinput…${NC}"

UDEV_RULE_FILE="/etc/udev/rules.d/99-rdesk-uinput.rules"
sudo tee "$UDEV_RULE_FILE" > /dev/null << 'UDEV_EOF'
# R-Desk: grant /dev/uinput access to 'input' group AND logged-in seat users.
# TAG+="uaccess" gives access automatically to the active console session user.
KERNEL=="uinput", MODE="0660", GROUP="input", TAG+="uaccess"
UDEV_EOF
ok "Installed udev rule → $UDEV_RULE_FILE"

# ──────────────────────────────────────────────────────────────────────────────
# 4. RELOAD UDEV RULES & RE-TRIGGER DEVICE
# ──────────────────────────────────────────────────────────────────────────────
sep
echo -e "${BOLD}[4/8] Reloading udev rules…${NC}"

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=misc --action=change 2>/dev/null || \
  sudo udevadm trigger
ok "udev rules reloaded and triggered"

# Verify /dev/uinput exists
if [[ -c /dev/uinput ]]; then
  UINPUT_PERMS=$(ls -l /dev/uinput)
  ok "/dev/uinput exists: $UINPUT_PERMS"
else
  warn "/dev/uinput not found — uinput module may need a reboot to appear."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 5. ADD USER TO REQUIRED GROUPS
#    • 'input'   — read/write /dev/uinput, /dev/input/* event devices
#    • 'video'   — some distros gate /dev/dri (GPU/display capture) via this group
#    • 'render'  — DRM render nodes for GPU-based screen capture
# ──────────────────────────────────────────────────────────────────────────────
sep
echo -e "${BOLD}[5/8] Adding '$USER' to required groups…${NC}"

REQUIRED_GROUPS=("input" "video" "render")

for grp in "${REQUIRED_GROUPS[@]}"; do
  if getent group "$grp" > /dev/null 2>&1; then
    if id -nG "$USER" | grep -qw "$grp"; then
      ok "Already in group '$grp'"
    else
      sudo usermod -aG "$grp" "$USER"
      ok "Added to group '$grp'"
    fi
  else
    warn "Group '$grp' does not exist on this system — skipping"
  fi
done

# ──────────────────────────────────────────────────────────────────────────────
# 6. INSTALL SCREEN CAPTURE DEPENDENCIES
#    X11:     No extra packages needed (XShm / XComposite used directly)
#    Wayland: Requires xdg-desktop-portal + backend (GNOME or GTK or wlr)
#             PipeWire for video stream capture
# ──────────────────────────────────────────────────────────────────────────────
sep
echo -e "${BOLD}[6/8] Installing screen capture & control dependencies…${NC}"

install_pkg() {
  # Install a package if not already present. Works on apt-based distros.
  local pkg="$1"
  if dpkg -s "$pkg" &>/dev/null; then
    ok "$pkg already installed"
  else
    info "Installing $pkg…"
    if sudo apt-get install -y -qq "$pkg" &>/dev/null; then
      ok "$pkg installed"
    else
      warn "$pkg — install failed (may not exist in your repos)"
    fi
  fi
}

if command -v apt-get &>/dev/null; then
  sudo apt-get update -qq 2>/dev/null || true

  # Core portal infrastructure
  install_pkg "xdg-desktop-portal"
  install_pkg "xdg-desktop-portal-gtk"

  # PipeWire screen capture (Wayland)
  install_pkg "pipewire"
  install_pkg "wireplumber"
  install_pkg "libpipewire-0.3-0"
  install_pkg "gstreamer1.0-pipewire"          # optional but useful

  # XTest library (X11 keyboard/mouse injection fallback)
  install_pkg "libxtst6"

  # Wayland shortcut inhibition (GTK3 portal)
  install_pkg "libgtk-3-0"

  # GNOME / KDE desktop portal backends (install what's available)
  install_pkg "xdg-desktop-portal-gnome" || true
  install_pkg "xdg-desktop-portal-kde"   || true
  install_pkg "xdg-desktop-portal-wlr"   || true  # wlroots compositors (sway, etc.)

elif command -v dnf &>/dev/null; then
  info "DNF-based system detected — installing equivalents…"
  sudo dnf install -y xdg-desktop-portal xdg-desktop-portal-gtk pipewire wireplumber \
       libXtst gtk3 2>/dev/null || warn "Some packages may have failed"
  ok "DNF package install attempted"

elif command -v pacman &>/dev/null; then
  info "Arch-based system detected — installing equivalents…"
  sudo pacman -Sy --noconfirm xdg-desktop-portal xdg-desktop-portal-gtk pipewire \
       wireplumber libxtst gtk3 2>/dev/null || warn "Some packages may have failed"
  ok "Pacman package install attempted"

else
  warn "Unknown package manager — please manually install:"
  warn "  xdg-desktop-portal, xdg-desktop-portal-gtk, pipewire, libxtst, gtk3"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 7. XTEST / X11 DISPLAY PERMISSION (for X11 sessions)
#    'xhost +local:' allows local connections. Required if running as a
#    different user or inside a container.
# ──────────────────────────────────────────────────────────────────────────────
sep
echo -e "${BOLD}[7/8] Configuring X11 XTest display access…${NC}"

if [[ "$DISPLAY_SERVER" == "x11" ]] && command -v xhost &>/dev/null; then
  xhost +local: 2>/dev/null && ok "xhost +local: — local X11 access granted" \
    || warn "xhost failed (may not matter if running same user)"

  # Also add to .xsessionrc for persistence on login
  XSESSION_RC="$HOME/.xsessionrc"
  if [[ -f "$XSESSION_RC" ]] && grep -q "xhost +local:" "$XSESSION_RC" 2>/dev/null; then
    ok "xhost already persisted in $XSESSION_RC"
  else
    echo "xhost +local:" >> "$XSESSION_RC"
    ok "Persisted xhost +local: → $XSESSION_RC"
  fi
elif [[ "$DISPLAY_SERVER" == "wayland" ]]; then
  info "Wayland session — X11 xhost not needed. uinput handles all input."
else
  warn "No DISPLAY set — xhost skipped"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 8. FIX /dev/uinput PERMISSIONS IMMEDIATELY (without full reboot)
#    Gives the current user DIRECT access right now so the app works
#    immediately after running this script (without logout/login).
# ──────────────────────────────────────────────────────────────────────────────
sep
echo -e "${BOLD}[8/8] Applying immediate /dev/uinput access (no logout required)…${NC}"

if [[ -c /dev/uinput ]]; then
  # Method 1: setfacl — gives current user direct rw access instantly
  if command -v setfacl &>/dev/null; then
    sudo setfacl -m "u:${USER}:rw" /dev/uinput && \
      ok "setfacl: /dev/uinput rw access granted to $USER (instant)" || \
      warn "setfacl failed"
  else
    # Method 2: temporarily chmod 0666 (less secure, ok for dev machines)
    sudo chmod 0666 /dev/uinput && \
      ok "chmod 0666 /dev/uinput — immediate access granted" || \
      warn "chmod failed"
    warn "Install 'acl' package for more secure per-user access: sudo apt install acl"
  fi
else
  warn "/dev/uinput not present — skipping immediate permission fix."
  warn "After reboot, it should appear. Run this script again."
fi

# ──────────────────────────────────────────────────────────────────────────────
# FINAL SUMMARY & STATUS
# ──────────────────────────────────────────────────────────────────────────────
sep
echo ""
echo -e "${BOLD}${GREEN}  🎉  PERMISSION SETUP COMPLETE!${NC}"
sep

echo -e "\n${BOLD}Status Report:${NC}"
echo -n "  /dev/uinput:      "
if [[ -c /dev/uinput ]]; then
  echo -e "${GREEN}EXISTS${NC}  $(ls -l /dev/uinput)"
else
  echo -e "${RED}NOT FOUND — reboot may be needed${NC}"
fi

echo -n "  Display server:   "
echo -e "${CYAN}$DISPLAY_SERVER${NC}"

echo -e "\n  ${BOLD}User groups for $USER:${NC}"
id -nG "$USER" | tr ' ' '\n' | grep -E "^(input|video|render)$" | \
  while read -r g; do echo -e "    ${GREEN}✔ $g${NC}"; done
MISSING_GROUPS=()
for grp in input video render; do
  if ! id -nG "$USER" | grep -qw "$grp" && getent group "$grp" &>/dev/null; then
    MISSING_GROUPS+=("$grp")
  fi
done
for g in "${MISSING_GROUPS[@]}"; do echo -e "    ${YELLOW}⚠ $g (will be active after logout/login)${NC}"; done

sep
echo ""
echo -e "${BOLD}${YELLOW}  ⚠  IMPORTANT NEXT STEPS:${NC}"
echo ""
echo -e "  1. ${BOLD}LOG OUT and LOG BACK IN${NC} so group membership ('input') takes permanent effect."
echo ""
echo -e "  2. You can now launch the R-Desk client securely:"
echo -e "     ${CYAN}r_desk${NC}"
echo ""
sep
