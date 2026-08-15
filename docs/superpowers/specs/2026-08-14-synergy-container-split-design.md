# Synergy Host / Raw-Data Container Split — Design

**Date:** 2026-08-14
**Status:** Draft, awaiting user review
**Repo:** Synergy (plus a one-line change in `memory/`, its own repo)
**Builds on:** [`2026-04-27-synergy-workspace-design.md`](./2026-04-27-synergy-workspace-design.md)
**Retires:** `clean_room/`
**Implementation order:** second of three (esper-lint → this → cog re-baseline)

## Problem

The intended split — raw, untrusted data handled in a sandbox; everything else on the macOS host —
is designed but no longer implemented. Three environments have drifted apart, and the boundary
between them is enforced by configuration that silently does nothing in two of them.

### Environments today

| | Host (macOS) | Personal supercontainer (this one) | `clean_room/` |
|---|---|---|---|
| Path to repo | `~/Synergy` | `/workspaces/Synergy` | `/workspace` |
| Definition lives | — | host, **outside `/workspaces`** | `clean_room/Containerfile` |
| Launch | `cd ~/Synergy && claude` | VS Code / devcontainer | `./start.sh` (macOS + Apple Container only) |
| Network | egress denied by tool rules | **open** | Anthropic-only |
| `DEVCONTAINER` | unset | **`true`** | `true` |

### What is actually broken

**Path-scoped permission rules are inert outside the host.** `.claude/settings.json` scopes
everything to `~/Synergy/**`, which in the container resolves to `/home/node/Synergy` — a path
that does not exist. `.claude/settings.local.json` uses `/Users/subelsky/**` absolute paths, inert
for the same reason. Every `Read`/`Edit` allow and deny — including the `esper/raw/**` and
`esper/_staging/**` denies that are the entire point — applies on the host and nowhere else.

Tool-level rules with no path attached (`WebFetch`, `WebSearch`, `Bash(curl:*)`, `Bash(wget:*)`)
*do* still apply in the container. The failure is specific to path-scoped rules, not total.

**The `/integrate` security gate is effectively always open.** The gate is
`[ "$DEVCONTAINER" = true ]`. That variable is set in *every* devcontainer on this machine,
including general-purpose development ones. Verified in this session: `DEVCONTAINER=true`,
`SUPER_CONTAINER_PROFILE=personal`. So the check that is supposed to confine untrusted-content
processing to a sandbox passes in a container that has the whole `memory/` tree mounted
read-write and open network egress.

**The lethal trifecta is live in the personal supercontainer.** Untrusted content
(`esper/raw/evernote/*.html` — scraped web pages), private data (`memory/`), and egress. Egress is
narrower than it looks — `WebFetch`/`WebSearch`/`curl`/`wget` are denied — but `Bash(git:*)` is
explicitly allowed, and a `git clone` from github.com succeeded during this session's research.

**`clean_room/` is unreachable from where the work happens.** It requires macOS and the Apple
Container CLI, so it cannot be launched from inside a devcontainer. Its `sources.conf` is
entirely commented out, so it has no source mounts configured and cannot currently ingest
anything.

**Dangling symlinks.** `bin/esper-lint` → `/Users/subelsky/super_containers/personal/tools/…` (resolved 2026-08-15 by moving the tool into the repo) and
the four PARA symlinks (`Projects`, `Areas`, `Resources`, `Archive`) → `/Users/subelsky/Documents/…`
all resolve on the host and dangle in the container.

**Stale cursor.** `memory/cog-meta/reflect-cursor.md` scopes to
`-Users-subelsky-Documents-Synergy`, a path from before the `~/Synergy` migration. `/reflect` has
been reading a cursor for a directory that no longer exists.

**Documentation asserts guarantees that do not hold.** `docs/synergy-user-guide.md` says
`/integrate` runs with "no network access, no shell commands." Neither is true in the environment
where the gate currently passes.

## Goals

- Raw-data work happens in one purpose-built container, launchable from either host or container.
- Everything else happens on the macOS host: reading memory, querying Esper, linting, planning.
- One set of permission rules that is correct in both environments.
- The `/integrate` gate names the sandbox specifically instead of "any devcontainer."
- The container definition is version-controlled next to the data it protects.

## Non-goals

- Changing the personal/work supercontainer definitions. They live on the host outside
  `/workspaces` and are out of reach from a container session; the only change proposed for them
  is that `/integrate` will no longer run there, which requires no edit on their side.
- Reorganizing `esper/` or `memory/` contents.
- Building a launcher CLI. `devcontainer up` / VS Code "Reopen in Container" is the interface.
- Re-litigating the `~/Synergy` layout from the 2026-04-27 spec.

## Architecture

```
HOST (macOS)                          RAW CONTAINER (.devcontainer/)
────────────────────────────          ──────────────────────────────
cwd ~/Synergy                         cwd /workspace
claude (normal permissions)           claude (skip-permissions, bounded)

read/write  memory/                   NO memory/ mount
read        esper/pages/ index log     read/write  esper/ only
run         esper-lint, /esper         read-only   /sources/*
MCP: things, apple-events             NO MCP
PARA via additionalDirectories        NO host mounts beyond the above
no web egress                         egress: Anthropic + npm only
NO esper/raw, NO esper/_staging       SYNERGY_RAW=1

  /personal /trayverify /esper          /integrate
  /reflect /housekeeping /foresight
```

The two sides share nothing but `esper/`, and only the container writes to it. Coordination is
implicit: `/integrate` writes source pages, the host reads them.

## Design

### 1. `.devcontainer/` in the Synergy repo

New, replacing `clean_room/`:

```
.devcontainer/
  devcontainer.json     # mounts, env, capabilities, lifecycle hooks
  Dockerfile            # ported from clean_room/Containerfile
  init-firewall.sh      # ported from clean_room/entrypoint.sh
  claude-config/        # isolated CLAUDE_CONFIG_DIR seed (settings.json only)
  CLAUDE.md             # minimal, ingestion-scoped; mounted over the repo's
  README.md
```

Carried over from `clean_room/`, which got these right:

- Isolated Claude config dir — never the host's `~/.claude`. No host credentials, skills, hooks,
  agents, or transcripts reachable from inside.
- Isolated npm cache.
- Network allowlist via `iptables`/`ipset` (`--cap-add=NET_ADMIN --cap-add=NET_RAW`), applied by
  `init-firewall.sh` as `postStartCommand`, with a fail-closed DNS smoke test.
- Source directories mounted read-only.

Changed from `clean_room/`:

- **Docker/devcontainer spec instead of Apple Container.** Launchable from VS Code, the
  `devcontainer` CLI, or an existing container session. No macOS requirement.
- **`memory/` is not mounted at all.** `clean_room` mounted the whole Synergy root read-only,
  which included `memory/`. Removing private data from the sandbox removes one leg of the
  trifecta outright rather than relying on a read-only flag. The container needs `CLAUDE.md` and
  `.claude/commands/` to function; those get mounted individually, read-only.

  This has a consequence: `CLAUDE.md`'s memory rule 1 ("read `memory/hot-memory.md` and
  `memory/cog-meta/patterns.md` at conversation start") cannot be satisfied in the raw container,
  and every session there would open with two failed reads. The container therefore gets its own
  minimal `CLAUDE.md`, mounted over the repo's, scoping the assistant to ingestion: no memory, no
  domain routing, `/integrate` only. This mirrors the approach `airgap/TODO.md` sketches for its
  own container and is the correct pattern for any sandbox that deliberately lacks memory.
- **Source mounts move from `sources.conf` into `devcontainer.json`**, using
  `${localEnv:HOME}` so the file is portable and version-controllable. `sources.conf` is
  currently all comments, so nothing is lost. Populating the real source paths is a migration
  step, not a code change.
- **`SYNERGY_RAW=1`** in `containerEnv`, alongside `DEVCONTAINER=true`.

### 2. `/integrate` gate

`.claude/commands/integrate.md` changes its preflight from `echo $DEVCONTAINER` to:

```bash
echo "${SYNERGY_RAW:-}"
```

Blocked unless the value is `1`. The block message names the fix: "run this from the Synergy
raw-data container (`.devcontainer/`), not from a general-purpose devcontainer."

`SYNERGY_RAW` is set only by `.devcontainer/devcontainer.json`. It is deliberately *not* set by
the personal or work supercontainers, so no change is needed on their side — the gate simply
stops passing there.

### 3. Portable permission rules

The failure mode is `~`-prefixed and `/Users/`-absolute paths in `Read`/`Edit`/`additionalDirectories`
rules. The fix is to express project-scoped rules in a form that resolves the same in both
environments.

**Step one is empirical, before anything else in this part is written.** Claude Code permission
paths follow gitignore-style semantics, but I could not confirm from local documentation whether a
leading `/` means "project root" or "filesystem root." The existing `Read(//private/tmp/**)` entry
in `settings.local.json` implies `//` is the absolute form and `/` is project-relative, but that is
inference, not verification. The implementation plan opens by testing both forms in both
environments and recording the result.

Two candidate forms, in preference order:

1. `Read(/esper/raw/**)` — project-root-relative. Tighter. Use if verification confirms it.
2. `Read(esper/raw/**)` — bare pattern, matches anywhere in the tree. Definitely portable.
   Over-matching a *deny* is harmless, and the allow rules cover `memory/` and `esper/pages/`
   where slight over-match costs nothing. This is the fallback and the design does not depend on
   option 1 being available.

### 4. Settings split

| File | Contents | Where it applies |
|---|---|---|
| `.claude/settings.json` | portable allow/deny for `memory/`, `esper/pages/`, `esper/index.md`, `esper/log.md`; denies for `esper/raw/**`, `esper/_staging/**`, `esper/sources/**`, `esper/pages/sources/**` | both |
| `.claude/settings.local.json` | PARA `additionalDirectories`, `~/`-absolute denies (`.ssh`, `.aws`, `.gnupg`, Keychains), MCP enablement, host-only Bash allows | host; inert but harmless elsewhere |
| `.devcontainer/claude-config/settings.json` | container-only: `esper/` writable, no MCP, no `memory/` | raw container |

The host-only file keeps its `/Users/subelsky/**` absolute paths — those rules are *meant* to be
host-specific, and their inertness elsewhere is now intentional rather than accidental. The
distinction gets a comment at the top of each file so the next reader does not have to rediscover
it.

`Bash(bin/esper-lint fix *)` comes out as part of the esper-lint change (spec 1).

### 5. `bin/` portability

**Superseded 2026-08-15.** This section originally specified a path-probing shell wrapper,
because `esper-lint` lived in a separate `tools/` repo outside Synergy. The tool has since been
moved to `tools/esper-lint/` *inside* this repo, so the problem the wrapper solved no longer
exists. `bin/esper-lint` is now a plain relative symlink:

```
bin/esper-lint -> ../tools/esper-lint/bin/esper-lint
```

A relative symlink resolves identically on the host and in any container, needs no probing, and
has no fallback path that can silently go stale.

This requires an exception to the existing `.gitignore` rule (`bin/*` with
`!bin/.gitkeep`) — add `!bin/esper-lint`. `Bash(~/Synergy/bin/*:*)` in `settings.json` is a
host-form path and moves to the portable form alongside the other rules.

The four PARA symlinks stay as-is. They are host conveniences, they dangle harmlessly in the
container, and the container has no business reading `~/Documents` anyway.

### 6. `memory/cog-meta/reflect-cursor.md`

Replace the `-Users-subelsky-Documents-Synergy` scope entry with the current host path, and add
the container project dir. This is a one-line data fix in the `memory/` repo, committed
separately.

Confirm the actual directory names under `~/.claude/projects/` on the host before writing —
the encoding is derived from the working directory path and should not be guessed.

### 7. Retiring `clean_room/`

Last step, only after the new container is verified end-to-end.

`clean_room/claude-home/` holds `.credentials.json`, `history.jsonl`, and session transcripts;
`.gitconfig-host` holds git identity. All are gitignored, so `git rm` leaves them on disk. The
migration archives the directory (`mv clean_room ~/Archive/clean_room-retired-2026-08-14`) rather
than deleting it, and the user removes it once satisfied.

Tracked files removed: `Containerfile`, `entrypoint.sh`, `start.sh`, `sources.conf`, `README.md`,
`.gitignore`.

### 8. Documentation

- `docs/synergy-user-guide.md` — correct the Security section to describe what the new container
  actually enforces (allowlisted egress, not "no network access"; shell commands *are* available).
  Fix the stale `~/Documents/Synergy` paths. Update the "Feeding Esper" section to name the
  raw-data container.
- `CLAUDE.md` — replace `clean_room` references with `.devcontainer`. (Part of the cog re-baseline
  in spec 3; noted here so the two specs do not conflict.)
- `.devcontainer/README.md` — new, absorbing the threat-model content from `clean_room/README.md`,
  which is the best writeup of this system's security posture and should not be lost with the
  directory.
- `airgap/TODO.md` — unchanged. The airgap container is a separate, still-unbuilt idea; this spec
  neither implements nor cancels it.

## Migration

Ordered, each step independently verifiable.

1. **Verify permission path semantics** (design step 3). Record which form works. Everything else
   depends on this.
2. **Rewrite `.claude/settings.json`** in the portable form. Verify on the host that PARA access,
   `memory/` writes, and the `esper/raw` deny all still behave. Verify in the container that the
   `esper/raw` deny now fires — it currently does not.
3. **Add `bin/esper-lint` wrapper**, update `.gitignore`, verify from both sides.
4. **Fix `reflect-cursor.md`** in the `memory/` repo.
5. **Build `.devcontainer/`.** Verify: no `memory/` mount, `esper/` writable, `SYNERGY_RAW=1`,
   isolated config dir, firewall blocks a non-allowlisted host, DNS smoke test passes.
6. **Switch the `/integrate` gate** to `SYNERGY_RAW`. Verify it blocks in the personal
   supercontainer and passes in the new one.
7. **End-to-end `/integrate` run** in the new container against one real source.
8. **Update docs.**
9. **Archive `clean_room/`.**

Rollback at any point before step 9: `git checkout` the settings files. `clean_room/` is untouched
until the end, so the old path stays available throughout.

## Risks

- **Permission-path verification could invalidate both candidate forms.** Unlikely — bare
  gitignore-style patterns are the documented baseline — but if neither works, the fallback is two
  divergent settings files and a documented "which one am I in" note. This is why verification is
  step 1.
- **The supercontainer definition is out of reach.** After this change, `/integrate` will refuse
  to run there, which is the intent. But the personal supercontainer retains `memory/` read-write
  and open egress for *other* work. Narrowing that requires host-side edits outside this spec's
  scope; it should be a follow-up.
- **`esper/raw/` remains mounted in the personal supercontainer.** The deny rules will now apply
  there once paths are portable, which closes the read path. That is a permission-layer defense,
  not a mount-layer one — weaker than the container boundary, and worth revisiting when the
  supercontainer definition is next edited.
- **Firewall port from Apple Container to Docker.** `iptables`/`ipset` behave differently under
  Docker Desktop / OrbStack than under Apple Container's VM. Budget real time for step 5; the
  smoke test must fail closed.
- **First run needs a fresh Claude login** inside the new container, same as `clean_room` did.

## Success criteria

- `/integrate` refuses to run in the personal supercontainer and runs in `.devcontainer/`.
- A `Read` of `esper/raw/**` is denied in *both* environments.
- `bin/esper-lint check` runs from host and container with no permission prompt.
- The raw container has no `memory/` mount (`ls /workspace/memory` fails).
- The raw container cannot reach a non-allowlisted host; DNS smoke test passes at startup.
- `/reflect` reads a cursor that points at a directory that exists.
- `clean_room/` is archived and nothing references it.
