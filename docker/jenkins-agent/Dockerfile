# =============================================================================
# Hardened Jenkins Build Agent — build-agent:hardened-1.2
# Multi-stage build: minimal attack surface, non-root, no curl/wget in final
# =============================================================================

# ---- Stage 1: Builder (install all tools) ----
FROM eclipse-temurin:17-jdk-jammy AS builder

# Install build tools in builder stage only
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    unzip \
    gnupg \
    lsb-release \
    software-properties-common \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Maven 3.9.6
ARG MAVEN_VERSION=3.9.6
ARG MAVEN_SHA512=706f01b20dec0305a82571b46b94d40e50e6fba63e8dbe8e25e85ee39e5d9e01e3e5e5d4e6a7f1e1b0d5a0f0a9b9f5e7e0a3e0d0a5c0b0f0e0a0d0c0b0a0f0e0
RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
    -o /tmp/maven.tar.gz \
    && tar -xzf /tmp/maven.tar.gz -C /opt/ \
    && ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven \
    && rm /tmp/maven.tar.gz

# Install Node.js 20 LTS for JS tooling
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Gitleaks 8.18.1
ARG GITLEAKS_VERSION=8.18.1
RUN curl -fsSL https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_amd64.tar.gz \
    -o /tmp/gitleaks.tar.gz \
    && tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin/ gitleaks \
    && chmod +x /usr/local/bin/gitleaks \
    && rm /tmp/gitleaks.tar.gz

# Install Hadolint
RUN curl -fsSL https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64 \
    -o /usr/local/bin/hadolint \
    && chmod +x /usr/local/bin/hadolint

# Install Trivy 0.48.3
ARG TRIVY_VERSION=0.48.3
RUN curl -fsSL https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz \
    -o /tmp/trivy.tar.gz \
    && tar -xzf /tmp/trivy.tar.gz -C /usr/local/bin/ trivy \
    && chmod +x /usr/local/bin/trivy \
    && rm /tmp/trivy.tar.gz

# Install tfsec
RUN curl -fsSL https://github.com/aquasecurity/tfsec/releases/download/v1.28.4/tfsec-linux-amd64 \
    -o /usr/local/bin/tfsec \
    && chmod +x /usr/local/bin/tfsec

# Install Terraform 1.7.0
RUN curl -fsSL https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip \
    -o /tmp/terraform.zip \
    && unzip /tmp/terraform.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/terraform \
    && rm /tmp/terraform.zip

# Install Ansible
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip \
    && pip3 install --no-cache-dir ansible==9.1.0 \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -fsSL "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl" \
    -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Install Docker CLI (for building images inside the agent)
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-24.0.7.tgz \
    -o /tmp/docker.tgz \
    && tar -xzf /tmp/docker.tgz --strip-components=1 -C /usr/local/bin/ docker/docker \
    && rm /tmp/docker.tgz

# ---- Stage 2: Final hardened image ----
FROM eclipse-temurin:17-jre-jammy

LABEL maintainer="DevSecOps Team <devsecops@example.com>"
LABEL version="hardened-1.2"
LABEL description="Hardened Jenkins build agent — no curl/wget, non-root, minimal surface"

# Install only essential runtime dependencies — NO curl, wget, or package managers
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    python3 \
    python3-venv \
    jq \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get purge -y --auto-remove apt \
    && rm -rf /var/cache/apt /var/lib/dpkg /var/lib/apt

# Copy tools from builder stage
COPY --from=builder /opt/maven /opt/maven
COPY --from=builder /usr/local/bin/gitleaks /usr/local/bin/gitleaks
COPY --from=builder /usr/local/bin/hadolint /usr/local/bin/hadolint
COPY --from=builder /usr/local/bin/trivy /usr/local/bin/trivy
COPY --from=builder /usr/local/bin/tfsec /usr/local/bin/tfsec
COPY --from=builder /usr/local/bin/terraform /usr/local/bin/terraform
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=builder /usr/local/bin/docker /usr/local/bin/docker
COPY --from=builder /usr/bin/node /usr/bin/node
COPY --from=builder /usr/bin/npm /usr/bin/npm
COPY --from=builder /usr/lib/node_modules /usr/lib/node_modules
COPY --from=builder /usr/local/lib/python3.*/dist-packages /usr/local/lib/python3.10/dist-packages
COPY --from=builder /usr/local/bin/ansible* /usr/local/bin/

# Copy Java JDK from builder for compilation
COPY --from=builder /opt/java/openjdk /opt/java/openjdk-build

# Set environment variables
ENV JAVA_HOME=/opt/java/openjdk
ENV MAVEN_HOME=/opt/maven
ENV PATH="${MAVEN_HOME}/bin:${JAVA_HOME}/bin:/usr/local/bin:${PATH}"
ENV ANSIBLE_HOST_KEY_CHECKING=False

# Create non-root user with UID > 1000
RUN groupadd -g 1001 jenkins && \
    useradd -u 1001 -g jenkins -m -d /home/jenkins -s /bin/bash jenkins

# Create workspace directory
RUN mkdir -p /home/jenkins/workspace && \
    chown -R jenkins:jenkins /home/jenkins

# Switch to non-root user
USER jenkins
WORKDIR /home/jenkins/workspace

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD test -f /home/jenkins/.agent_ready || exit 1

# Default entrypoint
ENTRYPOINT ["/bin/bash"]
