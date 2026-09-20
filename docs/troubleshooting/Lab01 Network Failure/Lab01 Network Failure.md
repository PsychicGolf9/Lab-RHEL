=== Incident: Fresh Minimal Rocky Install Can't Connect To Network ===

Severity: High
Node: RHEL-Lab01
System: Rocky Linux 9.8
Status: Resolved

During the initial boot on the physical machine, rhel-lab01, SSH is completely unavailable.
Peripherals are moved to the machine to analyze the root cause.
Running nmcli shows that the necessary plugins for the WLAN device. 

Suspected Cause:
    NetworkManager-Wifi is not installed

Options:
    1) Insert Rocky Linux install media and use it as a local repository to install missing packages.
    2) Boot from Arch Linux install media and connect to network via iwd, then mount, bind, and chroot to Rocky installation, install the package with dnf,
       and reboot.

Option 1 is chosen for simplicity and Rocky install USB is inserted, and partition mounted.
Default repositories are disabled and dnf is pointed to the USB.
The package installation fails due to missing dependencies for NetworkManager-Wifi which are not available in the ISO.

Option 2 is attempted, server is shutdown and booted from Arch install media.
The command iwctl is used to connect to the network.
Using cryptsetup and LVM commands, the block is decrypted and mounted to /mnt.
Other system directories are mounted with --bind.
The mounted Rocky system is chrooted into.
From here dnf can be used as if the system were running natively to install NetworkManager-Wifi.
For compatibility with SELinux, touch ./autorelabel is run from the Rocky system root.
The server is rebooted and SELinux triggers a second reboot, which is normal behavior after a chroot rescue.
The system now connects to the Internet using the WLAN interface.
