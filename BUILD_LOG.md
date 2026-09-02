=== Day 0 ===

Rocky Linux 9.8 installed via KVM over Arch Linux system.
Language set to English (US) and Local (UTM -6:00) time.
"Minimal Install" is chosen to reflect best practices in security by reducing attack surface and resource usage.

Partitioning:
  A custom partitioning scheme is selected to ensure that boot and root are utilizing the XFS filesystem and root and swap are configured for LVM.
  XFS is preferred over ext4 due to its better journaling, SELinux compatibility, snapshot capability, and large file performance.
  LVM is preferred over standard partitioning due to its ability to extend partitions over multiple physical drives and flexibility with drive management in the future.
  Boot is intentionally left as a standard partition type to maintain compatibility with bootloaders. A resilient system will also see this partition not needing to be extended.
  Root and swap are ensured to be encrypted upon creation.
  An appropriately strong decryption passphrase is entered into the field.

Root user password set to a strong password that differs from decryption password.
Root user account locked and disabled via SSH.
Standard user account created with sudo privileges, adhering to the principle of least privilege.

First Boot:
  User is logged in to the Rocky Linux VM via SSH from Arch Linux system.
  A few checks are made to ensure a successful installation. See Day0.log for full information.

  --- A Note On Encryption ---
	For this lab, LUKS encryption is used for physical security, aligning with at-home philosophy. This presents a problem in High Availability production servers that are
	administrated remotely: the passphrase must be entered manually in the console on the physical machine. In HIPAA compliant systems, this is handled by a TPM or /boot
	contained keyfile. In cloud servers, transparent encryption is provided by the infrastructure at the storage level, removing the need for OS level LUKS encryption.
	This homelab is meant to mimic production servers in industry, so an automatic unlocking keyfile is created by doing the following:

	-The server is shutdown to enable emulated TPM 2.0.
	-In the Virtual Machine Manager, "Add Hardware" is selected with TIS as the interface and 2.0 as the version.
	-TIS is chosen over CRB for maximum compatibility.
	-The setting "Emulated" is chosen over "Passthrough" to avoid conflicts with host machine.
	-The server is restarted and the user is once again logged in via SSH.
	-blkid is used to identify the UUID for the crypto-LUKS partition.
	-systemd-cryptenroll is used to enroll the TPM2 key into the LUKS superblock, identified by UUID.
	-/etc/crypttab is edited to enable LUKS to use TPM2.
	-The initramfs is rebuilt using dracut -f
	-The server is rebooted to confirm TPM automatic unlocking functions.
		--This configuration results in a bootloop where TPM failed. See the file /docs/troubleshooting/TPM Boot Failure.md for details and recovery method used.

=== Day 1 ===

User is logged in over SSH.
Static IP is configured for Rocky installation using nmcli. The process is intentionally left out of the log file to protect sensitive information. synopsis as follows:
  inet IPv4 and MAC are found using ip addr show.
  Gateway is found using ip route show.
  nmcli is used to set a profile name static-eth0 with the values found above and ipv4.method set to manual.
  The profile is then activated and set to up.
  Hostname and IP are added to /etc/hosts on Arch machine.

A full system update is performed using dnf update -y to ensure critical security patches are applied prior to hardening and system is free of known CVEs.
A check is performed to look for an updated kernel using rmp -q kernel. In this instance, the running kernel is different from the installed kernel, so a system reboot is performed.
Once the server is pushed to production, necessary reboots will be scheduled for times that least impact user experience.
The above TPM configuration and resultant failure occured here.
The write-up for my troubleshooting process is found at /docs/troubleshooting/TPM Boot Failure.md.
