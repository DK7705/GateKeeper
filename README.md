# Secure DevOps Automation Platform

A six-module DevSecOps pipeline platform enforcing **Security as Code** at every CI/CD stage.

## Architecture

```
Webhook → Jenkins → [SAST + Secret Scan] (parallel) → Docker Build + SCA → IaC + Provision → Blue-Green Deploy
                                                                                                      ↓
                                                                                    Prometheus / Grafana / ELK
```

## Modules

| # | Module | Tools |
|---|--------|-------|
| 1 | Build Triggering | Jenkins, Hardened Docker Agent |
| 2 | Static Analysis & Linting | SonarQube 10.3, Checkstyle |
| 3 | Container Build & SCA | Hadolint, Trivy 0.48.3 |
| 4 | Secret Detection | Gitleaks 8.18.1 |
| 5 | IaC & Blue-Green Deploy | Terraform, Ansible, Kubernetes |
| 6 | Observability | Prometheus 2.49, Grafana 10.3, ELK Stack |

## Security Gate

```
secrets found?       → ABORT immediately
SAST quality gate?   → FAIL with report
critical CVEs?       → FAIL with report
all clear?           → DEPLOY via blue-green
```

## Sample App

Three-tier Spring Boot microservices (API Gateway, User Service, Order Service) with **6 seeded vulnerabilities** for gate validation:

| Vulnerability | Type | Detected By |
|---------------|------|-------------|
| SQL Injection | SAST | SonarQube |
| Path Traversal | SAST | SonarQube |
| XXE Injection | SAST | SonarQube |
| Log4Shell (CVE-2021-44228) | SCA | Trivy |
| CVE-2023-28858 | SCA | Trivy |
| Hardcoded API Key | Secret | Gitleaks |

## Quick Start

```bash
# Start all 12 services locally
docker-compose up -d

# Access
# Jenkins:       http://localhost:8080
# SonarQube:     http://localhost:9000
# Grafana:       http://localhost:3000
# Prometheus:    http://localhost:9090
# Kibana:        http://localhost:5601
```

## Project Structure

```
├── Jenkinsfile                 # Full declarative pipeline
├── Dockerfile                  # Hardened app image
├── docker-compose.yml          # Local dev stack (12 services)
├── app/                        # Spring Boot microservices
├── terraform/                  # IaC modules (EKS, RBAC, NetworkPolicies)
├── ansible/                    # CIS Level 1 hardening playbooks
├── kubernetes/                 # Blue-green deployments, RBAC, monitoring
├── monitoring/                 # Prometheus, Grafana, Logstash, Alertmanager
├── scripts/                    # Blue-green deploy, pre-commit hook
├── docker/jenkins-agent/       # Hardened build agent
└── docs/setup.md               # Full setup guide
```

See [docs/setup.md](docs/setup.md) for detailed setup instructions.
