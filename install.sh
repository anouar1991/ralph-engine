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
MAN_DIR="$INSTALL_DIR/share/man/man1"
BASH_COMPLETIONS_DIR="${BASH_COMPLETION_USER_DIR:-$HOME/.local/share/bash-completion/completions}"
ZSH_COMPLETIONS_DIR="$HOME/.local/share/zsh/site-functions"

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
    mkdir -p "$BIN_DIR" "$LIB_DIR" "$MAN_DIR" "$BASH_COMPLETIONS_DIR" "$ZSH_COMPLETIONS_DIR"

    # Copy library files
    info "Installing libraries..."
    cp "$SCRIPT_DIR/lib/ralph-core.sh" "$LIB_DIR/"
    cp "$SCRIPT_DIR/lib/ralph-watch.sh" "$LIB_DIR/"
    chmod 644 "$LIB_DIR/ralph-core.sh" "$LIB_DIR/ralph-watch.sh"

    info "Installing binary..."
    cp "$SCRIPT_DIR/bin/ralph" "$BIN_DIR/"
    chmod 755 "$BIN_DIR/ralph"

    # Update RALPH_ROOT in installed binary
    sed -i "s|RALPH_ROOT=\"\$(cd \"\$(dirname \"\${BASH_SOURCE\[0\]}\")/..\"|RALPH_ROOT=\"$INSTALL_DIR/lib/ralph/../..\"|" "$BIN_DIR/ralph" 2>/dev/null || true

    # Set RALPH_ROOT to the installation directory
    sed -i "s|^RALPH_ROOT=.*|RALPH_ROOT=\"$INSTALL_DIR\"|" "$BIN_DIR/ralph"

    # Copy library directly to lib/ (not lib/ralph/) to match source path
    mkdir -p "$INSTALL_DIR/lib"
    cp "$SCRIPT_DIR/lib/ralph-core.sh" "$INSTALL_DIR/lib/"
    cp "$SCRIPT_DIR/lib/ralph-watch.sh" "$INSTALL_DIR/lib/"

    # Install prompts
    info "Installing prompts..."
    rm -rf "$INSTALL_DIR/prompts"
    cp -r "$SCRIPT_DIR/prompts" "$INSTALL_DIR/prompts"
    chmod 644 "$INSTALL_DIR/prompts"/*.md

    # Install config (agent/skill catalogs for optimizer fallback)
    info "Installing config..."
    rm -rf "$INSTALL_DIR/config"
    cp -r "$SCRIPT_DIR/config" "$INSTALL_DIR/config"
    chmod 644 "$INSTALL_DIR/config"/*.md

    # Install man page
    if [[ -f "$SCRIPT_DIR/man/man1/ralph.1" ]]; then
        info "Installing man page..."
        cp "$SCRIPT_DIR/man/man1/ralph.1" "$MAN_DIR/"
        chmod 644 "$MAN_DIR/ralph.1"
    fi

    # Install bash completions
    if [[ -f "$SCRIPT_DIR/completions/ralph.bash" ]]; then
        info "Installing bash completions..."
        cp "$SCRIPT_DIR/completions/ralph.bash" "$BASH_COMPLETIONS_DIR/ralph"
    fi

    # Install zsh completions
    if [[ -f "$SCRIPT_DIR/completions/ralph.zsh" ]]; then
        info "Installing zsh completions..."
        cp "$SCRIPT_DIR/completions/ralph.zsh" "$ZSH_COMPLETIONS_DIR/_ralph"
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

    # Check if man page is accessible
    if ! man -w ralph &>/dev/null 2>&1; then
        warn "Man page may not be accessible"
        echo ""
        echo "To access the man page, add to your shell profile:"
        echo ""
        echo "  export MANPATH=\"\$HOME/.local/share/man:\$MANPATH\""
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

    if [[ -d "$INSTALL_DIR/prompts" ]]; then
        rm -rf "$INSTALL_DIR/prompts"
        success "Removed prompts"
    fi

    if [[ -d "$INSTALL_DIR/config" ]]; then
        rm -rf "$INSTALL_DIR/config"
        success "Removed config"
    fi

    if [[ -f "$MAN_DIR/ralph.1" ]]; then
        rm -f "$MAN_DIR/ralph.1"
        success "Removed man page"
    fi

    if [[ -f "$BASH_COMPLETIONS_DIR/ralph" ]]; then
        rm -f "$BASH_COMPLETIONS_DIR/ralph"
        success "Removed bash completions"
    fi

    if [[ -f "$ZSH_COMPLETIONS_DIR/_ralph" ]]; then
        rm -f "$ZSH_COMPLETIONS_DIR/_ralph"
        success "Removed zsh completions"
    fi

    # Clean up lib files if they exist in alternate location
    rm -f "$INSTALL_DIR/lib/ralph-core.sh" "$INSTALL_DIR/lib/ralph-watch.sh" 2>/dev/null || true

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
        success "Core library found: $LIB_DIR/ralph-core.sh"
    else
        error "Core library not found: $LIB_DIR/ralph-core.sh"
        ok=false
    fi

    if [[ -f "$LIB_DIR/ralph-watch.sh" ]]; then
        success "Watch library found: $LIB_DIR/ralph-watch.sh"
    else
        warn "Watch library not found: $LIB_DIR/ralph-watch.sh"
    fi

    if [[ -f "$MAN_DIR/ralph.1" ]]; then
        success "Man page found: $MAN_DIR/ralph.1"
    else
        warn "Man page not found: $MAN_DIR/ralph.1"
    fi

    # Check if man page is accessible
    if man -w ralph &>/dev/null 2>&1; then
        success "Man page accessible: man ralph"
    else
        warn "Man page not in MANPATH (try: export MANPATH=\"\$HOME/.local/share/man:\$MANPATH\")"
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
