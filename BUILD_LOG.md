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
		--This configuration results in a bootloop where TPM failed. See the file /docs/troubleshooting/TPM Boot Failure/TPM Boot Failure.md for details and recovery method used.

=== Day 1 ===

User is logged in over SSH.
Static IP is configured for Rocky installation using nmcli. The process is intentionally left out of the log file to protect sensitive information. synopsis as follows:
  inet IPv4 and MAC are found using ip addr show.
  Gateway is found using ip route show.
  nmcli is used to set a profile name static-eth0 with the values found above and ipv4.method set to manual.
  The profile is then activated and set to up.
  Hostname and IP are added to /etc/hosts on Arch machine.

A full system update is performed using dnf update -y to ensure critical security patches are applied prior to hardening and system is free of known CVEs.
A check is performed to look for an updated kernel using rpm -q kernel. In this instance, the running kernel is different from the installed kernel, so a system reboot is performed.
Once the server is pushed to production, necessary reboots will be scheduled for times that least impact user experience.
The above TPM configuration and resultant failure occured here.
The write-up for my troubleshooting process is found at /docs/troubleshooting/TPM Boot Failure/TPM Boot Failure.md.

=== Day 2 ===

User is logged in over SSH.
The hardening process is started by editing /etc/ssh/sshd_config (copy attached in /docs/configs/).
A public SSH key is copied from Arch host machine to Rocky VM using ssh-copy-id admin@rhel-lab00.
A new terminal window is opened to test the key-authenticated login and it succeeds.
/etc/ssh/sshd_config is edited by adding the following to disable root login and password authentication, leaving only ssh key authentication.
	PermitRootLogin no
	PasswordAuthentication no
the key PubkeyAuthentication yes is uncommented to allow using ssh keys.
systemctl is used to restart sshd.

Wireguard is installed to protect admin level SSH access. See /docs/adr/WireGuard.md for decision making process.
Wireguard keys are configured on both server (Rocky) and client (Arch).
System is rebooted to confirm Wireguard interface initializes automatically.
sshd_config.d/99-listen.conf is added to listen only over Wireguard IP to eliminate internet facing attack surface for admin control (file in /configs).

=== Day 3 ===

User is logged in over SSH.
Hardening process is continued by configuring firewalld for strict network security.
Log file for commands can be found at /docs/logs/Day3.log.
During Firewalld configuration, a future issue is noted:
	The current configuration is set to default to the Drop zone for everything, including the Wireguard interface.
	This caused an inability to SSH to the server due to previous sshd_config settings.
	The issue was temporarily remedied by adding the Wireguard subnet and port to the Public zone, but not the interface itself.
	This will cause a broken handshake if wg0 ever goes down and back up.
	It is fixed by adding the Wireguard interface explicitly to the Public zone.
The complete write-up for reconfiguring firewalld is found at /docs/troubleshooting/firewalld.
A complete log of commands used can be found at /docs/troubleshooting/firewalld/logs.

=== Day 4 ===

Ansible is configured to automate playbooks that will reconfigure this exact state if a complete rebuild is required or a physical machine is added to the cluster.
The directory structure is created using mkdir -p ansible/{group_vars,inventory,playbooks,roles}.
The files ansible.cfg and inventory/hosts.yml are configured to find and reach the VM.
A group called "servers" is created preemtively for scalability.
The group_vars/servers.yml file is written to inlude a packages_to_install list for base programs.
The main playbook, site.yml, is written with a short test to ensure dnf and passwordless copying to root files functions as needed.
	
	--- A Note On Ansible ---
		Ansible uses SSH for its functions and requires passwordless privilege escalation in order to automate configurations.
		This causes a security concern if the human user is set to NOPASSWD: ALL in the sudoers file.
		The proper way to handle this is to create a service user for Ansible that doesn't require a password for sudo and authenticates SSH using private keys.
		A log of implementing this configuration can be found at /docs/ansible/Service User/Creating Service User.md

	Note: /ansible/playbooks/00-site.yml will be replaced with something more functional later. It exists currently only as a testing playbook to verify that dnf
		and port checking are present and working. The task that writes a file to /tmp/ is superceded by the adjacent file test.yml.

=== Day 5 ===

Repeatable IaC roles are created and targeted towards scalability.
The goal is to have the folder ansible/ complete every step that has been performed manually thusfar.
This will allow the repository to act like a blueprint for machines that will be added in the future, automating and standardizing their bas configuration.
It will also allow for a complete recovery in the event of hardware failure or other total system compromise.

The overview for roles is be this:
	1. Logs in as admin over SSH and creates a user account for itself with key only authentication and passwordless privilege escalation.
	2. Configures SSH key authentication for user admin.
	3. Edits /etc/ssh/sshd_config to disable root login and password login while enabling public key authentication globally.
	4. Assigns a static IP.
	5. Performs a full system update.
	6. Installs base packages that will be present on all machines.
	7. Configures TPM2 for automatic unlocking at boot time.
	8. Configures Wireguard.
	9. Adds drop-in file to sshd_config.d/ to only allow SSH to listen over Wireguard IP.
	10. Configures Firewalld to adhere to network security practices.

Role 1:
	A directory for this role is created at /ansible/roles/user_a/ and tasks/main.yml is also added.
	The main.yml for user_a is written to satisfy the conditions for the first role.
	With scalability in mind, an SSH Agent is enabled on the control machine and .ssh/config is created to resolve SSH requests externally with registered keys.
	This allows for formatting ansible/inventory/hosts.yml to go through the agent for host resolution instead of Ansible directly, keeping even the paths to private keys out of public repositories.
	A requirements.yml file is created with ansible.posix collection included to allow the repository to be reproduced on other machines.
	A host-specific YAML file is created to store the public key for each host.
	Using one key pair per node keeps the system containerized in the event of SSH compromise on a single node.
	The remote_user field is removed from ansible.cfg to allow the agent config to resolve that as well.

=== Day 6 ===

A new, physical machine is added to the cluster.
The Rocky 9.8 ISO is booted, and a minimal installation is chosen.
A user named admin is created for continuity across nodes and root login is disabled.
All other settings are identical to the VM installation.
	Note:
		This node will be treated as a fault-tolerant production device on the network.
		All configuration will be built by ansible playbooks instead of manually.
		The VM's role in the cluster is now primarily a testing environment for playbooks before getting pushed to production.
		To distinguish between the two, they are named rhel-lab00 and rhel-lab01 for VM and PM respectively.

The first boot of rhel-lab01 resulted in an inability to connect to the network due to missing packages, see docs/troubleshooting/Lab01 Network Failure/ for details.
	Note:
        WLAN is unreliable and has a much slower connection than a wired connection, but the physical lab infrastructure doesn't support ethernet connectivity at
        this time. A wired connection is planned for the future as budget allows.

After Wifi connection is established, an intermittent disconnection is noted where the interface disconnects after sitting idle for longer than 10-15 minutes.
See docs/troubleshooting/Lab01 Network Disconnect/ for details.
	Note:
		After performing the 24 hour evaluation of the issue resulting in system connection stability, an Ansible role will be created to automate this configuration for future nodes.

