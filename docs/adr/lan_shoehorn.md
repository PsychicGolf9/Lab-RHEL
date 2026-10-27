# ADR-001: Overriding ansible_host in lan_shoehorn

**Date:** 2026-10-26
**Status:** Implemented

## Context

New nodes are only reachable via IPv4 until WireGuard is installed and
configured. Once sshd is restricted to the WireGuard IP, IPv4 access is gone.

## Decision

Use set_fact in the role to set the connection to use IPv4 for nodes that
cannot connect via WireGuard IP yet. A check task is performed before
Overriding ansible_host to ensure the variable is only mutated for nodes that
don't possess WireGuard connectivity.

## Alternatives Considered

1) A flag variable in host_vars that controls whether the connection goes over
   LAN or WireGuard.
    pros:
      - ansible_host remains unmutated.
      - Idempotency for rerunning 00-bootstrap.yml on established nodes.
    cons:
      - Manual or script controlled variable handling.
      - More moving parts than a probe and set_fact.

2) A first-boot kickstart script that configures WireGuard.
    pros:
      - ansible_host remains unmutated.
      - Ansible only connects over the tunnel.
    cons:
      - Encrypted WireGuard keys are more difficult to handle safely.
      - Added infrastructure script that may fail or not be idempotent.

## Scope

The role is intended to only be used during the bootstrapping process. After
sshd is restricted, lan_shoehorn is intentionally rendered useless.

## Consequences

- Subsequent plays in the same run all connect via IPv4. This is mitigated by
  keeping 00-bootstrap.yml concise.
- No mutation occurs for nodes that pass the check task.
- The role can mask a WireGuard tunnel failure if used outside of its scope or
  if the tunnel goes down before sshd is hardened.
