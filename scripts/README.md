# Lab-RHEL Helper Scripts

These scripts prepare sensitive Ansible variables that cannot be safely or conveniently created through normal playbook execution. They are intended to be run from the control machine, such as a workstation, rather than from a node managed by Ansible.

## Before running the scripts

The scripts expect the following repository layout:

```text
.
├── vpass.txt
├── ansible/
│   └── inventory/
│       └── host_vars/
└── scripts/
    ├── bash_inventory
    ├── wg_setup.sh
    └── vault-luks-passphrase.sh
```

The scripts resolve these paths relative to their own directory, so they can be run from any working directory.

### Prerequisites

- Bash.
- `ansible-core`, including `ansible-vault`.
- `wg-tools` for `wg_setup.sh`.
- A Vault password file named `vpass.txt` in the repository root.
- A `bash_inventory` file containing one host per line in the scripts directory.
- An existing `ansible/inventory/host_vars/` directory, though individual host.yml files need not be present.

The Vault password file must be restricted to the user running the scripts:

```bash
chmod 600 ../vpass.txt
```

The path to `vpass.txt` must also be configured in `ansible.cfg` so Ansible can decrypt the generated variables later.

## `bash_inventory`

`bash_inventory` is a simple list of the hosts that should receive generated variables. Use one hostname per line:

```text
rhel-lab00
rhel-lab01
```

Blank lines and lines beginning with `#` are ignored.

Populate this file after adding the hosts to `hosts.yml` and before editing their `host_vars` files. The scripts use it to determine which hosts should receive generated values.

## Security and scope

These scripts are helper utilities for preparing Ansible variables. They only create or append data to files under:

```text
ansible/inventory/host_vars/
```

They do **not**:

- Configure WireGuard on a running host.
- Change LUKS volumes.
- Enroll TPM keys.
- Change system passwords.
- Modify running services.
- Apply Ansible playbooks.

Passphrases are read without terminal echo and passed to `ansible-vault` through standard input. The scripts avoid placing passphrases in command-line arguments, environment variables, or plaintext files. Passphrases are still temporarily held in the script process while they are being encrypted.

Review the generated `host_vars` files before running Ansible. Keep `vpass.txt` out of version control and restrict it to mode `0600`.

## `wg_setup.sh`

WireGuard requires several values to configure a peer. Most non-secret values can be stored manually in `hosts.yml` or `group_vars`. A private WireGuard key should not be entered directly into a tracked repository file.

`wg_setup.sh`:

1. Reads the hosts from `bash_inventory`.
2. Generates a unique WireGuard private key for each host.
3. Derives the corresponding public key.
4. Encrypts the private key with Ansible Vault.
5. Appends the encrypted private key and public key to the host’s `host_vars` file.
6. Skips hosts that already contain the expected private-key variable.

Run it with:

```bash
./wg_setup.sh
```

The control machine must have both `wg-tools` and `ansible-core` installed.

This script prepares variables only. WireGuard configuration is applied later by the Ansible role.

## `vault-luks-passphrase.sh`

This script generates Ansible Vault blocks for LUKS passphrases created during a Rocky Linux or RHEL installation. The resulting variables can be used by the optional TPM2/LUKS role when automatic unlocking is explicitly enabled.

The script:

1. Reads the hosts from `bash_inventory`.
2. Prompts for each host’s LUKS passphrase without displaying it.
3. Requests a confirmation entry.
4. Confirms that both entries match.
5. Encrypts the passphrase with Ansible Vault.
6. Appends the encrypted value to that host’s `host_vars` file.
7. Skips hosts that already contain a `tpm2luks_passphrase` variable.

Run it in the default per-host mode with:

```bash
./luks-passphrase.sh
```

The script requires an interactive terminal because it reads passphrases through `/dev/tty`.

Vaulting a LUKS passphrase does not change the LUKS volume, enroll a TPM key, modify `crypttab`, rebuild the initramfs, or enable automatic unlocking. Those actions are handled separately by Ansible when the TPM2 role is explicitly enabled.

### Experimental `--single-password` mode

The optional mode below uses one LUKS passphrase for every selected host that does not already contain a vaulted passphrase:

```bash
./luks-passphrase.sh --single-password
```

This creates a shared secret across those hosts. Anyone who obtains the passphrase for one participating node may be able to unlock every participating node. Reusing one passphrase also makes the reuse visible because the same encrypted value may appear in multiple host_vars files.

Use this mode only for controlled lab testing. Per-host passphrases are strongly recommended for production-like or security-sensitive deployments.

## Idempotence and existing variables

The scripts are designed to avoid overwriting existing values. If the expected variable is already present in a host’s `host_vars` file, that host is skipped.

This also means that changing a WireGuard key or LUKS passphrase requires a deliberate rotation procedure. Do not delete an existing value until the replacement value has been generated, reviewed, and verified through the intended recovery process.

## Recommended procedure

1. Create and secure `vpass.txt`.
2. Add the target hosts to `hosts.yml`.
3. Add those same hostnames to `bash_inventory`.
4. Confirm that any required local public-key files exist.
5. Run the helper scripts.
6. Review the generated `host_vars` files.
7. Confirm that no plaintext secrets were written.
8. Run Ansible syntax checks and variable validation.
9. Apply the appropriate Ansible playbook to the staging node.
10. Test the result before promoting the configuration to another node.

These scripts support batch preparation of Ansible variables. They do not replace testing, review, or the recovery procedures required before applying security-sensitive configuration to a node.
