# Synergy Raw-Data Container

A locked-down devcontainer for running Synergy's `/integrate` skill, which turns
untrusted sources (scraped articles, exported email, highlights, transcripts)
into the Esper knowledge base.

It replaced `clean_room/`, which required macOS and the Apple Container CLI and
therefore could not be launched from the place the work actually happens. This
one is a standard devcontainer: VS Code "Reopen in Container", the `devcontainer`
CLI, or plain `docker`.

`clean_room/` has since been retired and deleted; its files are in git history if
you ever need them back.

## Threat model

Three things together are dangerous: untrusted content, private data, and network
egress. Ingestion inherently supplies the first, so this container removes the
other two.

| Leg | How it is removed |
|---|---|
| Untrusted content | Unavoidable — it is the input. Treated as data, never instructions (see `CLAUDE.md`). |
| Private data | `memory/` is **not mounted**. Neither is the repo root, `~/.claude`, `~/Documents`, or `~/.ssh`. There is nothing private in here to exfiltrate. |
| Egress | Default-deny iptables + DNS allowlist. Only the Anthropic API and the npm registry are reachable. |

`clean_room/` mounted the whole Synergy root read-only, which included `memory/`
— private data present but flagged read-only. Read-only does not help against
exfiltration: reading is the attack. This container does not mount it at all.
That difference is why it was retired rather than kept as a fallback.

Because the container has no writable access to any host state that Claude Code
reads on the host, a prompt injection inside the sandbox cannot persist a hook,
skill, or setting that later executes on the host. Combined with the egress
allowlist, that bounds the worst case to:

- corrupt `esper/` — mitigated by git history in the `esper/` repo and backups
- burn Anthropic API tokens
- corrupt the container's own config volume — delete and rebuild it freely

The container also drops the base image's blanket `NOPASSWD:ALL` sudo. The only
sudo-able command is `/usr/local/bin/init-firewall.sh`, which is root-owned in a
root-owned directory and can only re-establish the firewall. Without that, an
agent running with `--dangerously-skip-permissions` could simply `sudo iptables
-F` its way out of the network allowlist.

## Mount layout

Everything the container can see from the host, in full:

| Host path | Container path | Access |
|---|---|---|
| `<repo>/esper` | `/workspaces/Synergy/esper` | **read-write** — the only writable host path |
| *(nothing — tmpfs)* | `/workspaces/Synergy/esper/.git` | read-only empty dir, shadows the host's `.git` |
| `<repo>/.claude/commands` | `/workspaces/Synergy/.claude/commands` | read-only |
| `<repo>/.devcontainer/CLAUDE.md` | `/workspaces/Synergy/CLAUDE.md` | read-only |
| volume `synergy-raw-claude-config` | `/home/vscode/.claude-raw` | read-write (not a host dir) |
| volume `synergy-raw-npm-cache` | `/home/vscode/.npm` | read-write (not a host dir) |
| optional, commented in `devcontainer.json` | `/sources/*` | read-only |

**Not mounted, deliberately:** the repo root, `memory/`, `~/.claude`,
`~/.claude.json`, `~/.gitconfig`, `~/.ssh`, `~/Documents`, the PARA symlinks,
`.claude/settings.json`, `.claude/settings.local.json`, `.mcp.json`,
`.devcontainer/` itself.

`/workspaces/Synergy` itself is the image's own directory in the container layer.
It is writable but invisible to the host and discarded on rebuild. The name
matches the `/workspaces/<repo>` convention used by the personal and work
supercontainers so a shell lands in a predictable place — it does **not** mean
the repo root is mounted there. Only the three rows above are present under it.

`workspaceMount` in `devcontainer.json` is overridden to point at `esper/`
precisely so the default (mount the whole workspace folder) never happens. If a
future devcontainer tool objects to `workspaceFolder` being the parent of the
mount target, the fix is to move the esper bind into `mounts` and give
`workspaceMount` an empty string or a named volume — **never** to delete the
override and let the default repo-root mount come back.

### Source mounts

The old `clean_room/sources.conf` was entirely commented out, so nothing was lost
in the move; the equivalent commented entries now live in `devcontainer.json`
under `mounts`, expressed with `${localEnv:HOME}` so the file stays portable.

Uncomment the ones you use and fix the paths — a bind mount whose host source
does not exist prevents the container from starting. All source mounts are
read-only.

Note that `esper/sources/*.yml` currently points `readwise`, `goodreads`,
`instapaper`, and `research-papers` at `esper/raw/*`, which is already inside the
esper mount. Only `claude-code.yml` and `email.yml` expect `/sources/`.

## Network allowlist

`init-firewall.sh` runs as `postStartCommand` on every start. Two layers:

1. **DNS** — `dnsmasq` with `no-resolv` forwards only allowlisted domains;
   everything else is refused, so nothing else can even be resolved.
2. **IP** — `dnsmasq`'s `ipset` directive adds each resolved address to
   `allowed-ips`; iptables permits outbound `:443` only to that set, and REJECTs
   everything else. CDN IP rotation is handled automatically; a hardcoded raw IP
   is still blocked.

Allowlisted domains:

| Domain | Why |
|---|---|
| `api.anthropic.com` | the Claude API |
| `platform.claude.com`, `console.anthropic.com`, `claude.ai` | OAuth login/token exchange |
| `statsig.anthropic.com` | Claude Code feature flags |
| `registry.npmjs.org` | `claude update` / `npx` |

Everything else — GitHub, the wider web, the host's other services — is denied.

**Fail closed.** Any error (missing `NET_ADMIN`, absent ipset kernel modules,
dnsmasq refusing to start, a smoke test that shows the allowlist is not being
enforced) locks the network down to loopback only and exits non-zero. The DNS
smoke test is carried over from `clean_room/entrypoint.sh`: `example.com` must
*not* resolve and `api.anthropic.com` must, checked with `getent` so no HTTP
client is required.

Re-running is safe: `sudo /usr/local/bin/init-firewall.sh`.

To change the allowlist, edit `ALLOWED_DOMAINS` at the top of `init-firewall.sh`
and rebuild. Treat every addition as widening the exfiltration channel for
untrusted content.

## Usage

```bash
# CLI (works from macOS or from another container that can reach the Docker socket)
devcontainer up --workspace-folder ~/Synergy
devcontainer exec --workspace-folder ~/Synergy zsh

# then, inside:
claude
> /integrate
```

Or VS Code: open `~/Synergy`, "Dev Containers: Reopen in Container", pick this
configuration.

First run needs a one-time Claude login inside the container — the config dir is
isolated, so host credentials are not visible here (same as `clean_room`). The
login URL opens in the host browser; the code exchange happens over the
allowlisted OAuth domains.

Rebuild after changing the Dockerfile or firewall:

```bash
devcontainer up --workspace-folder ~/Synergy --remove-existing-container --build-no-cache
```

To force a fresh login: `docker volume rm synergy-raw-claude-config`.

## Settings: which file applies where

Three permission files, three scopes. This is the distinction that made the old
setup silently ineffective, so it is worth stating plainly:

| File | Path form | Applies |
|---|---|---|
| `.claude/settings.json` | project-relative (`Read(/esper/raw/**)`) | everywhere — host and every container |
| `.claude/settings.local.json` | host-absolute (`/Users/...`, `~/...`) plus MCP enablement | the macOS host only; inert elsewhere by design |
| `.devcontainer/claude-config/settings.json` | project-relative | this container only |

Path semantics are gitignore-style: `/esper/raw/**` is project-root-relative,
`//etc/**` is filesystem-absolute, and a bare `esper/raw/**` matches anywhere.
`~/`-prefixed and `/Users/`-absolute rules resolve on the host and nowhere else —
which is why they belong in `settings.local.json`.

The container's file is seeded into the image and copied into the named volume
the first time it is created. **Editing it later does not affect an existing
volume** — remove `synergy-raw-claude-config` (or edit
`/home/vscode/.claude-raw/settings.json` in place) to pick up changes.

Note that `.claude/settings.json` is *not* mounted here; the container's own file
is the whole ruleset. It allows writes under `esper/`, denies web tools, shells
out to nothing useful, and denies reads of its own credentials directory. These
rules are defense in depth. The real boundary is the container: nothing important
is inside it.

## Verify after building (macOS host)

Run it with `devcontainer exec`, **not** `docker exec`. `devcontainer exec` runs
as `remoteUser` (`vscode`), which is the account the agent actually uses;
`docker exec` defaults to the image's `USER`, which is root here, and root can
write things `vscode` cannot. A verification run as root proves nothing.

```bash
devcontainer exec --workspace-folder ~/Synergy bash -lc '
  id -un                                          # must print vscode, not root
  echo "SYNERGY_RAW=$SYNERGY_RAW"                 # must print 1
  touch /workspaces/Synergy/stray 2>&1            # must fail: Permission denied
  touch /workspaces/Synergy/.claude/settings.local.json 2>&1  # must fail: Permission denied
  pwd                                             # must print /workspaces/Synergy
  ls /workspaces/Synergy/memory                   # must fail: No such file or directory
  ls -ld /workspaces/Synergy/esper                # exists, writable
  touch /workspaces/Synergy/esper/.write-probe && rm /workspaces/Synergy/esper/.write-probe && echo "esper writable"
  touch /workspaces/Synergy/.claude/commands/probe 2>&1   # must fail: Read-only file system
  touch /workspaces/Synergy/esper/.git/probe 2>&1         # must fail: Read-only file system
  ls -a /workspaces/Synergy/esper/.git                    # must be empty (tmpfs shadow)
  echo "$CLAUDE_CONFIG_DIR"                       # /home/vscode/.claude-raw
  getent hosts api.anthropic.com  && echo "anthropic resolves"
  getent hosts example.com        && echo "LEAK: example.com resolved" || echo "example.com blocked"
  getent hosts github.com         && echo "LEAK: github.com resolved"  || echo "github blocked"
  sudo iptables -F 2>&1           # must fail: sudo not permitted
  head -3 /workspaces/Synergy/CLAUDE.md           # the container CLAUDE.md, not the repo one
'
```

Then, inside a `claude` session: `/integrate` should pass its preflight here and
refuse in the personal supercontainer.

## Known trade-offs

- **Startup window.** `postStartCommand` runs after the container starts, so
  there is a brief interval before the firewall applies. Nothing runs
  automatically in that window, but do not start ingesting until the
  `[synergy-raw] network: DEFAULT DENY` line has appeared.
- **VS Code server download.** If the VS Code server is not already cached, the
  extension may try to download it inside the container, which the firewall
  blocks; it normally falls back to copying from the host. The `devcontainer exec`
  + terminal flow avoids the question entirely. If you want VS Code attachment to
  work unconditionally, add `update.code.visualstudio.com` and `*.vscode-cdn.net`
  to `ALLOWED_DOMAINS` — and accept the wider allowlist.
- **`curl`/`wget` are present** (they ship with the devcontainers base image and
  removing them breaks parts of it). The old `clean_room` purged `curl`. They are
  neutered by the egress allowlist and denied in the container's settings, but
  the binaries exist.
- **INPUT is default-DROP** with loopback and established connections only. The
  host network is not blanket-allowed, unlike the stock Claude Code devcontainer
  firewall. If some tooling needs to reach into the container over TCP, that is
  the rule to revisit.
- **The firewall does not survive a plain `docker start`.** It runs from
  `postStartCommand`, which only the devcontainer CLI executes; `docker start
  synergy-raw` yields a container with `-P OUTPUT ACCEPT` and full egress. Always
  start with `devcontainer up --workspace-folder .`. `/integrate`'s security gate
  probes DNS and refuses to run when the firewall is down, so the dangerous
  operation is gated even if the container is started the wrong way — but the
  container itself is still unrestricted until the firewall is applied.
- **The project root is root-owned and read-only to `vscode`**; only `esper/` is
  writable. Without that, the agent could write `.claude/settings.local.json` or
  `.claude/skills/` and grant itself the tools the settings deny list withholds.
- **No git identity or credentials** are mounted, and `esper/.git` is shadowed by
  a read-only tmpfs, so git does not function in here at all. Committing `esper/`
  is the host's job. Without the shadow, a writable `esper/.git` would be a
  container -> host code execution path: an injected `.git/hooks/post-checkout`
  or a `core.pager` entry in `.git/config` runs on the **host**, with full user
  privileges, the next time you use git in `~/Synergy/esper`.
- **`CLAUDE.md` is a single-file bind mount.** Editors that replace the file
  rather than rewrite it in place will leave the container looking at the old
  inode; restart the container after editing `.devcontainer/CLAUDE.md`.
