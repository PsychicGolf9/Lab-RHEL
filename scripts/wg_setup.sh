#! /usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INVENTORY_FILE="bash_inventory"
HOST_VARS_DIR="$SCRIPT_DIR/../ansible/inventory/host_vars"
VAULT_PASS="$SCRIPT_DIR/../vpass.txt"

# echo "[DEBUG] VAULT_PASS = $VAULT_PASS"
echo "[DEBUG] INVENTORY_FILE = $INVENTORY_FILE"

# Disable history to keep private keys out of userspace
HISTFILE=/dev/null
set +o history

while IFS= read -r node; do
    echo "[DEBUG] processing: '$node'"
    [[ -z "$node" || "$node" =~ ^# ]] && continue

    vault_file="$HOST_VARS_DIR/${node}.yml"

    if [[ ! -f "$vault_file" ]]; then
        touch "$vault_file"
        chmod 0600 "$vault_file"
    fi

    echo "[DEBUG] Checking for WG key vars"
    if grep -q "network_configuration_wg_private_key" "$vault_file" 2>/dev/null; then
        echo "[Skipping] $node -- WG keys already present"
        continue
    fi

    echo "[Generating] $node"

    echo "[DEBUG] running wg genkey..."

    private_key=$(wg genkey)
    echo "[DEBUG] wg genkey succeeded"
    echo "[DEBUG] running wg pubkey..."
    public_key=$(echo "$private_key" | wg pubkey)
    echo "[DEBUG] wg pubkey succeeded"

    echo "[DEBUG] running ansible-vault encrypt_string..."
    encrypted_key=$(ansible-vault encrypt_string "$private_key" \
        --name 'network_configuration_wg_private_key' \
        --vault-password-file "$VAULT_PASS")
    echo "[DEBUG] ansible-vault succeeded"

    # Add blank line separator only if file already has content
    if [[ -s "$vault_file" ]]; then
        echo "" >> "$vault_file"
    fi

    (
        echo "${encrypted_key}"
        echo "network_configuration_wg_public_key: ${public_key}"
    ) >> "$vault_file"

    echo "[Done] $node"

done < "$INVENTORY_FILE"

set -o history
echo "[Complete]"