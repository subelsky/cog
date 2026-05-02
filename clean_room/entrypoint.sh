#!/bin/zsh
#
# Entrypoint for the Esper ingestion container.
# Runs AS the claude user. Uses sudo only for iptables.
#

# --- Hermetic network firewall ---
#
# Two layers of enforcement:
#   1. DNS (dnsmasq)  — only allowed domains resolve; everything else → SERVFAIL
#   2. IP  (ipset + iptables) — only IPs resolved by dnsmasq are routable
#
# dnsmasq's `ipset` directive auto-adds resolved IPs to the ipset on every
# lookup, so CDN IP rotation is handled naturally — no stale boot-time pins.
# Even if code hardcodes a raw IP, iptables blocks it unless it's in the set.
#
# Adapted from init-firewall.sh (ipset pattern), narrowed to Anthropic-only.

ALLOWED_DOMAINS=(
    api.anthropic.com       # Claude API
    platform.claude.com     # OAuth (token exchange + login)
    statsig.anthropic.com   # Feature flags (Claude Code needs this)
    mcp2.readwise.io        # Readwise MCP server endpoint
    readwise.io             # Readwise OAuth / token endpoints
)

firewall_fail() { echo "[esper] FIREWALL ERROR: $1" >&2; exit 1; }

# --- 1. Capture upstream DNS before we touch anything ---
UPSTREAM_DNS=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null)
UPSTREAM_DNS="${UPSTREAM_DNS:-8.8.8.8}"
echo "[esper] Upstream DNS: $UPSTREAM_DNS"

# --- 2. Create ipset for allowed IPs ---
sudo ipset create allowed-ips hash:ip 2>/dev/null \
    || firewall_fail "ipset create failed — kernel module missing?"

# --- 3. Configure dnsmasq ---
#   - no-resolv + no default server = SERVFAIL for unlisted domains
#   - server=/domain/upstream  = forward only these domains
#   - ipset=/domain/set        = auto-add resolved IPs to the ipset
DNSMASQ_CONF="/tmp/dnsmasq-allowlist.conf"
{
    echo "# Auto-generated — do not edit"
    echo "no-resolv"
    echo "no-poll"
    echo "no-hosts"
    echo "listen-address=127.0.0.1"
    echo "bind-interfaces"
    echo "port=53"
    echo ""
    # Per-domain upstream forwarding
    for domain in "${ALLOWED_DOMAINS[@]}"; do
        echo "server=/${domain}/${UPSTREAM_DNS}"
    done
    echo ""
    # Auto-populate ipset on every DNS resolution
    echo "ipset=/${(j:/:)ALLOWED_DOMAINS}/allowed-ips"
} > "$DNSMASQ_CONF"

sudo dnsmasq --conf-file="$DNSMASQ_CONF" --pid-file=/tmp/dnsmasq.pid \
    || firewall_fail "dnsmasq failed to start"
echo "[esper] dnsmasq running (${#ALLOWED_DOMAINS[@]} domains allowed)"

# --- 4. Point system resolver at dnsmasq ---
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null

# --- 5. Pre-seed the ipset by resolving all allowed domains now ---
for domain in "${ALLOWED_DOMAINS[@]}"; do
    if getent hosts "$domain" > /dev/null 2>&1; then
        echo "[esper]   ✓ $domain"
    else
        echo "[esper]   ✗ $domain (will retry at connect time)"
    fi
done

# --- 6. iptables — adapted from init-firewall.sh ---
# Flush any existing rules
sudo iptables -F
sudo iptables -X

# Loopback (must come before default DROP)
sudo iptables -A INPUT  -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

# Established/related connections
sudo iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# DNS: only dnsmasq → upstream (not the user process → external DNS)
sudo iptables -A OUTPUT -d "$UPSTREAM_DNS" -p udp --dport 53 -j ACCEPT
sudo iptables -A OUTPUT -d "$UPSTREAM_DNS" -p tcp --dport 53 -j ACCEPT

# HTTPS: only to IPs in the ipset (populated by dnsmasq on each lookup)
sudo iptables -A OUTPUT -p tcp --dport 443 -m set --match-set allowed-ips dst -j ACCEPT

# REJECT everything else — fast failure, not silent DROP
sudo iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# Default policies
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT DROP

# --- 7. Lightweight DNS smoke test ---
# Confirms dnsmasq is enforcing the allowlist:
#   - an unlisted domain must NOT resolve (SERVFAIL)
#   - api.anthropic.com must resolve
# Uses getent (libc) instead of curl — no HTTP client needed.
if getent hosts example.com > /dev/null 2>&1; then
    firewall_fail "example.com resolved — DNS allowlist is broken"
fi
if ! getent hosts api.anthropic.com > /dev/null 2>&1; then
    firewall_fail "api.anthropic.com did not resolve — DNS allowlist is broken"
fi
echo "[esper]   ✓ DNS allowlist enforced (example.com blocked, api.anthropic.com OK)"

echo "[esper] Network: HERMETIC (DNS + IP allowlist: ${(j:, :)ALLOWED_DOMAINS})"

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
    exec claude "$@" --dangerously-skip-permissions
else
    exec claude --dangerously-skip-permissions
fi
