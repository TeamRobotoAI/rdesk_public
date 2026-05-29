# 🔧 R-Desk Troubleshooting Guide & FAQ

This document outlines solutions and answers for common issues encountered during the installation, permission configuration, and running of the **R-Desk Remote Desktop Client**.

---

## 📋 Table of Contents
1. [Linux: Remote controller can view screen, but cannot click or type](#1-linux-remote-controller-can-view-screen-but-cannot-click-or-type)
2. [Linux: Black/blank screen or screen sharing prompts fail on Wayland](#2-linux-blackblank-screen-or-screen-sharing-prompts-fail-on-wayland)
3. [Linux: "GLib Symbol Lookup Error" when starting the app](#3-linux-glib-symbol-lookup-error-when-starting-the-app)
4. [Windows: "Windows protected your PC" / SmartScreen warning](#4-windows-windows-protected-your-pc--smartscreen-warning)
5. [General: Robot/IoT device shows "Offline" in fleet management dashboard](#5-general-robotiot-device-shows-offline-in-fleet-management-dashboard)
6. [General: Bidirectional audio is crackling, quiet, or not working](#6-general-bidirectional-audio-is-crackling-quiet-or-not-working)

---

## 1. Linux: Remote controller can view screen, but cannot click or type

### 🔍 Cause
R-Desk requires permission to inject input events via the `/dev/uinput` kernel device. If the current user lacks read/write access to `/dev/uinput`, the remote controller can only view the desktop (Read-Only mode).

### 🛠️ Solution
1. Execute the automated permission script in your terminal:
   ```bash
   ./linux/setup.sh
   ```
2. **Crucial:** You must log out of your system user session completely and log back in, or simply restart the machine for the new group settings to apply.
3. Verify that `/dev/uinput` belongs to the `input` group and is readable/writable:
   ```bash
   ls -l /dev/uinput
   # Output should look like:
   # crw-rw---- 1 root input 10, 223 May 19 10:00 /dev/uinput
   ```
4. If you need to run R-Desk immediately without logging out, run this command to start the app in the current shell context:
   ```bash
   newgrp input
   r_desk
   ```

---

## 2. Linux: Black/blank screen or screen sharing prompts fail on Wayland

### 🔍 Cause
Wayland restricts direct window-capture access for security reasons. Screen capturing under Wayland requires **XDG Desktop Portals** (`xdg-desktop-portal`) and a compatible portal backend (e.g. `xdg-desktop-portal-gtk` or `xdg-desktop-portal-kde`).

### 🛠️ Solution
1. Install the required portal libraries:
   ```bash
   sudo apt update
   sudo apt install xdg-desktop-portal xdg-desktop-portal-gtk
   ```
2. Restart the user session or run the portal services:
   ```bash
   systemctl --user restart xdg-desktop-portal.service
   systemctl --user restart xdg-desktop-portal-gtk.service
   ```
3. When the remote session initiates, a system dialog will appear asking you to choose which monitor or specific window to share. Select your screen and click **Share**.
4. **Alternative:** If your desktop environment supports X11, you can choose **GNOME on Xorg** or **Ubuntu on Xorg** at the login screen. X11 captures screens natively without extra dialog prompts.

---

## 3. Linux: "GLib Symbol Lookup Error" when starting the app

### 🔍 Cause
This happens if the binary was compiled on a newer GLib/glibc environment (e.g. GLib 2.80+) than the one installed on your host system. 

### 🛠️ Solution
Ensure you have downloaded `r_desk_1.0.1_compatible_amd64.deb` instead of a platform-specific package compiled elsewhere. The `amd64` distribution is specifically compiled with Broad Glibc 2.31+ compatibility (compatible with Ubuntu 20.04 LTS and above, Debian 11+, and similar distributions).

---

## 4. Windows: "Windows protected your PC" / SmartScreen warning

### 🔍 Cause
Microsoft Defender SmartScreen flags newly compiled `.exe` installers that do not yet have a widespread global reputation or code-signing certificates.

### 🛠️ Solution
This is a standard behavior for fresh product releases. R-Desk is fully secure and safe:
1. Click the **More info** text link in the blue dialog box.
2. An addition button labelled **Run anyway** will appear at the bottom.
3. Click **Run anyway** to initiate the installer normally.

---

## 5. General: Robot/IoT device shows "Offline" in fleet management dashboard

### 🔍 Cause
The remote robot daemon or management module failed to authenticate or communicate with the signaling and connection coordinator service.

### 🛠️ Solution
1. Ensure the remote device has an active internet/local network connection.
2. Verify the R-Desk signaling client is running on the robot:
   ```bash
   systemctl status rdesk-daemon.service
   ```
3. Check the logs for authentication errors:
   ```bash
   journalctl -u rdesk-daemon.service -n 50
   ```
4. Confirm that the signaling server URI in the robot's configuration file `/etc/rdesk/config.json` is correct and reachable via ping.

---

## 6. General: Bidirectional audio is crackling, quiet, or not working

### 🔍 Cause
This can occur due to WebRTC microphone permission blocks, mismatched system audio sample rates, or muted input/output sliders.

### 🛠️ Solution
1. **Controls:** During an active session, click the Speaker icon in the remote viewer toolbar to open the **Audio Settings Overlay**. Ensure both the Remote System Volume and Local Microphone Volume sliders are raised.
2. **Permissions:**
   * **Linux:** Make sure your user is part of the `audio` group: `sudo usermod -aG audio $USER`.
   * **Windows:** Go to *Settings > Privacy & Security > Microphone* and ensure "Allow apps to access your microphone" is turned On.
3. **Devices:** If you have multiple audio output or capture devices (e.g. HDMI output, USB headset), verify that the correct primary default device is selected in your system settings.

---

## 📞 Still Having Issues?
If you've followed the steps above and are still experiencing issues:
* Open an issue in the [rdesk_public Issues](../../issues) page.
* Visit [https://rdesk.robotoai.com](https://rdesk.robotoai.com) for real-time customer support.
