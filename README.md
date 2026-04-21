<div align="center">

# 🛡️ GateKeeper

**A production-grade DevSecOps platform enforcing Security-as-Code at every stage of the CI/CD lifecycle.**

![HCL](https://img.shields.io/badge/HCL-33.3%25-844FBA?style=for-the-badge&logo=terraform&logoColor=white)
![Java](https://img.shields.io/badge/Java-29.2%25-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-24.0%25-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Dockerfile](https://img.shields.io/badge/Docker-13.1%25-2496ED?style=for-the-badge&logo=docker&logoColor=white)

![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-D24939?style=flat-square&logo=jenkins&logoColor=white)
![SonarQube](https://img.shields.io/badge/SonarQube-SAST-4E9BCD?style=flat-square&logo=sonarqube&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-SCA-1904DA?style=flat-square&logo=aqua&logoColor=white)
![Gitleaks](https://img.shields.io/badge/Gitleaks-Secrets-red?style=flat-square)
![Terraform](https://img.shields.io/badge/Terraform-IaC-623CE4?style=flat-square&logo=terraform&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Orchestration-326CE5?style=flat-square&logo=kubernetes&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-Monitoring-E6522C?style=flat-square&logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-Dashboards-F46800?style=flat-square&logo=grafana&logoColor=white)

</div>

---

## Overview

GateKeeper is a six-module DevSecOps pipeline platform that treats security as a first-class engineering concern. Rather than bolting security on at the end, every stage of the delivery pipeline enforces automated security gates — from static analysis and secret detection to container scanning and infrastructure hardening.

Vulnerabilities are caught **before they ship**, not after.

---

## Pipeline Architecture

```
Webhook → Jenkins → [SAST + Secret Scan] (parallel) → Docker Build + SCA → IaC + Provision → Blue-Green Deploy
                                                                                                      ↓
                                                                                    Prometheus / Grafana / ELK
```

The pipeline runs 12 services locally via Docker Compose and deploys to Kubernetes using a blue-green strategy for zero-downtime releases.

---

## Modules

| # | Module | Tools |
|---|--------|-------|
| 1 | Build Triggering | Jenkins, Hardened Docker Agent |
| 2 | Static Analysis & Linting | SonarQube 10.3, Checkstyle |
| 3 | Container Build & SCA | Hadolint, Trivy 0.48.3 |
| 4 | Secret Detection | Gitleaks 8.18.1 |
| 5 | IaC & Blue-Green Deploy | Terraform, Ansible, Kubernetes |
| 6 | Observability | Prometheus 2.49, Grafana 10.3, ELK Stack |

---

## Security Gate Logic

Every pipeline run passes through an automated decision tree before any deployment is permitted:

```
secrets found?       → ABORT immediately
SAST quality gate?   → FAIL with report
critical CVEs?       → FAIL with report
all clear?           → DEPLOY via blue-green
```

No manual override. No exceptions. Security gates are non-negotiable.

---

## Sample Application & Seeded Vulnerabilities

The platform ships with a three-tier Spring Boot microservices application (API Gateway, User Service, Order Service) containing **6 intentionally seeded vulnerabilities** to validate each gate:

| Vulnerability | Type | Detected By |
|---------------|------|-------------|
| SQL Injection | SAST | SonarQube |
| Path Traversal | SAST | SonarQube |
| XXE Injection | SAST | SonarQube |
| Log4Shell (CVE-2021-44228) | SCA | Trivy |
| CVE-2023-28858 | SCA | Trivy |
| Hardcoded API Key | Secret | Gitleaks |

All six are detected and blocked automatically — no manual review required.

---

## Quick Start

```bash
# Start all 12 services locally
docker-compose up -d
```

| Service | URL |
|---------|-----|
| Jenkins | http://localhost:8080 |
| SonarQube | http://localhost:9000 |
| Grafana | http://localhost:3000 |
| Prometheus | http://localhost:9090 |
| Kibana | http://localhost:5601 |

For full setup instructions, see [docs/setup.md](./docs/setup.md).

---

## Project Structure

```
GateKeeper/
├── Jenkinsfile                 # Full declarative pipeline
├── Dockerfile                  # Hardened application image
├── docker-compose.yml          # Local dev stack (12 services)
├── app/                        # Spring Boot microservices
├── terraform/                  # IaC modules (EKS, RBAC, NetworkPolicies)
├── ansible/                    # CIS Level 1 hardening playbooks
├── kubernetes/                 # Blue-green deployments, RBAC, monitoring
├── monitoring/                 # Prometheus, Grafana, Logstash, Alertmanager
├── scripts/                    # Blue-green deploy & pre-commit hooks
├── docker/jenkins-agent/       # Hardened build agent
└── docs/setup.md               # Full setup guide
```

---

## Key Design Decisions

- **Parallel security scanning** — SAST and secret detection run concurrently to minimise pipeline duration without sacrificing coverage
- **Hardened build agent** — Jenkins runs inside a custom Docker agent built to CIS benchmarks, so the build environment itself is a security boundary
- **CIS Level 1 hardening** — Ansible playbooks enforce baseline OS hardening on every provisioned node before deployment
- **Blue-green deployments** — Zero-downtime releases with instant rollback capability; production traffic only shifts after health checks pass
- **Full observability stack** — Prometheus metrics, Grafana dashboards, and ELK log aggregation provide end-to-end visibility post-deployment

---

<div align="center">

Built by [Hrishikesh Bywar](https://github.com/DK7705)

</div>
