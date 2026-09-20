=== Incident: Fresh Minimal Rocky Install Can't Connect To Network ===

Severity: Moderate
Node: RHEL-Lab01
System: Rocky Linux 9.8
Status: Resolved

An intermittent disconnection occurs with the wireless interface after sitting idle.
This causes SSH connections to drop and forces a manual reconnection fromthe machine's console.
If there were no on-site access to the node, the severity of this issue would be Critical and much more difficult to resolve.

Suspected Cause:
    Many Linux distrobutions (Rocky included) ship with a standard power saving setting for the network adapter.
    This causes the WLAN interface to enter a deep sleep state that can't be woken up by the network router.
    If the router tries to re-establish connection during this time, the interface is unresponsive and the connection is dropped.

A drop-in file is created manually in /etc/NetworkManager/conf.d/wifi-powersave.conf to select a powersave option that keeps the interface up at all times.
The file can be found at ./logs/wifi-powersave.conf.
NetworkManager is restarted with systemctl.
Connection automatically connects.
A 24 hour uptime evaluation is conducted and no network disconnects are found.
Ticket resolved.