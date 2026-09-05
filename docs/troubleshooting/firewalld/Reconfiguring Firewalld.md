=== Prevented Incident: Wireguard Lockout After Firewalld Configuration Change ===

Potential Severity: Critical
System: Rocky Linux 9.8
Status: Prevented

Configuration change to Firewalld settings revealed a future issue should the Wireguard tunnel ever go down and back up.

Problem:
	Firewalld default zone is changed to Drop while interface wg0 remains unbound.
	The Wireguard handshake to establish the tunnel is routed through the NIC.
	With the default zone set to Drop, it will refuse to connect on next reboot.
	There is a possibility that the SSH connection is established and run outside of the Wireguard encryption tunnel, directly through the NIC.
	
Cause:
	The SSH service and Wireguard port are bound to the Public zone, but not the interface itself.

Possible Solutions:
	1) Explicitly bind wg0 to the Public zone in the Firewalld config.
	2) Write post-up and post-down lines in /etc/wireguard/wg0.conf.
	3) Use a Firewalld rule to always allow Wireguard at boot.

Chosen route:
	Writing post-up and post-down lines in /etc/wireguard/wg0.conf is selected due to possible race conditions that could appear by explicitly binding wg0
	to the Public zone. It avoids the chance that the Firewalld service starts before Wireguard, causing a missed connection. By using post-down lines, 
	missed connections outside of boot time can also be avoided due to its dynamic nature. This allows the interface to add or remove itself to the Public
	zone on up or down event.

Process:
	Config file /etc/wireguard/wg0.conf is edited to include these lines in the Interface section:
		PostUp = firewall-cmd --permanent --zone=public --add-interface=wg0
		PostUp = firewall-cmd --reload
		PostDown = firewall-cmd --permanent --zone=public --remove-interface=wg0
		PostDown = firewall-cmd --reload
	The rich rule for SSH in the Drop zone is removed since it is now handled by the Public zone.
	Ensure that the Wireguard port and SSH service are added to the Public zone.
	Firewalld is then reloaded.
	A visual confirmation is done for the Public zone using --list-all.

Testing:
	The server is rebooted to check for resolution or possible new conflicts.
	SSH hangs and never connects.

=== Incident: Admin Lockout During Testing procedures ===

Severity: Critical
System: Rocky Linux 9.8
Status: Resolved

Problem:
	SSh is now unreachable due to firewalld and/or Wireguard misconfiguration.

Cause:
	Either Wireguard or Firewalld is misconfigured, causing complete packet loss during handshake.

Possible Solutions:
	1) The hooks added to /etc/wireguard/wg0.conf fail to execute.
	2) wg-quick@wg0 failed to start at boot entirely. This is less likely because it has worked before.
	3) firewalld started after wg-quick@wg0. This is a highly likely race condition.

Recovery procedure:
	Interface is checked for up status. It does not exist.
	The logs are checked using systemctl. A file that has relevant information is created with grep redirected to a log (./logs/wg-sctl.log)
	Log file indicates that wg-quick@wg0 is trying to start before firewalld, failing the postup hook, and exiting without completely initializing.
	The race condition assessment is the most likely candidate now and fix is applied as follows (./logs/override.log for full commands):
		A Systemd override file is created.
		Systemd daemons are reloaded.
		wg-quick@wg0 is restarted.
		wg-quick@wg0 fails to restart with same errors that occured during reboot.
	Logs from both systemctl and journalctl are saved to file and read.
	The errors are exactly the same as before.

Reassessment:
	A race condition most likely exists because interfaces are meant to go up before the firewall configs so the latter knows where to bind them.
	Extensive config editing within Systemd itself might result from trying to get this approach to work.
	The current issue most likely stems from making wg-quick@wg0 perform duties out of its scope.
	Trying to add wg0 to the Public zone explicitly.

Recovery Procedure:
	Systemd override file is deleted.
	Systemd daemons are reloaded.
	Hooks in /etc/wireguard/wg0.conf are removed.
	Interface wg0 is added to the Public zone in Firewalld configuration.
	System is restarted.
	SSH succeeds through the wg0 interface.

Result:
	Lockout caused by Firewalld configuration was resolved by adding interface wg0 to the Public zone directly.

Learning Points:
	Firewalld monitors for interface state automatically, there is no need to configure it with the interface.
	wg-quick@wg0 starts earlier in the boot process than firewalld.
	This will cause race conditions when trying to pass commands to firewalld from a Wireguard config file.
