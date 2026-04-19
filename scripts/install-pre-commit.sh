#!/usr/bin/env bash
# =============================================================================
# Gitleaks Pre-commit Hook Installation Script
# Installs Gitleaks as a Git pre-commit hook on developer workstations
# =============================================================================

set -euo pipefail

GITLEAKS_VERSION="8.18.1"
HOOKS_DIR=".git/hooks"
HOOK_FILE="${HOOKS_DIR}/pre-commit"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    error "Not in a git repository root. Run this script from the project root."
    exit 1
fi

# Detect OS and architecture
detect_platform() {
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"

    case "${os}" in
        linux*)  os="linux" ;;
        darwin*) os="darwin" ;;
        mingw*|msys*|cygwin*) os="windows" ;;
        *) error "Unsupported OS: ${os}"; exit 1 ;;
    esac

    case "${arch}" in
        x86_64|amd64) arch="x64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) error "Unsupported architecture: ${arch}"; exit 1 ;;
    esac

    echo "${os}_${arch}"
}

# Install Gitleaks if not present
install_gitleaks() {
    if command -v gitleaks &>/dev/null; then
        local current_version
        current_version=$(gitleaks version 2>/dev/null || echo "unknown")
        info "Gitleaks already installed (version: ${current_version})"
        return 0
    fi

    info "Installing Gitleaks v${GITLEAKS_VERSION}..."
    local platform
    platform=$(detect_platform)

    local download_url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_${platform}.tar.gz"

    if command -v curl &>/dev/null; then
        curl -fsSL "${download_url}" -o /tmp/gitleaks.tar.gz
    elif command -v wget &>/dev/null; then
        wget -q "${download_url}" -O /tmp/gitleaks.tar.gz
    else
        error "Neither curl nor wget found. Install one and retry."
        exit 1
    fi

    tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin/ gitleaks 2>/dev/null || \
        sudo tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin/ gitleaks
    chmod +x /usr/local/bin/gitleaks
    rm -f /tmp/gitleaks.tar.gz

    info "Gitleaks v${GITLEAKS_VERSION} installed successfully."
}

# Create pre-commit hook
create_hook() {
    mkdir -p "${HOOKS_DIR}"

    # Check for existing hook
    if [ -f "${HOOK_FILE}" ]; then
        if grep -q "gitleaks" "${HOOK_FILE}" 2>/dev/null; then
            info "Gitleaks pre-commit hook already installed."
            return 0
        fi
        warn "Existing pre-commit hook found. Backing up to ${HOOK_FILE}.bak"
        cp "${HOOK_FILE}" "${HOOK_FILE}.bak"
    fi

    cat > "${HOOK_FILE}" << 'HOOK_CONTENT'
#!/usr/bin/env bash
# =============================================================================
# Gitleaks Pre-commit Hook
# Scans staged diffs for secrets before allowing commit
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if gitleaks is installed
if ! command -v gitleaks &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} gitleaks is not installed. Run ./scripts/install-pre-commit.sh"
    exit 1
fi

# Configuration file path
GITLEAKS_CONFIG=".gitleaks.toml"
GITLEAKS_ARGS="detect --staged --verbose"

if [ -f "${GITLEAKS_CONFIG}" ]; then
    GITLEAKS_ARGS="${GITLEAKS_ARGS} --config=${GITLEAKS_CONFIG}"
fi

echo -e "${YELLOW}[PRE-COMMIT]${NC} Running Gitleaks secret scan on staged changes..."

# Run gitleaks on staged changes
if gitleaks ${GITLEAKS_ARGS} 2>&1; then
    echo -e "${GREEN}[PRE-COMMIT]${NC} No secrets detected. Commit proceeding."
    exit 0
else
    echo ""
    echo -e "${RED}========================================================${NC}"
    echo -e "${RED}  SECRETS DETECTED IN STAGED CHANGES!${NC}"
    echo -e "${RED}  Commit blocked. Review the findings above.${NC}"
    echo -e "${RED}========================================================${NC}"
    echo ""
    echo -e "${YELLOW}To fix:${NC}"
    echo "  1. Remove the secret from your code"
    echo "  2. Use environment variables or a secrets manager"
    echo "  3. Add to .gitleaks.toml allowlist if false positive"
    echo ""
    echo -e "${YELLOW}To bypass (NOT recommended):${NC}"
    echo "  git commit --no-verify"
    echo ""
    exit 1
fi
HOOK_CONTENT

    chmod +x "${HOOK_FILE}"
    info "Pre-commit hook installed at ${HOOK_FILE}"
}

# Main execution
main() {
    echo "================================================================"
    echo "  Gitleaks Pre-commit Hook Installer"
    echo "  Version: ${GITLEAKS_VERSION}"
    echo "================================================================"
    echo ""

    install_gitleaks
    create_hook

    echo ""
    info "Setup complete. Gitleaks will scan staged changes before each commit."
    info "Configuration file: .gitleaks.toml"
    echo ""
}

main "$@"
