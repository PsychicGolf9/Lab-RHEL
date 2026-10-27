#! /usr/bin/bash
set -euo pipefail

# !!! Read the README.md file to learn how to use the scripts in this directory !!!
# !!! This script registers the LUKS passphrases for each node in bash_inventory interactively !!!
# !!! It is meant for use with the tpm2 role found in the ansible directory. If you don't need TPM2, you don't need this script !!!

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/bash_inventory"
HOST_VARS_DIR="${SCRIPT_DIR}/../ansible/inventory/host_vars"
VAULT_PASS="${SCRIPT_DIR}/../vpass.txt"

TEMP_FILE=""

HISTFILE=/dev/null
set +o history

# === Require an active terminal ===
if [[ ! -r /dev/tty ]]; then
  echo "[ERROR] An interactive terminal must be used for this process." >&2
  exit 1
fi

# Check deps
if ! command -v ansible-vault >/dev/null 2>&1; then
  echo "[ERROR] ansible-vault command not found."
  echo "        Install ansible-core and re-run script."
  exit 1
fi

echo "[Debug] INVENTORY_FILE = ${INVENTORY_FILE}"
echo "[Debug] HOST_VARS_DIR = ${HOST_VARS_DIR}"

if [[ ! -f "${VAULT_PASS}" ]]; then
  echo "[ERROR] Vault password file not found."
  echo "        You must create a vault password at: ${VAULT_PASS}"
  exit 1
fi

perms=$(stat -c '%a' "${VAULT_PASS}")
if [[ "${perms}" != "600" ]]; then
  echo "[ERROR] Vault password file has insecure permissions: ${perms}"
  echo "        Expected: 600"
  echo "        Enter: chmod 600 ${VAULT_PASS}"
  exit 1
fi

SINGLE_PASSWORD=false
for arg in "$@"; do
  case "${arg}" in
  --single-password) SINGLE_PASSWORD=true ;;
  *)
    echo "[ERROR] Unknown argument: ${arg}. The only permitted argument is --single-password. Read the README." >&2
    exit 1
    ;;
  esac
done

if [[ ! -f "${INVENTORY_FILE}" ]]; then
  echo "[ERROR] ${INVENTORY_FILE} not found. Create bash_inventory file and re-run script."
  exit 1
fi

HOSTS=()
while IFS= read -r host; do
  host="${host//$'\r'/}"
  [[ -z "$host" || "$host" =~ ^[[:space:]]*# ]] && continue
  HOSTS+=("$host")
done <"${INVENTORY_FILE}"

if [[ ${#HOSTS[@]} -eq 0 ]]; then
  echo "[ERROR] ${INVENTORY_FILE} contains no hostnames."
  exit 1
fi

echo ""
echo "=== TPM2 LUKS Passphrase Vaulting ==="
echo "Hosts found: ${#HOSTS[@]}"
printf ' - %s\n' "${HOSTS[@]}"
echo ""

if [[ "${SINGLE_PASSWORD}" == true ]]; then
  echo "Mode: single passphrase for all hosts"
else
  echo "Mode: per-host passphrases"
fi
echo ""

prompt_and_encrypt() {
  local label="$1"
  local pass_a=""
  local pass_b=""

  printf 'Enter LUKS passphrase for %s: ' "${label}" >&2
  read -r -s pass_a </dev/tty
  printf '\n' >&2
  if [[ -z "${pass_a}" ]]; then
    echo "[ERROR] passphrase cannot be empty." >&2
    return 1
  fi

  printf 'Confirm Luks passphrase for %s: ' "${label}" >&2
  read -r -s pass_b </dev/tty
  printf '\n' >&2
  if [[ "${pass_a}" != "${pass_b}" ]]; then
    echo "[ERROR] passphrases do not match for ${label}." >&2
    unset pass_a pass_b
    return 1
  fi

  printf '%s' "${pass_a}" | ansible-vault encrypt_string \
    --stdin-name 'tpm2luks_passphrase' \
    --vault-password-file "${VAULT_PASS}"

  unset pass_a pass_b
}

CIPHERTEXT=""

encrypt_single() {
  local label="$1"
  local pass_a=""
  local pass_b=""

  printf 'Enter LUKS passphrase for %s: ' "${label}" >&2
  read -r -s pass_a </dev/tty
  printf '\n' >&2
  if [[ -z "${pass_a}" ]]; then
    echo "[ERROR] passphrase cannot be empty." >&2
    return 1
  fi

  printf 'Confirm LUKS passphrase for %s: ' "${label}" >&2
  read -r -s pass_b </dev/tty
  printf '\n' >&2
  if [[ "${pass_a}" != "${pass_b}" ]]; then
    echo "Passphrases do not match for ${label}." >&2
    return 1
  fi

  printf '%s' "${pass_a}" | ansible-vault encrypt_string \
    --stdin-name 'tpm2luks_passphrase' \
    --vault-password-file "${VAULT_PASS}"

  unset pass_a pass_b
}

#--- Main Loop ---

for HOST in "${HOSTS[@]}"; do
  HOST_VARS="${HOST_VARS_DIR}/${HOST}.yml"

  #Create if it doesn't exist
  if [[ ! -f "${HOST_VARS}" ]]; then
    touch "${HOST_VARS}"
    chmod 0600 "${HOST_VARS}"
    echo "[Created] ${HOST_VARS}"
  fi

  #Skip if passphrase is already vaulted
  if grep -q "^tpm2luks_passphrase:" "${HOST_VARS}" 2>/dev/null; then
    echo "[Skip] ${HOST} -- tpm2luks_passphrase already vaulted."
    continue
  fi

  #encrypt
  if [[ "${SINGLE_PASSWORD}" == true ]]; then
    if [[ -z "${CIPHERTEXT}" ]]; then
      CIPHERTEXT="$(encrypt_single "${HOST}")" || exit 1
    else
      echo "(Using same passphrase as first host)"
    fi
    VAULT_BLOCK="${CIPHERTEXT}"
  else
    VAULT_BLOCK="$(prompt_and_encrypt "${HOST}")" || exit 1
  fi

  #Append to host_vars
  if [[ -s "${HOST_VARS}" ]]; then
    echo "" >>"${HOST_VARS}"
  fi

  {
    echo "${VAULT_BLOCK}"
  } >>"${HOST_VARS}"

  echo "[Done] ${HOST}"
done

set -o history
echo ""
echo "===Done==="
echo ""
echo "Verify with:"
for HOST in "${HOSTS[@]}"; do
  if [[ -f "${HOST_VARS_DIR}/${HOST}.yml" ]]; then
    echo " ansible ${HOST} -m debug -a 'var=tpm2luks_passphrase' --vault-password-file=${VAULT_PASS}"
  fi
done
