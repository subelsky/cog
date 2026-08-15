#!/usr/bin/env bash
#
# init-firewall.sh — default-deny network egress for the Synergy raw-data container.
#
# Ported from clean_room/entrypoint.sh (zsh, Apple Container) to bash/Docker.
# Runs as root, invoked by devcontainer.json's postStartCommand:
#
#     sudo /usr/local/bin/init-firewall.sh
#
# Two independent layers of enforcement:
#
#   1. DNS  (dnsmasq)          — only allowlisted domains resolve at all.
#                                Everything else gets REFUSED/SERVFAIL.
#   2. IP   (ipset + iptables) — only IPs that dnsmasq actually resolved for an
#                                allowlisted domain are routable on :443.
#
# dnsmasq's `ipset` directive adds every resolved address to the set as it is
# resolved, so CDN IP rotation is handled naturally — no stale boot-time pins.
# Even if code hardcodes a raw IP, iptables drops it unless it is in the set.
#
# FAIL CLOSED: any error in here locks the network down completely (policy DROP
# on INPUT/OUTPUT/FORWARD, loopback only) and exits non-zero. A firewall that
# silently no-ops is worse than no firewall, because the rest of this container's
# design assumes egress is bounded.
#
# Re-running is safe and idempotent.

set -euo pipefail

# --- Allowlist ------------------------------------------------------------
# Keep this list as short as the container can function with. Every entry is a
# path out of the sandbox for content that arrives via untrusted source files.
ALLOWED_DOMAINS=(
    api.anthropic.com       # Claude API — the only endpoint ingestion needs
    platform.claude.com     # OAuth: login + token exchange
    console.anthropic.com   # OAuth: legacy/console login path
    claude.ai               # OAuth: subscription login path
    statsig.anthropic.com   # Feature flags — Claude Code degrades without it
    registry.npmjs.org      # npm: `claude update` / npx, user-owned install prefix
)

LOG_PREFIX="[synergy-raw]"
IPSET_NAME="allowed-ips"
DNSMASQ_CONF="/run/synergy-dnsmasq.conf"
DNSMASQ_PID="/run/synergy-dnsmasq.pid"

log() { echo "${LOG_PREFIX} $*"; }

# Deny everything except loopback. Used when we cannot build a correct allowlist.
lockdown() {
    iptables -P INPUT   DROP 2>/dev/null || true
    iptables -P FORWARD DROP 2>/dev/null || true
    iptables -P OUTPUT  DROP 2>/dev/null || true
    iptables -F              2>/dev/null || true
    iptables -A INPUT  -i lo -j ACCEPT 2>/dev/null || true
    iptables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true
}

firewall_fail() {
    trap - ERR                      # never re-enter
    echo "${LOG_PREFIX} FIREWALL ERROR: $1" >&2
    lockdown
    echo "${LOG_PREFIX} network LOCKED DOWN (all egress denied)." >&2
    echo "${LOG_PREFIX} fix the cause, then re-run: sudo /usr/local/bin/init-firewall.sh" >&2
    exit 1
}

trap 'firewall_fail "unexpected failure at line ${LINENO}"' ERR

# --- 0. Preconditions -----------------------------------------------------
[ "$(id -u)" -eq 0 ] || firewall_fail "must run as root (use: sudo $0)"

for tool in iptables ipset dnsmasq getent; do
    command -v "$tool" >/dev/null 2>&1 || firewall_fail "required tool not found: $tool"
done

# NET_ADMIN is granted by runArgs in devcontainer.json. Without it every rule
# below silently fails, which is exactly the case this check exists to catch.
iptables -L -n >/dev/null 2>&1 \
    || firewall_fail "iptables unusable — is --cap-add=NET_ADMIN set in runArgs?"

# --- 1. Capture upstream DNS before touching resolv.conf -------------------
# Docker gives the container either its embedded resolver (127.0.0.11) or the
# host's nameserver. Either works as dnsmasq's upstream.
#
# Step 4 rewrites resolv.conf to 127.0.0.1, so a re-run would otherwise capture
# dnsmasq as its own upstream and resolve nothing. Remember the real upstream in
# /run and fall back to it whenever resolv.conf already points at us.
UPSTREAM_STATE="/run/synergy-upstream-dns"
UPSTREAM_DNS="$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null || true)"

if [ -n "$UPSTREAM_DNS" ] && [ "$UPSTREAM_DNS" != "127.0.0.1" ]; then
    printf '%s\n' "$UPSTREAM_DNS" > "$UPSTREAM_STATE"
elif [ -s "$UPSTREAM_STATE" ]; then
    UPSTREAM_DNS="$(head -1 "$UPSTREAM_STATE")"
    log "resolv.conf already points at dnsmasq; reusing remembered upstream"
else
    UPSTREAM_DNS="8.8.8.8"
    log "no usable upstream found in resolv.conf; falling back to ${UPSTREAM_DNS}"
fi

case "$UPSTREAM_DNS" in
    ""|127.0.0.1) firewall_fail "could not determine a usable upstream DNS server" ;;
esac
log "upstream DNS: ${UPSTREAM_DNS}"

# --- 2. ipset for allowlisted addresses ------------------------------------
if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
    ipset create "$IPSET_NAME" hash:ip \
        || firewall_fail "ipset create failed — ip_set kernel modules missing in this VM?"
fi

# --- 3. dnsmasq: resolve allowlisted domains, refuse everything else -------
#   no-resolv + no default server = REFUSED for unlisted domains
#   server=/domain/upstream       = forward only these domains
#   ipset=/domain/set             = add every resolved IP to the set
{
    echo "# Generated by init-firewall.sh — do not edit; edit ALLOWED_DOMAINS instead."
    echo "no-resolv"
    echo "no-poll"
    echo "no-hosts"
    echo "listen-address=127.0.0.1"
    echo "bind-interfaces"
    echo "port=53"
    echo ""
    for domain in "${ALLOWED_DOMAINS[@]}"; do
        echo "server=/${domain}/${UPSTREAM_DNS}"
    done
    echo ""
    # ipset=/a/b/c/setname — domains joined by '/'
    printf 'ipset=/'
    printf '%s/' "${ALLOWED_DOMAINS[@]}"
    printf '%s\n' "$IPSET_NAME"
} > "$DNSMASQ_CONF" || firewall_fail "could not write ${DNSMASQ_CONF}"
chmod 0644 "$DNSMASQ_CONF"

# Restart cleanly so re-runs pick up allowlist edits.
if [ -f "$DNSMASQ_PID" ]; then
    kill "$(cat "$DNSMASQ_PID")" 2>/dev/null || true
fi
if command -v pkill >/dev/null 2>&1; then
    pkill -x dnsmasq 2>/dev/null || true
fi
sleep 1

dnsmasq --conf-file="$DNSMASQ_CONF" --pid-file="$DNSMASQ_PID" \
    || firewall_fail "dnsmasq failed to start (port 53 already in use?)"
log "dnsmasq running (${#ALLOWED_DOMAINS[@]} domains allowlisted)"

# --- 4. Point the system resolver at dnsmasq -------------------------------
# /etc/resolv.conf is a bind mount from the Docker daemon; truncating and
# rewriting it in place works, replacing the inode does not.
printf 'nameserver 127.0.0.1\noptions timeout:2 attempts:2\n' > /etc/resolv.conf \
    || firewall_fail "could not rewrite /etc/resolv.conf"

if ! grep -q '^nameserver 127.0.0.1$' /etc/resolv.conf; then
    firewall_fail "/etc/resolv.conf did not take the dnsmasq nameserver"
fi

# --- 5. Pre-seed the ipset -------------------------------------------------
# Resolving now populates the set for the common case. Anything that rotates
# later is added by dnsmasq at lookup time.
for domain in "${ALLOWED_DOMAINS[@]}"; do
    if getent hosts "$domain" >/dev/null 2>&1; then
        log "  ok   ${domain}"
    else
        log "  warn ${domain} (unresolved now; will retry at connect time)"
    fi
done

# --- 6. iptables -----------------------------------------------------------
# filter table only. Docker's embedded DNS relies on nat-table rules in this
# network namespace, so nat is deliberately left alone.
iptables -F
iptables -X 2>/dev/null || true

# Loopback (dnsmasq lives here) — must precede the default DROP.
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Return traffic for connections we opened.
iptables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# DNS: only dnsmasq -> the captured upstream. User processes cannot reach any
# other resolver, so they cannot resolve around the allowlist.
iptables -A OUTPUT -d "$UPSTREAM_DNS" -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -d "$UPSTREAM_DNS" -p tcp --dport 53 -j ACCEPT

# HTTPS: only to addresses dnsmasq resolved for an allowlisted domain.
iptables -A OUTPUT -p tcp --dport 443 -m set --match-set "$IPSET_NAME" dst -j ACCEPT \
    || firewall_fail "iptables 'set' match unavailable — xt_set module missing?"

# Everything else: REJECT so callers fail fast instead of hanging.
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# Default policies last.
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  DROP

# --- 7. Verify the rules actually landed -----------------------------------
iptables -S | grep -q -- '-P OUTPUT DROP' \
    || firewall_fail "OUTPUT policy is not DROP — rules did not apply"
iptables -S OUTPUT | grep -q -- "--match-set ${IPSET_NAME} dst" \
    || firewall_fail "allowlist match rule missing from OUTPUT chain"

# --- 8. DNS smoke test (fail closed) ---------------------------------------
# Uses getent (libc resolver) — no HTTP client required, so it also works in an
# image with curl removed.
if getent hosts example.com >/dev/null 2>&1; then
    firewall_fail "example.com resolved — the DNS allowlist is NOT being enforced"
fi
if ! getent hosts api.anthropic.com >/dev/null 2>&1; then
    firewall_fail "api.anthropic.com did not resolve — the allowlist is broken"
fi
log "  ok   DNS allowlist enforced (example.com blocked, api.anthropic.com resolves)"

printf '%s network: DEFAULT DENY. allowlist: ' "$LOG_PREFIX"
printf '%s ' "${ALLOWED_DOMAINS[@]}"
printf '\n'

trap - ERR
exit 0
