#!/bin/zsh
#
# Entrypoint for the Esper ingestion container.
# Runs AS the claude user. Uses sudo only for iptables.
#

# --- Network firewall via sudo ---
NETWORK_STATUS="UNKNOWN"
if sudo iptables -P OUTPUT DROP 2>/dev/null; then
    sudo iptables -P INPUT DROP 2>/dev/null
    sudo iptables -P FORWARD DROP 2>/dev/null
    sudo iptables -A INPUT -i lo -j ACCEPT 2>/dev/null
    sudo iptables -A OUTPUT -o lo -j ACCEPT 2>/dev/null
    sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null

    # Allow DNS (needed to resolve api.anthropic.com)
    sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT 2>/dev/null

    # Resolve Anthropic API and allow HTTPS to it
    ANTHROPIC_IPS=$(getent hosts api.anthropic.com 2>/dev/null | awk '{print $1}' | sort -u)
    if [[ -n "$ANTHROPIC_IPS" ]]; then
        for ip in ${(f)ANTHROPIC_IPS}; do
            sudo iptables -A OUTPUT -d "$ip" -p tcp --dport 443 -j ACCEPT 2>/dev/null
        done
        NETWORK_STATUS="RESTRICTED (api.anthropic.com only)"
    else
        # Fallback: allow all HTTPS
        sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null
        NETWORK_STATUS="RESTRICTED (HTTPS-only fallback)"
    fi
else
    NETWORK_STATUS="OPEN (iptables unavailable)"
fi
echo "[esper] Network: $NETWORK_STATUS"

# --- Restore .claude.json if missing ---
if [[ ! -f "$HOME/.claude.json" ]]; then
    BACKUP=$(ls -t "$HOME/.claude/backups/.claude.json.backup."* 2>/dev/null | head -1)
    if [[ -n "$BACKUP" ]]; then
        cp "$BACKUP" "$HOME/.claude.json"
        echo "[esper] Restored .claude.json from backup"
    fi
fi

# --- Launch ---
if [[ "${1:-}" == "shell" ]]; then
    echo "[esper] Shell session — type 'exit' to quit"
    exec /bin/zsh
elif [[ $# -gt 0 ]]; then
    exec claude "$@"
else
    exec claude
fi
