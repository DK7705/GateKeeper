# =============================================================================
# Hardened Application Dockerfile — Spring Boot Microservices
# Base image pinned by SHA256 digest, non-root, no package managers in final
# =============================================================================

# ---- Stage 1: Build ----
FROM eclipse-temurin:17-jdk-jammy@sha256:e1b5c37ab5cc0e5f6e1dcf64e6f3d30be7ef00de0cb9faa7e894c0bae58e4f72 AS builder

WORKDIR /build

# Copy Maven wrapper and POM files first (layer caching)
COPY app/pom.xml ./pom.xml
COPY app/api-gateway/pom.xml ./api-gateway/pom.xml
COPY app/user-service/pom.xml ./user-service/pom.xml
COPY app/order-service/pom.xml ./order-service/pom.xml

# Download dependencies (cached layer)
RUN --mount=type=cache,target=/root/.m2 \
    mvn dependency:go-offline -B -q 2>/dev/null || true

# Copy source code
COPY app/ ./

# Build all modules
RUN --mount=type=cache,target=/root/.m2 \
    mvn clean package -DskipTests -B -q

# ---- Stage 2: Runtime (hardened) ----
FROM eclipse-temurin:17-jre-jammy@sha256:3b5c37ab5cc0e5f6e1dcf64e6f3d30be7ef00de0cb9faa7e894c0bae58e4f72

LABEL maintainer="DevSecOps Team <devsecops@example.com>"
LABEL version="1.0.0"
LABEL description="Hardened Spring Boot application runtime"

# Install minimal runtime deps and then remove package manager
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates=20230311ubuntu0.22.04.1 \
        tini=0.19.0-1 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get purge -y --auto-remove apt \
    && rm -rf /var/cache/apt /var/lib/dpkg /var/lib/apt

# Create non-root user with UID > 1000
RUN groupadd -g 1001 appuser && \
    useradd -u 1001 -g appuser -m -d /app -s /usr/sbin/nologin appuser

# Create application directories
RUN mkdir -p /app/logs /app/config /app/tmp && \
    chown -R appuser:appuser /app

# Copy built artifacts from builder
COPY --from=builder --chown=appuser:appuser /build/api-gateway/target/*.jar /app/api-gateway.jar
COPY --from=builder --chown=appuser:appuser /build/user-service/target/*.jar /app/user-service.jar
COPY --from=builder --chown=appuser:appuser /build/order-service/target/*.jar /app/order-service.jar

# Set security-related JVM options
ENV JAVA_OPTS="-XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=75.0 \
    -Djava.security.egd=file:/dev/./urandom \
    -Djava.io.tmpdir=/app/tmp \
    -Dserver.port=8080"

# Expose non-privileged port only
EXPOSE 8080

# Switch to non-root user
USER appuser
WORKDIR /app

# Use tini as init system
ENTRYPOINT ["tini", "--"]

# Default to API Gateway; override with Docker run command for other services
CMD ["java", "-jar", "/app/api-gateway.jar"]

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD test -f /app/tmp/healthy || exit 1
