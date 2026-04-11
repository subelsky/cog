#!/usr/bin/env bash
#
# start.sh - Run Claude Code in the Esper ingestion sandbox
#
# Launches an Apple Container VM with:
#   - Synergy repo mounted read-only at /workspace
#   - esper/ overlaid read-write (the only writable project path)
#   - Source directories mounted read-only at /sources/
#   - Network killed via iptables inside the container
#   - DEVCONTAINER=true (required by /integrate security gate)
#
# Usage:
#   ./start.sh                  # Launch Claude Code
#   ./start.sh shell            # Launch a terminal session
#   ./start.sh --rebuild        # Force rebuild the container image
#
# Configure source mounts in sources.conf (one per line).
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNERGY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="clean-room"
CONTAINER_NAME="clean-room-session-$$"

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_prerequisites() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_error "This script requires macOS"
        exit 1
    fi

    if ! command -v container &>/dev/null; then
        log_error "'container' CLI not found"
        echo ""
        echo "Install Apple Container from: https://github.com/apple/swift-container"
        exit 1
    fi

    if [[ ! -f "$SCRIPT_DIR/Containerfile" ]]; then
        log_error "Containerfile not found in $SCRIPT_DIR"
        exit 1
    fi

    if [[ ! -d "$SYNERGY_DIR/esper" ]]; then
        log_error "esper/ directory not found in $SYNERGY_DIR"
        echo "Run the Esper setup first (scaffold directory structure)"
        exit 1
    fi
}

build_image_if_needed() {
    local force_build=false

    if [[ "${1:-}" == "--rebuild" ]]; then
        force_build=true
    fi

    if $force_build || ! container images 2>/dev/null | grep -q "${IMAGE_NAME}"; then
        log_info "Building container image '$IMAGE_NAME'..."

        # Copy gitconfig for the build (Apple Container can't bind-mount single files)
        if [[ -f "$HOME/.gitconfig" ]]; then
            cp "$HOME/.gitconfig" "$SCRIPT_DIR/.gitconfig-host"
        else
            touch "$SCRIPT_DIR/.gitconfig-host"
        fi

        container build \
            -t "$IMAGE_NAME" \
            --build-arg HOST_UID="$HOST_UID" \
            --build-arg HOST_GID="$HOST_GID" \
            "$SCRIPT_DIR"

        log_info "Container image built successfully"
    fi
}

setup_directories() {
    mkdir -p "$HOME/.claude"
    mkdir -p "$HOME/.npm"
}

build_args() {
    # Mount args (global array — bash 3.2 doesn't support namerefs)
    MOUNT_ARGS=()
    ENV_ARGS=()

    # Synergy repo root — READ-ONLY
    # This gives Claude access to CLAUDE.md, .claude/commands/, memory/
    MOUNT_ARGS+=(--mount "type=bind,src=$SYNERGY_DIR,dst=/workspace,readonly")

    # Esper directory — READ-WRITE (overlaid on top of read-only workspace)
    # This is the ONLY writable project path. /integrate writes here.
    MOUNT_ARGS+=(--mount "type=bind,src=$SYNERGY_DIR/esper,dst=/workspace/esper")

    # Claude configuration — read-write (Claude Code needs this to function)
    # Session transcripts persist here on the host automatically
    MOUNT_ARGS+=(--mount "type=bind,src=$HOME/.claude,dst=/home/claude/.claude")

    # NPM cache
    MOUNT_ARGS+=(--mount "type=bind,src=$HOME/.npm,dst=/home/claude/.npm")

    # Git configuration — read-only (Apple Container only mounts directories, not files)
    if [[ -d "$HOME/.config/git" ]]; then
        MOUNT_ARGS+=(--mount "type=bind,src=$HOME/.config/git,dst=/home/claude/.config/git,readonly")
    fi

    # Source directories from sources.conf — all read-only
    local sources_conf="$SCRIPT_DIR/sources.conf"
    if [[ -f "$sources_conf" ]]; then
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

            local host_path="${line%%:*}"
            local container_path="${line##*:}"

            # Trim whitespace
            host_path="$(echo "$host_path" | xargs)"
            container_path="$(echo "$container_path" | xargs)"

            if [[ -d "$host_path" ]]; then
                MOUNT_ARGS+=(--mount "type=bind,src=$host_path,dst=$container_path,readonly")
                log_info "Source mount: $host_path → $container_path (read-only)"
            else
                log_warn "Source path not found, skipping: $host_path"
            fi
        done < "$sources_conf"
    else
        log_warn "No sources.conf found — no source directories will be mounted"
    fi

    # Environment args
    ENV_ARGS+=(--env "TERM=${TERM:-xterm-256color}")
    ENV_ARGS+=(--env "LANG=en_US.UTF-8")
}

run_container() {
    build_args

    log_info "Starting Esper clean room..."
    echo "---"

    local tty_args=()
    if [[ -t 0 ]] && [[ -t 1 ]]; then
        tty_args+=(--tty --interactive)
    fi

    exec container run \
        --rm \
        --name "$CONTAINER_NAME" \
        "${tty_args[@]}" \
        "${MOUNT_ARGS[@]}" \
        "${ENV_ARGS[@]}" \
        "$IMAGE_NAME" \
        "$@"
}

cleanup() {
    container rm -f "$CONTAINER_NAME" 2>/dev/null || true
}

main() {
    trap cleanup EXIT

    # Handle --rebuild flag
    local rebuild_flag=""
    local run_args=()
    for arg in "$@"; do
        if [[ "$arg" == "--rebuild" ]]; then
            rebuild_flag="--rebuild"
        else
            run_args+=("$arg")
        fi
    done

    check_prerequisites
    build_image_if_needed "$rebuild_flag"
    setup_directories
    run_container "${run_args[@]}"
}

main "$@"
