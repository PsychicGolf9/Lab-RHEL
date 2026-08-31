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
