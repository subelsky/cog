# Clean Room — Esper Ingestion Sandbox

A locked-down Apple Container VM for running Synergy's `/integrate` skill, which processes untrusted sources (email, web articles, Kindle highlights, Claude transcripts) into the Esper knowledge base.

## Security Model

- **Network**: Locked to Anthropic endpoints only (dnsmasq + iptables allowlist)
- **Filesystem**: Synergy repo mounted read-only; only `esper/` is writable
- **Sources**: All source directories mounted read-only
- **Claude config**: Fully isolated — container uses `clean_room/claude-home/`, NOT the host's `~/.claude/`. No access to host credentials, skills, hooks, agents, or session transcripts. First run requires a one-time login inside the container.
- **npm cache**: Isolated at `clean_room/npm-cache/`, NOT `~/.npm/`
- **Environment**: `DEVCONTAINER=true` set (required by `/integrate` security gate)

Because the container has zero writable access to host state that Claude Code ever reads on the host, a prompt injection inside the sandbox cannot persist hooks, skills, or settings that would later execute on the host. Combined with the network allowlist, this makes running `--dangerously-skip-permissions` inside the clean room a bounded risk:

- Worst case: corrupt `esper/` (mitigated by backups + git history)
- Worst case: burn Anthropic API tokens
- The container's own `claude-home/` can be blown away and rebuilt freely

## Usage

```bash
cd clean_room/

# Launch Claude Code (default — for running /integrate)
./start.sh

# Launch a shell session (for debugging/inspection)
./start.sh shell

# Force rebuild the container image
./start.sh --rebuild
```

## Setup

1. Install [Apple Container CLI](https://github.com/apple/swift-container)
2. Edit `sources.conf` — uncomment and customize paths to your source directories
3. Run `./start.sh` — first run builds the image (takes a few minutes)
4. Inside the container, run `/integrate` to process sources

## Source Mounts

Edit `sources.conf` to map your host directories to container paths. Format:

```
/path/on/host:/path/in/container
```

All sources are mounted read-only. See the file for examples.

## Mount Layout

| Host Path | Container Path | Access |
|-----------|---------------|--------|
| `../` (Synergy root) | `/workspaces/Synergy` | Read-only |
| `../esper/` | `/workspaces/Synergy/esper` | **Read-write** |
| `./claude-home/` (isolated) | `/home/claude/.claude` | Read-write |
| `./npm-cache/` (isolated) | `/home/claude/.npm` | Read-write |
| `~/.gitconfig` | `/home/claude/.gitconfig` | Read-only (baked at build) |
| Sources from `sources.conf` | `/sources/*` | Read-only |

Project-local commands (`.claude/commands/`, including `/integrate`) live inside the Synergy repo and are reachable read-only via the `/workspaces/Synergy` mount — no separate mount needed.

## Transcripts

Claude Code session transcripts from work inside this container persist at `clean_room/claude-home/projects/` — **not** in the host's `~/.claude/projects/`. This is a deliberate isolation boundary: nothing Claude writes inside the sandbox is visible to host-side `/reflect` or other skills unless you explicitly copy it out.

If you want `/reflect` on the host to mine clean-room transcripts, copy them manually after inspecting them. If you want `/integrate` to process them as a source, add `clean_room/claude-home/projects/` to `sources.conf`.
