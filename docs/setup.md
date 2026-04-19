# Secure DevOps Automation Platform — Setup Guide

## Overview

This platform implements a six-module DevSecOps pipeline enforcing "Security as Code" at every stage of the CI/CD lifecycle. The stack is Jenkins-orchestrated, Docker/Kubernetes-based, with a multi-stage Security Gate performing SAST, SCA, and secret detection in parallel.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         SECURITY GATE                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐  │
│  │  SAST + Lint     │  │  Secret Scan     │  │  Container    │  │
│  │  (SonarQube)     │  │  (Gitleaks)      │  │  SCA (Trivy)  │  │
│  └────────┬────────┘  └────────┬────────┘  └───────┬───────┘  │
│           │ PARALLEL           │                    │          │
│           └────────────────────┴────────────────────┘          │
│                              │                                 │
│                    ┌─────────┴─────────┐                       │
│                    │  Decision Engine   │                       │
│                    │  (Early Exit)      │                       │
│                    └─────────┬─────────┘                       │
└──────────────────────────────┼──────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │   IaC + Deploy       │
                    │   (Terraform/Ansible)│
                    └──────────┬──────────┘
                               │
                    ┌──────────┴──────────┐
                    │  Blue-Green Deploy   │
                    │  + Health Checks     │
                    └──────────┬──────────┘
                               │
                    ┌──────────┴──────────┐
                    │   Observability      │
                    │   (Prometheus/ELK)   │
                    └─────────────────────┘
```

## Prerequisites

- **Docker** >= 24.0 with Docker Compose v2
- **Git** >= 2.40
- **Java JDK** 17 (for local builds)
- **Maven** 3.9+ (for local builds)
- **kubectl** >= 1.29 (for Kubernetes deployment)
- **Terraform** >= 1.7.0 (for IaC provisioning)
- **Ansible** >= 9.0 (for configuration management)

### System Requirements

| Component | Minimum RAM | Recommended RAM |
|-----------|-------------|-----------------|
| Jenkins | 2 GB | 4 GB |
| SonarQube | 2 GB | 4 GB |
| Elasticsearch | 2 GB | 4 GB |
| Prometheus + Grafana | 1 GB | 2 GB |
| **Total** | **8 GB** | **16 GB** |

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd secure-devops-platform
```

### 2. Install Pre-commit Hook

```bash
chmod +x scripts/install-pre-commit.sh
./scripts/install-pre-commit.sh
```

This installs Gitleaks as a Git pre-commit hook to scan staged diffs before each commit.

### 3. Start the Local Dev Stack

```bash
docker-compose up -d
```

Wait for all services to be healthy:

```bash
docker-compose ps
```

### 4. Access Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Jenkins | http://localhost:8080 | admin / (initial admin password) |
| SonarQube | http://localhost:9000 | admin / admin |
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | — |
| Kibana | http://localhost:5601 | — |
| Elasticsearch | http://localhost:9200 | — |

### 5. Configure Jenkins

1. Navigate to http://localhost:8080
2. Install suggested plugins plus:
   - Docker Pipeline
   - Pipeline: Stage View
   - SonarQube Scanner
   - Email Extension
   - Slack Notification
   - Prometheus Metrics
3. Configure credentials in **Manage Jenkins → Credentials**:

   | Credential ID | Type | Description |
   |---------------|------|-------------|
   | `sonarqube-token` | Secret text | SonarQube authentication token |
   | `container-registry-creds` | Username/Password | Container registry credentials |
   | `aws-access-key` | Secret text | AWS Access Key ID |
   | `aws-secret-key` | Secret text | AWS Secret Access Key |
   | `kubeconfig` | Secret file | Kubernetes kubeconfig file |
   | `slack-webhook-url` | Secret text | Slack webhook URL |

4. Create a new Pipeline job pointing to the `Jenkinsfile` in the repo root

### 6. Configure SonarQube Quality Gate

1. Navigate to http://localhost:9000
2. Go to **Quality Gates → Create**
3. Configure the following conditions:

   | Metric | Operator | Value |
   |--------|----------|-------|
   | New Critical Issues | greater than | 0 |
   | New Blocker Issues | greater than | 0 |
   | New Major Issues | greater than | 5 |
   | New Coverage | less than | 70% |
   | New Duplicated Lines (%) | greater than | 15% |

4. Set as default Quality Gate

### 7. Configure Webhook (GitHub/GitLab)

#### GitHub Webhook

1. Go to repository **Settings → Webhooks → Add webhook**
2. Payload URL: `http://<jenkins-url>:8080/github-webhook/`
3. Content type: `application/json`
4. Secret: Set HMAC-SHA256 shared secret (configure matching value in Jenkins)
5. Events: Select "Just the push event" and "Pull requests"
6. Filter to branches: `main`, `release/*`

#### GitLab Webhook

1. Go to **Settings → Webhooks**
2. URL: `http://<jenkins-url>:8080/project/<job-name>`
3. Secret Token: Set shared secret
4. Trigger: Push events + Merge request events
5. Branch filter: `main|release/.*`

## Module Details

### Module 1 — Automated Build Triggering

- Jenkins listens for webhook events (push or PR to `main`/`release` branches)
- HMAC-SHA256 webhook validation prevents spoofing
- Ephemeral Docker build agent (`build-agent:hardened-1.2`) spun up per build
- Non-root, no curl/wget in final stage, multi-stage build

### Module 2 — Static Analysis and Linting

- Checkstyle for Java (warnings, not blockers)
- SonarQube SAST with custom Quality Gate (BLOCKING):
  - Zero new Critical/Blocker security vulnerabilities
  - Max 5 new Major issues
  - Min 70% coverage on new code
  - Max 15% duplicated code density

### Module 3 — Container Image Build + SCA

- Hadolint Dockerfile linting (FATAL on violation)
- Trivy SCA on built image (BLOCKING: 0 CRITICAL, max 3 HIGH)
- JSON + table output for machine and human consumption

### Module 4 — Secret Detection

- Gitleaks scans full repo with custom org-specific ruleset
- Any secret found → immediate pipeline abort
- Pre-commit hook for developer workstations

### Module 5 — IaC + Blue-Green Deployment

- tfsec scans Terraform before provisioning
- Terraform plan captured as build artifact
- Ansible CIS Level 1 hardening after provisioning
- Blue-Green deployment with 5-point health check battery
- Automatic rollback on health check failure

### Module 6 — Observability

- Prometheus scrapes all services every 15 seconds
- Alertmanager: error rate >5%, p99 >500ms, crash-looping
- Grafana dashboard with service health, latency, JVM metrics
- ELK Stack for structured log collection and search
- Code-change-to-production correlation

## Security Gate Decision Algorithm

```
if secrets_found > 0:
    CRITICAL_ALERT → ABORT immediately
if sast_quality_gate == FAILED:
    SAST_REPORT → FAIL pipeline
if container_critical_cves > 0:
    SCA_REPORT → FAIL pipeline
PASS → proceed to Deployment
```

## Seeded Vulnerabilities (for validation)

The sample application contains 6 intentional vulnerabilities:

| # | Vulnerability |         Location        | Detected By |
|---|---------------|--------------------------|-------------|
| 1 | SQL Injection | `UserController.searchUsers()` | SonarQube SAST |
| 2 | Path Traversal | `UserController.uploadFile()` | SonarQube SAST |
| 3 | XXE Injection | `UserController.importUsersFromXml()` | SonarQube SAST |
| 4 | Log4Shell CVE-2021-44228 | `api-gateway/pom.xml` (log4j 2.14.1) | Trivy SCA |
| 5 | CVE-2023-28858 | Base image redis-py layer | Trivy SCA |
| 6 | Hardcoded API Key | `application.properties` | Gitleaks |

## Directory Structure

```
/
├── Jenkinsfile                    # Complete declarative pipeline
├── docker-compose.yml             # Local dev stack (12 services)
├── Dockerfile                     # Hardened app Dockerfile
├── .hadolint.yaml                 # Dockerfile linting rules
├── .gitleaks.toml                 # Secret detection config
├── .trivyignore                   # CVE false positive allowlist
├── sonar-project.properties       # SonarQube project config
├── app/                           # Spring Boot microservices
│   ├── pom.xml                    # Parent POM
│   ├── checkstyle.xml             # Checkstyle rules
│   ├── api-gateway/               # API Gateway (port 8080)
│   ├── user-service/              # User Service (port 8081)
│   └── order-service/             # Order Service (port 8082)
├── terraform/                     # Infrastructure as Code
│   ├── main.tf                    # Main config + S3 backend
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Outputs + Ansible inventory
│   └── modules/
│       ├── eks/                   # EKS cluster module
│       ├── namespaces/            # K8s namespaces
│       ├── rbac/                  # RBAC roles/bindings
│       └── network-policies/      # Network policies
├── ansible/                       # Configuration management
│   ├── ansible.cfg
│   ├── inventory
│   └── playbooks/
│       ├── site.yml               # Main playbook
│       └── roles/hardening/       # CIS Level 1 hardening
├── kubernetes/                    # K8s manifests
│   ├── blue-deployment.yaml       # Blue environment
│   ├── green-deployment.yaml      # Green environment
│   ├── service.yaml               # Traffic router + PostgreSQL
│   ├── rbac.yaml                  # RBAC config
│   ├── network-policy.yaml        # Network policies
│   └── monitoring/                # Monitoring stack
│       ├── prometheus.yaml
│       ├── grafana.yaml
│       └── elk-stack.yaml
├── scripts/
│   ├── blue-green-deploy.sh       # Deployment + health checks
│   ├── install-pre-commit.sh      # Gitleaks hook installer
│   └── init-db.sql                # Database initialization
├── monitoring/
│   ├── prometheus.yml             # Prometheus scrape config
│   ├── alertmanager-rules.yml     # Alert rules
│   ├── grafana-dashboard.json     # Grafana dashboard
│   ├── logstash-pipeline.conf     # Logstash pipeline
│   └── elasticsearch-index-template.json
├── docker/
│   └── jenkins-agent/
│       └── Dockerfile             # Hardened build agent
└── docs/
    └── setup.md                   # This file
```

## Troubleshooting

### SonarQube fails to start

```bash
# Increase vm.max_map_count for Elasticsearch
sudo sysctl -w vm.max_map_count=262144
# Persist across reboots
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

### Jenkins cannot access Docker

```bash
# Ensure Docker socket is accessible
sudo chmod 666 /var/run/docker.sock
```

### Elasticsearch out of disk space

```bash
# Clear old indices
curl -X DELETE 'http://localhost:9200/app-logs-*'
```

### Build agent image not found

```bash
# Build the hardened agent image locally
cd docker/jenkins-agent
docker build -t build-agent:hardened-1.2 .
```

## Production Deployment

For production deployment:

1. Replace all `CHANGE_ME` values in Kubernetes Secrets
2. Configure proper TLS certificates
3. Set up proper DNS and ingress controllers
4. Enable Elasticsearch X-Pack security
5. Configure Grafana LDAP/SSO authentication
6. Set up Terraform remote state with proper IAM roles
7. Configure Alertmanager routing to PagerDuty/OpsGenie
8. Enable Kubernetes Pod Security Standards
