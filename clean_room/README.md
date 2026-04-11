# Clean Room — Esper Ingestion Sandbox

A locked-down Apple Container VM for running Synergy's `/integrate` skill, which processes untrusted sources (email, web articles, Kindle highlights, Claude transcripts) into the Esper knowledge base.

## Security Model

- **Network**: All outbound traffic blocked via iptables inside the container
- **Filesystem**: Synergy repo mounted read-only; only `esper/` is writable
- **Sources**: All source directories mounted read-only
- **Environment**: `DEVCONTAINER=true` set (required by `/integrate` security gate)

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
| `../` (Synergy root) | `/workspace` | Read-only |
| `../esper/` | `/workspace/esper` | **Read-write** |
| `~/.claude/` | `/home/claude/.claude` | Read-write |
| `~/.npm/` | `/home/claude/.npm` | Read-write |
| `~/.gitconfig` | `/home/claude/.gitconfig` | Read-only |
| Sources from `sources.conf` | `/sources/*` | Read-only |

## Transcripts

Claude Code session transcripts from work done inside this container persist at `~/.claude/projects/` on your host (because `~/.claude` is bind-mounted). These are automatically available to:
- **Cog's `/reflect`** — mines them for patterns and observations
- **Esper's `/integrate`** — can process them as a source if configured in `sources.conf`
