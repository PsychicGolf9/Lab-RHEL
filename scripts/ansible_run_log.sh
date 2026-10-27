#!/usr/bin/env bash

# This script catches Ansible output for idempotence evidence and logging
# It never captures Vault secrets.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${REPO_ROOT}/ansible"
RUN_ROOT="${REPO_ROOT}/docs/ansible/runs"

# Change these defaults when the script is being used for a different playbook.
# Command-line options can override them.
# PLAYBOOK is relative to the ansible/ directory.

PLAYBOOK=""
PLAYBOOK_FLAGS=()
SERVICES=()
SERVICES_CLI_SET=0

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [OPTIONS] TARGET MODE

The --playbook (-p) option is the only mandatory option.
SERVICES are pulled from docs/ansible/verification/<playbook>.services file when it exists.
SERVICES and playbook flags can be overridden using the options below.

TARGET:
  Ansible inventory host.

MODE:
  first   Apply the selected playbook and capture the initial baseline.
  second  Apply it again and require zero changes, failures, or unreachable hosts to succeed.
  verify  Run read-only service-state checks for SERVICES.
  full    Run first, second, and verify in sequence.

OPTIONS:
  -p, --playbook PATH    Override PLAYBOOK; PATH is relative to ansible/.
  -f, --flags FLAG       Set flags for the selected playbook. Repeatable.
  -s, --service NAME     Set a service to verify. Repeatable; replaces the metadata file.
      --no-services      Clear SERVICES and skip service verification.
  -h, --help             Show this help message.

Examples:
  $(basename "$0") --playbook playbooks/test.yml rhel-lab00 full
  $(basename "$0") --playbook playbooks/test.yml --flags -Kk rhel-lab00 full
  $(basename "$0") --no-services rhel-lab00 full
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  -p | --playbook)
    if [[ $# -lt 2 ]]; then
      printf 'Error: %s requires a path.\n\n' "$1" >&2
      usage
      exit 2
    fi
    PLAYBOOK="$2"
    shift 2
    ;;
  -s | --service)
    if [[ $# -lt 2 ]]; then
      printf 'Error: %s requires a service name.\n\n' "$1" >&2
      usage
      exit 2
    fi
    if ((SERVICES_CLI_SET == 0)); then
      SERVICES=()
      SERVICES_CLI_SET=1
    fi
    SERVICES+=("$2")
    shift 2
    ;;
  --no-services)
    SERVICES=()
    SERVICES_CLI_SET=1
    shift
    ;;
  -f | --flags)
    if [[ $# -lt 2 ]]; then
      printf 'Error: %s requires a flag letter.\n\n' "$1" >&2
      usage
      exit 2
    fi
    PLAYBOOK_FLAGS+=("$2")
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --)
    shift
    break
    ;;
  -*)
    printf 'Error: unknown option: %s\n\n' "$1" >&2
    usage
    exit 2
    ;;
  *)
    break
    ;;
  esac
done

if [[ -z "${PLAYBOOK}" ]]; then
  printf 'Error: --playbook (-p) is required.\n\n' >&2
  usage
  exit 2
fi

TARGET="${1:-}"
MODE="${2:-}"

if [[ -z "${TARGET}" || -z "${MODE}" ]]; then
  usage
  exit 2
fi

case "${MODE}" in
first | second | verify | full) ;;
*)
  printf 'Error: unsupported mode: %s\n\n' "${MODE}" >&2
  usage
  exit 2
  ;;
esac

if [[ ! -d "${ANSIBLE_DIR}" ]]; then
  printf 'Error: Ansible directory not found: %s\n' "${ANSIBLE_DIR}" >&2
  exit 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  printf 'Error: ansible-playbook is not installed or not in PATH.\n' >&2
  exit 1
fi

if ! command -v ansible >/dev/null 2>&1; then
  printf 'Error: ansible is not installed or not in PATH.\n' >&2
  exit 1
fi

if [[ "${PLAYBOOK}" = /* ]]; then
  printf 'Error: PLAYBOOK must be relative to the ansible/ directory: %s\n' "${PLAYBOOK}" >&2
  exit 1
fi

if [[ ! -f "${ANSIBLE_DIR}/${PLAYBOOK}" ]]; then
  printf 'Error: playbook not found: %s\n' "${ANSIBLE_DIR}/${PLAYBOOK}" >&2
  exit 1
fi

if [[ "$(basename -- "${PLAYBOOK}")" == "00-bootstrap.yml" ]]; then
  PLAYBOOK_FLAGS=(-K -k)
fi

PLAYBOOK_NAME="$(basename -- "${PLAYBOOK}")"
METADATA_FILE="${REPO_ROOT}/docs/ansible/verification/${PLAYBOOK_NAME%.*}.services"

load_services_metadata() {
  if ((SERVICES_CLI_SET == 1)); then
    return
  fi

  if [[ ! -f "${METADATA_FILE}" ]]; then
    return
  fi

  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    [[ "${service}" == \#* ]] && continue
    SERVICES+=("${service}")
  done <"${METADATA_FILE}"
}

load_services_metadata

for service in "${SERVICES[@]}"; do
  if [[ ! "${service}" =~ ^[A-Za-z0-9_.:@-]+$ ]]; then
    printf 'Error: invalid service name: %s\n' "${service}" >&2
    exit 1
  fi
done

TARGET_DIR="${RUN_ROOT}/${TARGET}/$(basename "${PLAYBOOK}" .yml)"
mkdir -p "${TARGET_DIR}"

RUN_DATE="$(date -u +%Y-%m-%d)"
RUN_TIME="$(date -u +%H:%M:%S)"
RUN_ID="$(basename "${PLAYBOOK}")-${RUN_DATE}T${RUN_TIME}Z"
COMMIT="$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"

services_as_text() {
  if ((${#SERVICES[@]} == 0)); then
    printf '%s' '(none)'
  else
    printf '%s' "${SERVICES[*]}"
  fi
}

write_metadata() {
  local log_file="$1"
  local phase="$2"

  {
    printf '%s\n' "\$ ansible-playbook ${PLAYBOOK} ${PLAYBOOK_FLAGS[*]} --limit ${TARGET}"
    printf 'Phase: %s\n' "${phase}"
    printf 'UTC start: %s\n' "${RUN_DATE}T${RUN_TIME}Z"
    printf 'Repository commit: %s\n' "${COMMIT}"
    printf 'Playbook: %s\n' "${PLAYBOOK}"
    printf 'Verification Metadata: %s\n' "${METADATA_FILE:-none}"
    printf 'Services configured for verification: %s\n' "$(services_as_text)"
    printf 'Ansible: %s\n' "$(ansible --version | head -n 1)"
    printf '\n--- PLAYBOOK OUTPUT ---\n'
  } >"${log_file}"
}

run_playbook() {
  local phase="$1"
  local log_file="${TARGET_DIR}/${RUN_ID}-${phase}.log"
  local rc=0

  printf 'Capturing %s run for %s: %s\n' "${phase}" "${TARGET}" "${log_file}"
  write_metadata "${log_file}" "${phase}"

  if (
    cd "${ANSIBLE_DIR}" &&
      ansible-playbook "${PLAYBOOK}" "${PLAYBOOK_FLAGS[@]}" --limit "${TARGET}"
  ) 2>&1 | tee -a "${log_file}"; then
    rc=0
  else
    rc="${PIPESTATUS[0]}"
  fi

  {
    printf '\n--- EXIT STATUS: %s ---\n' "${rc}"
    if ((rc == 0)); then
      printf 'Playbook result: PASS\n'
    else
      printf 'Playbook result: FAIL\n'
    fi
  } >>"${log_file}"

  printf 'Playbook %s exit status: %s\n' "${phase}" "${rc}"
  return "${rc}"
}

assert_clean_recap() {
  local log_file="$1"
  local recap

  recap="$(sed 's/\x1b\[[0-9;]*m//g' "${log_file}" | grep -E "^${TARGET}[[:space:]]+.*changed=" | tail -n 1 || true)"

  if [[ -z "${recap}" ]]; then
    printf 'Idempotence assertion failed: no recap line found in %s\n' "${log_file}" >&2
    return 1
  fi

  for field in changed=0 failed=0 unreachable=0; do
    if [[ "${recap}" != *"${field}"* ]]; then
      printf 'Idempotence assertion failed: recap is missing %s\n' "${field}" >&2
      printf 'Recap: %s\n' "${recap}" >&2
      return 1
    fi
  done

  printf 'Idempotence assertion passed: %s\n' "${recap}"
  return 0
}

run_verification() {
  local log_file="${TARGET_DIR}/${RUN_ID}-state-verification.log"
  local rc=0

  printf 'Capturing service verification for %s: %s\n' "${TARGET}" "${log_file}"

  {
    printf '%s\n' "\$ ansible ${TARGET} -b -m command -a 'systemctl is-active SERVICE'"
    printf 'UTC start: %s\n' "${RUN_DATE}T${RUN_TIME}Z"
    printf 'Repository commit: %s\n' "${COMMIT}"
    printf 'Playbook: %s\n' "${PLAYBOOK}"
    printf 'Verification Metadata: %s\n' "${METADATA_FILE:-none}"
    printf 'Services configured for verification: %s\n' "$(services_as_text)"
    printf '\n--- SERVICE STATE ---\n'
  } >"${log_file}"

  if ((${#SERVICES[@]} == 0)); then
    printf 'No services configured; service verification skipped.\n' >>"${log_file}"
  else
    for service in "${SERVICES[@]}"; do
      printf '\n%s\n' "\$ ansible ${TARGET} -b -m command -a 'systemctl is-active ${service}'" >>"${log_file}"
      if (
        cd "${ANSIBLE_DIR}" &&
          ansible "${TARGET}" -b -m ansible.builtin.command \
            -a "systemctl is-active ${service}"
      ) >>"${log_file}" 2>&1; then
        :
      else
        rc=1
      fi
    done
  fi

  printf '\n--- VERIFICATION EXIT STATUS: %s ---\n' "${rc}" >>"${log_file}"
  printf 'Service verification exit status: %s\n' "${rc}"
  return "${rc}"
}

case "${MODE}" in
first)
  run_playbook first
  ;;
second)
  run_playbook second || exit $?
  second_log="${TARGET_DIR}/${RUN_ID}-second.log"
  assert_clean_recap "${second_log}"
  ;;
verify)
  run_verification
  ;;
full)
  run_playbook first || exit $?
  run_playbook second || exit $?
  second_log="${TARGET_DIR}/${RUN_ID}-second.log"
  assert_clean_recap "${second_log}" || exit 1
  run_verification || exit $?
  ;;
esac

printf '\nEvidence directory: %s\n' "${TARGET_DIR}"
printf 'Review logs for secrets before committing to public repository.\n'
