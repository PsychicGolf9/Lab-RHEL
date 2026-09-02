=== Incident: Boot Failure After TPM 2.0 Configuration ===

Severity: Critical
System: Rocky Linux 9.8
Status: Resolved

After configuring systemd-cryptenroll to bind LUKS root partition to an emulated TPM 2.0 chip and adding 'try-tpm2' flag to /etc/crypttab,
the system failed to boot.

Boot process prompts for passphrase instead of unlocking automatically.
The process then hangs at 'Reached Target Basic System'.
Cannot access shell via SSH or console.
Dracut emergency shell does not have 'cryptsetup' binary in initramfs.

Suspected Causes:
	1) try-tpm2 module doesn't exist or loaded wrong drivers.
	2) typing error in crypttab causing an unrecognized device.
	3) TPM token was unsuccessfully loaded to LUKS header.

Inspecting error messages (see /images/dev-rl-root Does Not Exist.png), suspected cause number 2 is most likely.

Rescue Process:
	-The server is shutdown.
	-VM Manager is pointed to the Rocky Linux install ISO.
	-VM is booted to ISO.
	-"Troubleshooting" is selected.
	-"Rescue A Rocky Linux Installation" is selected.
	-Disk is mounted rw automatically.
	-Password is entered to unlock device.
	-chroot /mnt/sysroot to modify /etc/crypttab and other configs if necessary. See /images/chroot.png.
	-/etc/crypttab is checked for typing errors in UUID and that the system is using the appropriate UUID.
	-The UUID is correct, but try-tpm2 is not a valid flag.
	-try-tpm2 is removed from /etc/crypttab flags.
	-tpm2-device=auto is set in its place and x-initrd.attach is added as well.
	-This should cause LVM to start after the LUKS device is decrypted by the initramfs.
	-initramfs is regenerated using dracut -f
	-System is shutdown and booted from internal drive.
	-The issue persists.

Reassessment:
	The option "try-tpm2" is not a valid option.
	The system still falls back to prompting for passphrase, so "tpm-device=auto" does not work either.
	This issue appears to be two separate problems and should be isolated.
	The next step is to remove the TPM configs to see if it is replicated.

Rescue Process:
	-Both versions of rdsosreport.txt are saved to /boot, named rdsosreport.txt and rdsosreport-1.txt respective of their occurances.
	-VM is booted to ISO and previous options are selected to enter chroot environment.
	-rdsosreport.txt and rdsosreport-1.txt are inspected.
	-The boot process seems to hang on resume=/dev/mapper/rl-swap. It is removed from the grub config.
	-/etc/crypttab is edited to remove all flags referring to TPM.
	-The grub config is regenerated using grub2-mkconfig.
	-initramfs is regenerated using dracut -f.
	-System is shutdown and booted from internal drive.
	-The issue persists.
	
Reassessment:
	Issue confirmed to be two separate problems after removing TPM from configs.
	The rdsosreport.txt files need to be reinspected for other possible causes.

Rescue Process:
	-Third rdsosreport.txt saved to /boot and named rdsosreport-2.txt.
	-VM is booted to ISO and previous options are selected to enter chroot environment.
	-Most recent rdsosreport.txt is read through using less.
	-The entry "encountered unknown option 'try-tpm2', ignoring" is found in this rdsosreport.txt file after deleting it from /etc/crypttab.
	-dracut -f is now assumed to be the problem because it isn't writing changes made in /etc/crypttab to initramfs.
	-dracut --force --regenerate-all is run to ensure regeneration across all initramfs images.
	-System is shutdown and booted from internal drive.
	-The issue persists.

Reassessment:
	The issue must be with dracut or the kernel command line arguments.
	Reverting to the original /etc/crypttab will isolate that config file as a possible cause.
	After doing so, TPM can be successfully implemented in a different way.

Rescue Process:
	-VM is booted from ISO and previous otions are selected to enter chroot environment.
	-Original /etc/crypttab file, now renamed /etc/crypttab.bak for safekeeping, is restored to /etc/crypttab.
	-Edited /etc/crypttab is renamed to /etc/crypttab.bak1.
	-System now boots successfully.
	-Issue was found to be a missing option link-volume-key in /etc/crypttab.
	-/etc/default/grub was edited to include the rd.option=tpm2-device=auto entry.
	-grub2-mkconfig -o /boot/grub2/grub.cfg and dracut --force --regenerate-all are run again to commit changes to /etc/default/grub.
	-System is rebooted.
	-Boot process still prompts for passphrase instead of using TPM.
	-Learning point: the decryption process is handled by initramfs, not kernel arguments.
	-Learning point: RHEL 9.3+ uses grubby instead of direct edits to /etc/default/grub.
	-grubby is used to remove the rd.option from kernel arguments.
	-TPM module is loaded into initramfs using /etc/dracut.conf.d/tpm2.conf.
	-dracut --force --regenerate-all is run to forcefully regenerate initramfs images for all installed kernels.
	-System is rebooted.
	-TPM automatic unlocking feature works as intended.
	-Issue resolved.

Notes:
	Running dracut --force --regenerate-all is not safe practice for production servers.
	It is used in this instance because the server is still undergoing initial configuration.
	Screenshots and logs have been sanitized for any PII but remain limited due to heavy use of editing root configs.
