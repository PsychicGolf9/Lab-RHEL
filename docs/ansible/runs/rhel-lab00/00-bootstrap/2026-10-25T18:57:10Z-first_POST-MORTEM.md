# Post-Mortem: 00-bootstrap.yml Idempotency Failure

**Date:** 2026-10-25
**Severity:** LOW
**Duration:** 18:57Z -> 20:38Z
**Services Affected:** None
**Blast Radius:** rhel-lab00
**Author:** Admin

## Summary

During the idempotency test for 00-bootstrap.yml on rhel-lab00,
the node was unreachable due to a legacy configuration in the play.
The play was updated with the newer wg_check role to ensure reachability
even after SSH is configured to listen only over the WireGuard tunnel.

## Impact

- Users Affected: None
- No customer facing failures
- No revenue lost

## Timeline

All times UTC. Factual, chronological, no interpretation.

| Time (UTC) | Event |
| ------------ | ------- |
| 18:57 | Idempotency test run on node |
| 18:57 | Logs checked |
| 18:59 | Root cause identified |
| 19:01 | Mitigation applied |
| 20:38 | Validation passed |

## Root Cause

Idempotency test failed due to unreachable node.
Upon inspecting 00-bootstrap.yml, the cause was clear due to a hard-coded configuration
using the ansible_host_inet variable, which resolves to an IPv4 address.
The node was configured to listen for SSH over only WireGuard addresses after running
01-base.yml. This breaks any play that needs to run through IPv4.

## Contributing Factors

The WireGuard-only configuration was introduced in a later play (01-base.yml)
without updating the connection method used in 00-bootstrap.yml.

## Mitigation

The reusable role named wg_check was applied and the ansible_host_inet variable
was removed. Idempotency was then validated successfully.

## Action Items

| Action | Owner | Due | Ticket |
| ------ | ----- | --- | ------ |
| wg_check patch | Admin | 2026-10-25 | N/A |

## Lessons Learned

The base configuration for the nodes in this cluster move from
using IPv4 to WireGuard for security.
In automating that, flexibility in roles is required in order to maintain idempotency.
Older playbooks need to be updated regularly and tested thoroughly.

## Notes

The time gap between the mitigation being applied and the validation passed
was due to a bug in the wrapper script that prints Ansible output to logfiles
not being able to parse the flags and allow Ansible to function interactively,
necessary for 00-bootstrap.yml to function properly, not the event itself.
The script was in testing phase and has been updated to allow this critical functionality
in the future.
