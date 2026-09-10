# Rocky Linux K3s Homelab

This project documents my Rocky Linux homelab as it grows from a single virtual machine into a small K3s cluster. The purpose is to build practical experience with Linux administration, Kubernetes, infrastructure automation, GitOps, monitoring, security, and incident recovery.

The first cluster will run on one VM and expand to three nodes, but the design will remain scalable beyond three nodes. Ansible will handle host and cluster automation. Argo CD will handle GitOps-based delivery. Prometheus and Grafana will provide monitoring and dashboards.

> **Status:** The Rocky Linux foundation is in progress. SSH hardening, encrypted storage, WireGuard administration, firewalld, troubleshooting documentation, and initial Ansible work are already part of the project. K3s and the application services are future phases unless noted otherwise.

## Project goals

- Build a repeatable Rocky Linux foundation for a single-node and multi-node K3s cluster.
- Apply production-oriented security practices to a homelab environment.
- Manage infrastructure and applications through automation and version-controlled configuration.
- Monitor the host, cluster, workloads, storage, and network through useful metrics and alerts.
- Run self-hosted services while documenting their security, availability, backup, and recovery requirements.
- Record failures and recovery procedures instead of documenting only successful deployments.

## Planned architecture

```text
                         Git repository
                               |
                       Argo CD / GitOps
                               |
                 +-------------+-------------+
                 |                           |
          K3s control plane             Applications
                 |                           |
       Prometheus + Grafana       Nextcloud, TES3MP,
       metrics, dashboards,       retro-game streaming,
       alerts, health checks      later Frigate/Jellyfin
                 |
          Rocky Linux nodes
                 |
          VM now; nodes later
                 |
     LUKS encryption, WireGuard,
       SSH hardening, firewalld
                 |
            Homelab hardware
```

The first implementation will use one Rocky Linux VM for control-plane and workload testing. As additional nodes become available, control-plane and worker responsibilities will be separated where that improves reliability and maintenance.

## Platform components

| Layer | Technology | Role in the project |
|---|---|---|
| Operating system | Rocky Linux | RHEL-compatible foundation for administration and platform work. |
| Virtualization | KVM-based VM | Initial deployment boundary and recovery environment. |
| Orchestration | K3s | Lightweight Kubernetes distribution for the cluster. |
| Automation | Ansible | Host preparation, baseline configuration, cluster prerequisites, and repeatable operations. |
| GitOps | Argo CD | Git-based desired state, synchronization, and drift detection. |
| CI | To be selected | Linting, testing, scanning, image builds, and artifact publication. Argo CD will handle delivery and reconciliation. |
| Observability | Prometheus and Grafana | Metrics, dashboards, alerts, and service-health visibility. |
| Administration | SSH over WireGuard | Restricted administrative access through an encrypted management path. |
| Host firewall | firewalld | Explicit network policy at the Rocky Linux host layer. |
| Storage security | LUKS and encrypted application data | Protection for data at rest and practice with encrypted-storage recovery. |
| Secrets | Encrypted or external secret management | Keep credentials and private keys out of plaintext Git files. |

## Services

### Nextcloud

Nextcloud will be the first major application. It will focus on secure configuration, encrypted transport, protected credentials, persistent storage, backups, and restore testing. The documentation will separate protections provided by the application, Kubernetes, and the host.

### TES3MP

TES3MP will provide a stateful multiplayer workload. It will test persistent storage, resource limits, networking, updates, maintenance, and recovery. The deployment will document what level of availability a small homelab can provide.

### Retro-game streaming

A streaming service for systems ranging from the NES through the PS2/Xbox generation will provide a resource-intensive workload. It will test GPU access, scheduling, network performance, storage throughput, user access, and workload isolation.

I will select the emulator and streaming stack after the cluster, storage, and monitoring layers are stable.

### Later applications

Later phases will evaluate:

- **Frigate** for camera and video-analysis workloads.
- **Jellyfin** for media management and streaming.
- A secure end-to-end encrypted messaging server after I document its threat model, maintenance requirements, and exposure risks.

Each application will have documented data sensitivity, authentication, network exposure, backup, and recovery requirements before deployment.

## Security model

Security will be handled in layers across the host, cluster, applications, network, storage, and administrative workflow.

The project will use:

- Minimal Rocky Linux installation where practical.
- LUKS full-disk encryption for data-at-rest protection.
- TPM-backed unlocking experiments where the environment supports them.
- SSH key authentication and disabled direct root login.
- WireGuard-restricted administrative access where practical.
- Explicit firewalld zones and permitted services.
- Least-privilege users, service accounts, namespaces, and Kubernetes permissions.
- Secrets kept out of plaintext Git files.
- TLS for exposed services.
- Regular patching and documented maintenance windows.
- Backups tested through restoration.
- Metrics, dashboards, alerts, and service-health checks.
- Recovery documentation for boot, network, storage, and application failures.

Full-disk encryption is part of this project’s effort to model security practices used in high-security environments. This lab is for learning and portfolio development; encryption by itself does not make an environment HIPAA compliant.

## Automation and GitOps

Ansible will establish and maintain Rocky Linux and K3s prerequisites. Kubernetes manifests or Helm values will define platform and application resources. Argo CD will reconcile the desired state from Git. CI will validate configuration, build and scan artifacts, and publish approved outputs before deployment.

The division of responsibility will be:

- **Ansible:** operating-system configuration, packages, users, SSH, firewall prerequisites, WireGuard, storage preparation, and K3s bootstrap.
- **Kubernetes and Helm:** platform and application resources inside the cluster.
- **Argo CD:** delivery, synchronization, drift detection, and Git-based reconciliation.
- **CI:** linting, manifest validation, image builds, vulnerability scanning, and artifact publication.
- **Git:** reviewed configuration and desired state, with secrets handled through an encrypted or external workflow.

Manual commands will support discovery and recovery. Stable procedures will move into version-controlled automation. A successful `kubectl apply` will not be treated as proof that a deployment is repeatable.

## Observability

Prometheus and Grafana will observe both the platform and its applications. The monitoring stack will cover:

- Node CPU, memory, storage, filesystem, and network metrics.
- K3s control-plane and node health.
- Pod restarts, scheduling failures, resource pressure, and readiness.
- Persistent-volume capacity and errors.
- Application health and performance metrics.
- Certificate and endpoint checks for exposed services.
- Alerts for unavailable workloads, storage exhaustion, repeated restarts, and abnormal resource use.

Dashboards will answer operational questions instead of displaying raw metrics without context. Logs and incident artifacts will retain enough information to reconstruct failures without storing credentials or unnecessary personal information.

## Scaling and availability

The design will scale from one VM to a small multi-node cluster, but three nodes will not automatically create enterprise-grade high availability. Resilience will depend on the K3s control-plane design, storage behavior, network and power dependencies, backup frequency, hardware failure domains, and the ability of each application to run multiple replicas and recover its state.

Each service will have a documented availability target and recovery procedure. The project will not claim high availability where the underlying storage, hardware, or application design does not support it.

## Current project state

The repository currently contains:

- Rocky Linux installation and build notes.
- Encrypted storage and TPM/LUKS troubleshooting.
- SSH key-based access and hardening work.
- WireGuard administrative access.
- firewalld configuration and recovery documentation.
- Sanitized command logs and diagnostic artifacts.
- Initial Ansible inventory, variables, configuration, and playbook work.

The immediate work is to make the Ansible baseline safer and more complete, finish the architecture documentation, and prepare the host for K3s.

## Target project state

When fully developed, this repository will contain:

- A documented Rocky Linux host and multi-node K3s topology.
- Ansible roles for host preparation, SSH, firewalling, WireGuard, and K3s prerequisites.
- K3s installation, node replacement, upgrade, and recovery procedures.
- Prometheus and Grafana dashboards and tested alerts.
- Argo CD applications and Git-based environment configuration.
- CI validation for Ansible, Kubernetes manifests, Helm values, and secret scanning.
- Nextcloud, TES3MP, and retro-game streaming deployments.
- Later deployments for Frigate and Jellyfin where the hardware supports them.
- Backup and restore procedures tested against real service data.
- Runbooks for maintenance, rollback, incident response, and disaster recovery.
- Architecture decision records explaining important design choices.

## Roadmap

### Foundation — current phase

The project is establishing the Rocky Linux foundation. This phase covers encrypted storage, network configuration, SSH hardening, WireGuard, firewalld, TPM/LUKS recovery, troubleshooting records, and a safe Ansible baseline.

### Cluster platform — next phase

The next phase will define the node topology, prepare nodes with Ansible, install K3s, configure storage and ingress, and document node joins, replacements, upgrades, and recovery.

### Platform operations

The platform phase will deploy Prometheus, Grafana, and Argo CD. It will add dashboards, alerts, Git-based environments, CI validation, secret scanning, and drift detection.

### Applications

The application phase will deploy Nextcloud, TES3MP, and the retro-game streaming service. It will then evaluate Frigate, Jellyfin, and an encrypted messaging service based on available hardware, security requirements, and operational cost.

## Repository structure

```text
.
├── ansible/                 # Host and cluster automation
├── docs/
│   ├── adr/                 # Architecture decision records
│   ├── ansible/             # Automation procedures
│   ├── configs/             # Sanitized configuration examples
│   ├── logs/                # Build and command-session records
│   └── troubleshooting/     # Incident reports and recovery evidence
├── images/                  # Supporting screenshots and diagrams
├── BUILD_LOG.md             # Chronological build notes
└── README.md                # Project overview and roadmap
```

## Operating principles

1. Automate repeatable work.
2. Change one major variable at a time.
3. Validate configuration before applying it remotely.
4. Keep a console, recovery, backup, and rollback path.
5. Treat logs as evidence and remove sensitive values before committing them.
6. Use least privilege for people, services, namespaces, and network paths.
7. Document the final state as well as the troubleshooting history.

This is an evolving homelab and portfolio project. Configurations will change as I test, improve, and document the platform.
