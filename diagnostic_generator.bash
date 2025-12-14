#!/bin/bash

# 1. Ask for the password upfront
sudo -v

# 2. Keep the sudo timestamp alive while the script runs
#    (runs a dummy sudo command in the background every 60s)
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Output file name
OUTFILE="system_diagnostics.txt"

# Clear the file to start fresh
: > "$OUTFILE"

echo "Generating report into $OUTFILE..."

# ==============================================================================
# Helper Function: Format and Log
# Arg 1: Human readable description
# Arg 2: The actual command to run
# ==============================================================================
log_cmd() {
    local desc="$1"
    local cmd="$2"

    {
        echo "################################################################################"
        echo "# DESCRIPTION: $desc"
        echo "################################################################################"
        echo "$ $cmd"
        echo "--------------------------------------------------------------------------------"
        
        # Run the command
        # 1. eval allows complex pipes/redirection in the command string
        # 2. cat -s squeezes multiple empty lines into one
        eval "$cmd" 2>&1 | cat -s
        
        echo -e "\n" 
    } >> "$OUTFILE"
}

# ==============================================================================
# GROUP 1: SYSTEM IDENTITY & KERNEL (The Basics)
# ==============================================================================

log_cmd "OS Release Information" \
    "cat /etc/os-release"

log_cmd "Kernel Version (uname)" \
    "uname -a"

log_cmd "Active Kernel Boot Parameters" \
    "cat /proc/cmdline"

log_cmd "Confirm mem_sleep setting" \
    "cat /sys/power/mem_sleep"

log_cmd "Desktop Environment (Hyprland) Version" \
    "hyprctl version"


# ==============================================================================
# GROUP 2: HARDWARE & BUS DRIVERS
# ==============================================================================

log_cmd "Block Devices & Filesystems" \
    "lsblk -f"

log_cmd "USB Bus Check" \
    "lsusb"

log_cmd "Input Devices (evtest list)" \
    "timeout 1s sudo evtest" 
    # NOTE: 'timeout' is used here because evtest waits for user input. 
    # This forces it to just dump the list and exit.

log_cmd "ACPI Wakeup Status" \
    "cat /proc/acpi/wakeup | grep enabled"

# ==============================================================================
# GROUP 3: OTHER HARDWARE AND DRIVER DATA
# ==============================================================================

log_cmd "GPU and Driver In Use" \
    "lspci -k | grep -A 2 -E '(VGA|3D)'"

log_cmd "Hyprland Monitors & Scale" \
    "hyprctl monitors"

log_cmd "Audio Hardware (ALSA)" \
    "aplay -l"

log_cmd "Sound Server Status (PipeWire/WirePlumber)" \
    "wpctl status 2>/dev/null || pactl info"

log_cmd "Bluetooth & Radio Killswitches" \
    "rfkill list"

# ==============================================================================
# GROUP 4: KERNEL MODULES & PACKAGES
# ==============================================================================

log_cmd "Installed Kernel & Header Packages (Pacman)" \
    "pacman -Q linux-t2 linux-t2-headers"

log_cmd "Installed Kernel & Header Packages With Specific Names" \
     "pacman -Q | grep -E 'apple|touch|bce|brcm|tiny|drm|tb'"

log_cmd "Current Running Kernel Release" \
    "uname -r"

log_cmd "DKMS Status (Module Build Status)" \
    "dkms status"

log_cmd "Loaded T2/Apple Specific Modules" \
    "lsmod | grep -E 'apple|touchbar|ibridge|bce|brcm|tiny|tb'"

log_cmd "Module Directory Listing" \
    "ls -ld /lib/modules/\$(uname -r)"

# ==============================================================================
# GROUP 5: CONFIGURATION FILES (Boot & Modprobe)
# ==============================================================================

log_cmd "GRUB Config for Linux T2" \
    "sudo grep -i 'linux-t2' /boot/grub/grub.cfg | head -n 1"

log_cmd "EFI Boot Images" \
    "find /boot/efi -name 'vmlinuz*'"

log_cmd "Modprobe.d Custom Configs" \
    "find /etc/modprobe.d/ -type f -exec printf '\n--- File: %s ---\n' {} \; -exec cat {} \;"

log_cmd "Modules-load.d Custom Configs" \
    "find /etc/modules-load.d/ -type f -exec printf '\n--- File: %s ---\n' {} \; -exec cat {} \;"

log_cmd "UDEV Rules" \
    "ls /etc/udev/rules.d"

# ==============================================================================
# GROUP 6: SYSTEM SERVICES (Systemd)
# ==============================================================================

log_cmd "List All Systemd Units" \
    "systemctl list-units --no-pager"

log_cmd "Service File Content: Suspend T2" \
    "cat /etc/systemd/system/suspend-t2.service"

log_cmd "Attempting to Restart tiny-dfr Service" \
    "sudo systemctl restart tiny-dfr"

log_cmd "Service Status (Suspend, Tiny-DFR, Network)" \
    "systemctl status suspend-t2.service tiny-dfr NetworkManager --no-pager"

log_cmd "Failed Systemd Units" \
    "systemctl --failed --no-pager"

# ==============================================================================
# GROUP 7: LOGS & DIAGNOSTICS (Specific Errors)
# ==============================================================================

log_cmd "Recent Journal Logs for tiny-dfr" \
    "journalctl -xe -u tiny-dfr -n 100 --no-pager"

log_cmd "Kernel Ring Buffer (dmesg) - T2/Apple/Errors" \
    "sudo dmesg | grep -iE 'apple|touchbar|ibridge|bce|brcm|tiny|bce|tb|segfault' | tail -n 50"

log_cmd "Kernel suspend trace" \
    "sudo sh -c 'echo 1 > /sys/power/pm_debug_messages' && sudo journalctl -k -b -1 | grep -i suspend"

log_cmd "Journal entries for kernel related to these specific drivers (limit 500)" \
    "journalctl -b -1 -k -n 500 | grep -E 'bce|brcm|usb|sleep'"
  
log_cmd "Analyze sleep critical chain" \
    "systemd-analyze critical-chain sleep.target"

# ==============================================================================
# GROUP 8: Power and Thermal
# ==============================================================================

log_cmd "Battery Status" \
    "upower -i /org/freedesktop/UPower/devices/battery_BAT0"

log_cmd "Thermal Sensors" \
    "sensors"

# ==============================================================================
# GROUP 9: Critical errors
# ==============================================================================

log_cmd "Critical Errors (Current Boot)" \
    "journalctl -p 3 -xb --no-pager | tail -n 50"

echo "Done. Report saved to $OUTFILE"

