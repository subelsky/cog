# airgap — disposable web-research container

Sibling to `clean_room/`. Opposite tradeoff: `clean_room` is locked-down execution sandbox for
running untrusted code with broad filesystem-but-no-network access; `airgap` is a
broad-network-but-no-host container for doing web research without giving the host Claude
session any web egress.

## Why this exists

Cog's host settings (`.claude/settings.local.json`) deny `WebFetch` and `WebSearch`. That
collapses the prompt-injection → exfiltration chain that would otherwise be wide open given
how much of the user's filesystem and GitHub presence the agent can touch. All of Cog's
external data flows through narrow MCP interfaces (Things, Readwise, gcal) — never raw HTML
into context.

The cost: when the user genuinely needs Claude to read a URL, search the web, or summarize a
page, the host session can't do it. Click-approving `WebFetch` on the host would re-open the
exfil path. Instead: spin up a disposable container whose only job is "fetch, read, summarize"
and whose output crosses an air gap by being hand-copied back into the host session.

## Threat model

- **Host Cog session**: highest trust. Has memory, Things MCP, gh, git, readwise MCP, the
  user's entire filesystem via `Read`. MUST NOT have raw web egress.
- **clean_room**: mid trust. Isolated `claude-home`, firewalled network (anthropic + github +
  npm only), broad code-execution privileges. For running sketchy code against a repo.
- **airgap**: low trust for *input*, zero trust for *output*. Broad outbound internet, no host
  mounts, no MCP access, no memory, no persistent state. Output leaves the container only as
  text the user hand-pastes into the host session (which treats it as untrusted content).

The air gap is the feature. A compromise of airgap can't touch memory files, can't push to
GitHub, can't read `~/.ssh`, can't even see that the host filesystem exists.

## Design sketch

Base on `clean_room/`'s structure (`Containerfile`, `entrypoint.sh`, `start.sh`,
gitignored state dirs), but invert the network + mount posture:

**Network**
- Outbound: unrestricted (or: allowlist of anthropic + whatever domain the user names when
  launching, via a `start.sh` arg). Default open, since research is the whole point.
- Inbound: none.
- Keep the `getent`-based DNS smoke test from `clean_room` so the container fails fast if DNS
  is broken.

**Filesystem**
- NO bind-mounts from host. Not `~/.claude`, not `~/Documents/Synergy`, not the Cog repo,
  nothing. A compromised airgap session must not be able to name a host path.
- Dedicated `airgap/claude-home/` and `airgap/npm-cache/` gitignored dirs, same pattern as
  `clean_room`. Wiped between sessions (see "disposability" below).
- Working directory inside the container is `/work`, empty on start.

**Claude Code config inside the container**
- Run with `--dangerously-skip-permissions` since the blast radius is bounded by the container
  boundary.
- Allow `WebFetch`, `WebSearch`, `Read`, `Write` inside `/work`, basic bash tools.
- No MCP servers configured. Explicitly no Things, no Readwise, no gcal.
- No memory files. No auto-loaded CLAUDE.md from Cog — the container has its own minimal
  `CLAUDE.md` that says "you are a research assistant, summarize what you fetch, do not invent
  tool calls that don't exist here."

**Disposability**
- `start.sh` should default to wiping `airgap/claude-home/` and `airgap/npm-cache/` on each
  launch so no session state persists. An optional `--keep` flag for multi-turn research
  sessions.
- No git repo inside the container. Nothing to push.

**Crossing the air gap**
- Output path: user reads the container's summary on screen and hand-copies text back into
  the host Cog session. The host session treats pasted content as untrusted input (same as
  any user message).
- No file transfer out. No shared volume. No clipboard bridge. The friction is intentional —
  it forces a human review step on every piece of data leaving the research session.

## Open questions

- Does `airgap` need the Anthropic SDK at all, or just the Claude Code CLI? (Same as
  `clean_room` — just the CLI.)
- Should the default network posture be "fully open" or "allowlist provided at launch"? Start
  fully open; tighten later if we find a pattern.
- Firewall: reuse `clean_room`'s iptables/nftables setup but invert the default? Or skip the
  firewall entirely since the threat model is about data *leaving* via host access, not
  network exfil (which is the whole point of this container)?
- How to launch: `airgap/start.sh "summarize https://example.com/article"` as a one-shot, or
  interactive shell? Start with interactive, add one-shot later.

## TODO

- [ ] Copy `clean_room/Containerfile` → `airgap/Containerfile`, strip firewall, strip MCP
      setup, strip any bind-mount hooks
- [ ] Copy `clean_room/entrypoint.sh` → `airgap/entrypoint.sh`, remove host-mount logic
- [ ] Write `airgap/start.sh` with disposability default (wipe state, `--keep` to preserve)
- [ ] Write minimal `airgap/CLAUDE.md` scoping the in-container assistant to research tasks
- [ ] Write `airgap/.gitignore` for `claude-home/`, `npm-cache/`, `work/`
- [ ] Write `airgap/README.md` explaining the three-container posture
      (host / clean_room / airgap) and when to reach for which
- [ ] Document the host-side workflow: "when Cog needs to fetch X, open airgap, do it, paste
      the summary back"
- [ ] Decide whether to add a `/research` skill on the host that reminds the user to launch
      airgap rather than trying to fetch directly
