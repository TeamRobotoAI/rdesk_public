# 📖 R-Desk Comprehensive Installation Guide

This guide provides step-by-step instructions for installing and configuring the **R-Desk Remote Desktop Client** on Windows and Linux systems.

---

## 🪟 Windows Installation

R-Desk is distributed as a fully self-contained installer for both standard 64-bit (x64) PCs and Windows on ARM (ARM64) devices.

### 1. Select the Correct Installer
* **Standard PC (Intel/AMD x64):** Download `r_desk_1.0.1_x64_setup.exe` from the `windows/stable/version/1.0.1/` directory.
* **ARM Laptops (Snapdragon X Elite, Surface Pro 9/11):** Download `r_desk_1.0.1_arm64_setup.exe` from the `windows/stable/version/1.0.1/` directory.

### 2. Run the Setup Wizard
1. Double-click the downloaded `.exe` file.
2. **SmartScreen Notice:** If Microsoft Defender SmartScreen displays a "Windows protected your PC" prompt (common for new release binaries), click **More info** and then click **Run anyway**.
3. Follow the on-screen installation wizard to choose your installation directory and create desktop shortcuts.
4. Click **Install** and wait for the process to complete.

### 3. Launching R-Desk
Once installed, launch **R-Desk** from your desktop shortcut or Start Menu. The application will automatically generate your secure AnyDesk-compatible R-Desk ID for remote access.

---

## 🐧 Linux Installation

R-Desk provides native Debian (`.deb`) packages for x86_64 (AMD64) workstations and ARM64 single-board computers/robotics controllers. We have unified the installation process into a single, automated script.

### 1. Run the Unified Installer (Recommended)

Our `install.sh` script automatically detects your architecture, installs the right `.deb` package securely via `sudo dpkg -i`, and configures all necessary remote control permissions in one step.

You can download and run the unified installer in a single line command:

```bash
curl -L https://raw.githubusercontent.com/TeamRobotoAI/rdesk_public/main/linux/stable/version/1.0.1/install.sh -o install.sh && curl -L https://raw.githubusercontent.com/TeamRobotoAI/rdesk_public/main/linux/stable/version/1.0.1/setup.sh -o setup.sh && chmod +x install.sh setup.sh && ./install.sh
```

**What the script does:**
* Detects your CPU architecture (AMD64 vs ARM64).
* Installs the corresponding `.deb` package securely via `sudo dpkg -i`.
* Executes `setup.sh` to configure `uinput` kernel permissions and input group memberships.
* Checks for XDG Desktop Portal dependencies for Wayland compatibility.

> [!IMPORTANT]
> **Reboot or Log Out:** For the user group permission changes to take full effect in your desktop environment, you **must log out and log back in** (or restart your computer) after the installation finishes.

---

### 2. Manual Installation (For Advanced Users)

If you prefer to install packages and configure permissions manually without the automated script, follow these steps:

#### A. Install the `.deb` Package
```bash
# For AMD64 (x86_64) systems:
sudo dpkg -i ./linux/r_desk_1.0.1_compatible_amd64.deb
sudo apt install -f # to resolve any missing dependencies

# For ARM64 (aarch64) systems:
sudo dpkg -i ./linux/r_desk_1.0.1_arm64.deb
sudo apt install -f # to resolve any missing dependencies
```

#### B. Configure Remote Control Permissions
By default, Linux security prevents remote apps from injecting keyboard and mouse events. To enable remote control manually:

```bash
# 1. Ensure uinput kernel module is loaded
sudo modprobe uinput
echo "uinput" | sudo tee /etc/modules-load.d/uinput.conf

# 2. Create udev rule for /dev/uinput
sudo tee /etc/udev/rules.d/99-uinput.rules <<'EOF'
KERNEL=="uinput", MODE="0660", GROUP="input", TAG+="uaccess"
EOF

# 3. Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# 4. Add your user to the 'input' group
sudo usermod -aG input "$USER"
```

---

## 🖥️ Screen Capture Compatibility (Wayland vs. X11)

R-Desk supports both X11 and modern Wayland display servers.
* **X11:** Works out of the box with zero additional configuration.
* **Wayland:** Relies on XDG Desktop Portals (`xdg-desktop-portal`). When an incoming session connects, Wayland will prompt you to select the screen or window you wish to share. Ensure portals are installed on your system:
  ```bash
  sudo apt install xdg-desktop-portal xdg-desktop-portal-gtk
  ```

---

## ❓ Next Steps & Troubleshooting
* Having trouble connecting or experiencing permission issues? Check our [Troubleshooting Guide (TROUBLESHOOTING.md)](TROUBLESHOOTING.md).
* For enterprise deployment or fleet provisioning, contact support at [https://rdesk.robotoai.com](https://rdesk.robotoai.com).
