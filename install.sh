#!/usr/bin/env bash
#
# Ralph Engine Installer
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Determine installation paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${RALPH_INSTALL_DIR:-$HOME/.local}"
BIN_DIR="$INSTALL_DIR/bin"
LIB_DIR="$INSTALL_DIR/lib/ralph"
COMPLETIONS_DIR="${BASH_COMPLETION_USER_DIR:-$HOME/.local/share/bash-completion/completions}"

usage() {
    cat <<EOF
Ralph Engine Installer

USAGE:
    ./install.sh [OPTIONS]

OPTIONS:
    --prefix DIR    Installation prefix (default: ~/.local)
    --uninstall     Remove ralph from the system
    --check         Check if ralph is properly installed
    -h, --help      Show this help

EXAMPLES:
    ./install.sh                    # Install to ~/.local
    ./install.sh --prefix /usr      # Install to /usr (requires sudo)
    ./install.sh --uninstall        # Remove installation
    ./install.sh --check            # Verify installation

EOF
}

check_dependencies() {
    local missing=()

    if ! command -v claude &>/dev/null; then
        missing+=("claude (Claude Code CLI)")
    fi

    if ! command -v jq &>/dev/null; then
        missing+=("jq (JSON processor)")
    fi

    if ! command -v git &>/dev/null; then
        missing+=("git")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing dependencies:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        echo ""
        warn "Ralph will work once these are installed."
    else
        success "All dependencies found"
    fi
}

install_ralph() {
    info "Installing Ralph Engine..."
    echo "  Source:      $SCRIPT_DIR"
    echo "  Destination: $INSTALL_DIR"
    echo ""

    # Create directories
    mkdir -p "$BIN_DIR" "$LIB_DIR" "$COMPLETIONS_DIR"

    # Copy files
    info "Installing library..."
    cp "$SCRIPT_DIR/lib/ralph-core.sh" "$LIB_DIR/"
    chmod 644 "$LIB_DIR/ralph-core.sh"

    info "Installing binary..."
    cp "$SCRIPT_DIR/bin/ralph" "$BIN_DIR/"
    chmod 755 "$BIN_DIR/ralph"

    # Update RALPH_ROOT in installed binary
    sed -i "s|RALPH_ROOT=\"\$(cd \"\$(dirname \"\${BASH_SOURCE\[0\]}\")/..\"|RALPH_ROOT=\"$INSTALL_DIR/lib/ralph/../..\"|" "$BIN_DIR/ralph" 2>/dev/null || true

    # Actually, let's use a simpler approach - set RALPH_ROOT explicitly
    sed -i "s|^RALPH_ROOT=.*|RALPH_ROOT=\"$INSTALL_DIR\"|" "$BIN_DIR/ralph"

    # Ensure lib is in the right place
    mkdir -p "$INSTALL_DIR/lib"
    rm -rf "$INSTALL_DIR/lib/ralph"
    cp -r "$SCRIPT_DIR/lib" "$INSTALL_DIR/lib/ralph"

    # Install completions
    if [[ -f "$SCRIPT_DIR/completions/ralph.bash" ]]; then
        info "Installing bash completions..."
        cp "$SCRIPT_DIR/completions/ralph.bash" "$COMPLETIONS_DIR/ralph"
    fi

    echo ""
    success "Ralph Engine installed successfully!"
    echo ""

    # Check if bin is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "$BIN_DIR is not in your PATH"
        echo ""
        echo "Add this to your shell profile (~/.bashrc or ~/.zshrc):"
        echo ""
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
    fi

    # Check dependencies
    echo ""
    check_dependencies
}

uninstall_ralph() {
    info "Uninstalling Ralph Engine..."

    if [[ -f "$BIN_DIR/ralph" ]]; then
        rm -f "$BIN_DIR/ralph"
        success "Removed $BIN_DIR/ralph"
    fi

    if [[ -d "$LIB_DIR" ]]; then
        rm -rf "$LIB_DIR"
        success "Removed $LIB_DIR"
    fi

    if [[ -f "$COMPLETIONS_DIR/ralph" ]]; then
        rm -f "$COMPLETIONS_DIR/ralph"
        success "Removed completions"
    fi

    success "Ralph Engine uninstalled"
}

check_installation() {
    info "Checking Ralph installation..."
    echo ""

    local ok=true

    if command -v ralph &>/dev/null; then
        success "ralph command found: $(command -v ralph)"
        echo "  Version: $(ralph --version)"
    else
        error "ralph command not found in PATH"
        ok=false
    fi

    if [[ -f "$LIB_DIR/ralph-core.sh" ]]; then
        success "Library found: $LIB_DIR/ralph-core.sh"
    else
        error "Library not found: $LIB_DIR/ralph-core.sh"
        ok=false
    fi

    echo ""
    check_dependencies

    echo ""
    if [[ "$ok" == true ]]; then
        success "Installation OK"
    else
        error "Installation has issues"
        exit 1
    fi
}

# Parse arguments
ACTION="install"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)
            INSTALL_DIR="$2"
            BIN_DIR="$INSTALL_DIR/bin"
            LIB_DIR="$INSTALL_DIR/lib/ralph"
            shift 2
            ;;
        --uninstall)
            ACTION="uninstall"
            shift
            ;;
        --check)
            ACTION="check"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

case "$ACTION" in
    install)
        install_ralph
        ;;
    uninstall)
        uninstall_ralph
        ;;
    check)
        check_installation
        ;;
esac
