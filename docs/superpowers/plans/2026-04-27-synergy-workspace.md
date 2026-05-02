# Synergy Workspace Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to work through this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the cog/ember/clean_room workspace from `~/Documents/4-Synergy/` to `~/Synergy/`, scope host Claude to PARA folders + cog/ember, and curate a `~/Synergy/bin/` allowlist for host CLIs.

**Architecture:** Single `mv` relocates the cog repo. Two exports added to `~/.zshrc` set `SYNERGY_HOME` and prepend `~/Synergy/bin` to PATH. `.claude/settings.json` is rewritten with scoped `additionalDirectories` and an ember deny rule. Clean room continues working unchanged because its `SCRIPT_DIR/..` resolution moves with it. Super_container cog/ember integration is deferred (requires container rebuild).

**Tech Stack:** macOS, zsh, git, Apple Container CLI, Claude Code.

**Spec reference:** `docs/superpowers/specs/2026-04-27-synergy-workspace-design.md`

---

## Operating notes

**Commits.** Per user's CLAUDE.md (`/Users/subelsky/CLAUDE.md`): make file changes only; user commits themselves. Do not run `git commit` in any task. Stage with `git add` only when explicitly noted, or leave staging to the user.

**Risky operations need confirmation.** Tasks 2, 3, and 6 perform destructive or shell-modifying operations on the user's home directory and shell profile. Before executing each, surface the exact commands and ask the user to confirm.

**Cwd.** Tasks 1 (pre-flight) runs from `~/Documents/4-Synergy/`. Task 2 moves the directory. Tasks 3+ run from `~/Synergy/`.

**Rollback.** At any point: `mv ~/Synergy ~/Documents/4-Synergy`. Remove the two `SYNERGY_HOME` / PATH export lines from `~/.zshrc` if you want to fully undo Task 3.

---

## File Map

**Created:**
- `~/Synergy/bin/.gitkeep` — placeholder so empty `bin/` is committable

**Modified (post-move paths shown):**
- `~/Synergy/.claude/settings.json` — full rewrite of `permissions` block
- `~/Synergy/.gitignore` — add `bin/*` and `!bin/.gitkeep`
- `~/.zshrc` — add `SYNERGY_HOME` and PATH exports
- Files surfaced by Task 4 grep audit (any reference to `4-Synergy` or `Documents/4-Synergy`)

**Moved:**
- `~/Documents/4-Synergy/` → `~/Synergy/` (single `mv`, preserves all subdirs and `.git`)

---

## Task 1: Pre-flight verification

**Files:** Read-only inspection.

- [ ] **Step 1.1: Confirm no live Claude or container sessions**

Run from any cwd:
```bash
container ls
ps aux | grep -i claude | grep -v grep
```

Expected: `container ls` shows no running containers (or only ones the user knows about and is OK shutting down). `ps` may show the current Claude session.

- [ ] **Step 1.2: Inspect outstanding work in 4-Synergy**

Run from `~/Documents/4-Synergy/`:
```bash
git status
git -C memory status
git -C esper status
```

Expected: list of modified/untracked files in each repo. Surface this to the user. **Ask the user to commit and push outstanding work themselves before proceeding.** Do not commit on their behalf.

- [ ] **Step 1.3: Optional escape hatch — snapshot tarball**

Ask user if they want a one-shot backup. If yes:
```bash
tar -czf ~/synergy-pre-migration-$(date +%Y%m%d).tar.gz -C ~/Documents 4-Synergy
ls -lh ~/synergy-pre-migration-*.tar.gz
```

Expected: tarball file ~tens of MB depending on memory/esper size. Confirm size is reasonable.

---

## Task 2: The move

**Files:** Moves `~/Documents/4-Synergy/` → `~/Synergy/`. Destructive but trivially reversible.

- [ ] **Step 2.1: Confirm target does not exist**

```bash
[ -e ~/Synergy ] && echo "EXISTS — abort" || echo "clear"
```

Expected: `clear`. If it prints `EXISTS`, stop and ask the user how to handle the existing path.

- [ ] **Step 2.2: Surface the move command and confirm with user**

Show the user:
```bash
mv ~/Documents/4-Synergy ~/Synergy
```

Wait for explicit confirmation before running it.

- [ ] **Step 2.3: Execute the move**

```bash
mv ~/Documents/4-Synergy ~/Synergy
```

Expected: no output. Returns 0.

- [ ] **Step 2.4: Verify the move**

```bash
ls -la ~/Synergy/ | head -20
[ -d ~/Documents/4-Synergy ] && echo "STILL THERE" || echo "moved"
git -C ~/Synergy status
```

Expected: `~/Synergy/` listing shows `CLAUDE.md`, `.claude/`, `.git/`, `memory/`, `esper/`, `clean_room/`, `docs/`, `README.md`, etc. `~/Documents/4-Synergy` no longer exists. `git status` works (proves `.git` came along intact).

---

## Task 3: Host shell environment

**Files:** Creates `~/Synergy/bin/.gitkeep`. Modifies `~/.zshrc` and `~/Synergy/.gitignore`.

- [ ] **Step 3.1: Create `~/Synergy/bin/` with `.gitkeep`**

```bash
mkdir -p ~/Synergy/bin
touch ~/Synergy/bin/.gitkeep
ls -la ~/Synergy/bin/
```

Expected: `bin/` exists; contains `.gitkeep`.

- [ ] **Step 3.2: Update `~/Synergy/.gitignore`**

Read current content:
```bash
cat ~/Synergy/.gitignore
```

Use Edit tool to append (or insert in a sensible location):
```
# Bin: tracked as a directory via .gitkeep; symlinks are personal
bin/*
!bin/.gitkeep
```

Verify:
```bash
grep -A2 '^bin' ~/Synergy/.gitignore
```

Expected: shows the two lines.

- [ ] **Step 3.3: Surface the `~/.zshrc` edit and confirm with user**

Show user the lines to be added at the end of `~/.zshrc`:
```sh
# Synergy workspace
export SYNERGY_HOME="$HOME/Synergy"
export PATH="$SYNERGY_HOME/bin:$PATH"
```

Confirm with user before editing.

- [ ] **Step 3.4: Add the exports to `~/.zshrc`**

Use Edit tool to append the three lines (comment + two exports) at the end of `~/.zshrc`. Verify:
```bash
tail -4 ~/.zshrc
```

Expected: shows the comment and the two export lines.

- [ ] **Step 3.5: Verify the exports load in a fresh shell**

```bash
zsh -i -c 'echo "SYNERGY_HOME=$SYNERGY_HOME" && echo "$PATH" | tr ":" "\n" | head -3'
```

Expected: `SYNERGY_HOME=/Users/subelsky/Synergy` and `/Users/subelsky/Synergy/bin` appears as the first PATH entry.

---

## Task 4: Path audit

**Files:** All modifications driven by grep results. Likely candidates: `CLAUDE.md`, `.claude/commands/*.md`, `.claude/settings*.json`, `clean_room/*.sh`, `clean_room/Containerfile`, `docs/**/*.md`.

- [ ] **Step 4.1: Audit for `4-Synergy` references**

```bash
cd ~/Synergy
grep -rn '4-Synergy' . --include='*.md' --include='*.json' --include='*.sh' --include='*.yml' --include='Containerfile' --exclude-dir=.git --exclude-dir=memory --exclude-dir=esper
```

Expected: zero or a small number of hits. Each hit is a file + line that mentions `4-Synergy`. Capture the full output.

- [ ] **Step 4.2: Audit for `Documents/4-Synergy` references**

```bash
cd ~/Synergy
grep -rn 'Documents/4-Synergy' . --include='*.md' --include='*.json' --include='*.sh' --include='*.yml' --include='Containerfile' --exclude-dir=.git --exclude-dir=memory --exclude-dir=esper
```

Expected: any hit with this longer pattern is also caught by Step 4.1, but the explicit form helps verify. Capture output.

- [ ] **Step 4.3: Audit for relevant absolute paths**

```bash
cd ~/Synergy
grep -rn '/Users/subelsky/Documents/4-Synergy' . --exclude-dir=.git --exclude-dir=memory --exclude-dir=esper
grep -rn '/Users/subelsky/Documents/4-Synergy' ~/.claude/ 2>/dev/null
```

Expected: list of hits inside Synergy, and any hits in user-level Claude config. The second grep may surface external references that are out of scope for this plan but worth flagging to the user.

- [ ] **Step 4.4: For each hit inside `~/Synergy/`, apply the replacement**

For each file the audit surfaced, use the Edit tool to apply the substitution:

| Match pattern | Replacement |
|---|---|
| `/Users/subelsky/Documents/4-Synergy` | `/Users/subelsky/Synergy` (or `$SYNERGY_HOME` in shell scripts) |
| `~/Documents/4-Synergy` | `~/Synergy` (or `$SYNERGY_HOME` in shell scripts) |
| `Documents/4-Synergy` | `Synergy` |
| `4-Synergy` (bare reference to directory name) | `Synergy` |

After each file edit, re-run the targeted grep on that file to verify zero remaining hits:
```bash
grep -n '4-Synergy' <path>
```

Expected: no output (zero hits).

- [ ] **Step 4.5: Surface external hits to the user**

If Step 4.3 found references in `~/.claude/` or elsewhere outside `~/Synergy/`, list them and ask the user to update them separately. Do not modify files outside `~/Synergy/` in this task — that's outside the spec's scope and may break unrelated tooling.

- [ ] **Step 4.6: Final clean-tree verification**

```bash
cd ~/Synergy
grep -rn '4-Synergy' . --include='*.md' --include='*.json' --include='*.sh' --include='*.yml' --include='Containerfile' --exclude-dir=.git --exclude-dir=memory --exclude-dir=esper
```

Expected: no output.

---

## Task 5: Update Claude settings.json

**Files:** `~/Synergy/.claude/settings.json` (full `permissions` block rewrite; preserve any unrelated keys already present).

- [ ] **Step 5.1: Read current settings.json**

```bash
cat ~/Synergy/.claude/settings.json
```

Capture full content. The spec rewrites the `permissions` block; any other top-level keys (e.g., `hooks`, `mcpServers`) must be preserved.

- [ ] **Step 5.2: Rewrite the `permissions` block**

Use the Edit tool to replace the existing `permissions` block (or insert one if absent) with:

```json
"permissions": {
  "additionalDirectories": [
    "~/Documents/0-Projects",
    "~/Documents/1-Areas",
    "~/Documents/2-Resources",
    "~/Documents/3-Archive"
  ],
  "allow": [
    "Bash(~/Synergy/bin/*:*)",
    "Read(~/Documents/0-Projects/**)",
    "Read(~/Documents/1-Areas/**)",
    "Read(~/Documents/2-Resources/**)",
    "Read(~/Documents/3-Archive/**)",
    "Edit(~/Documents/0-Projects/**)",
    "Edit(~/Documents/1-Areas/**)",
    "Edit(~/Documents/2-Resources/**)",
    "Edit(~/Documents/3-Archive/**)",
    "Read(~/Synergy/memory/**)",
    "Edit(~/Synergy/memory/**)",
    "Read(~/Synergy/esper/index.md)",
    "Read(~/Synergy/esper/log.md)",
    "Read(~/Synergy/esper/pages/**)"
  ],
  "deny": [
    "Read(~/Synergy/esper/raw/**)",
    "Read(~/Synergy/esper/_staging/**)",
    "Edit(~/Synergy/esper/**)"
  ]
}
```

Preserve all other keys in `settings.json`. If existing `allow`/`deny` entries from the user are present and not in conflict, ask the user whether to merge them in or leave them dropped.

- [ ] **Step 5.3: Validate JSON**

```bash
python3 -c 'import json; json.load(open("/Users/subelsky/Synergy/.claude/settings.json"))' && echo "valid" || echo "INVALID"
```

Expected: `valid`.

- [ ] **Step 5.4: Inspect settings.local.json for conflicts**

```bash
cat ~/Synergy/.claude/settings.local.json
```

Surface any entries that conflict with the new shared settings (e.g., a local `deny` rule that contradicts a shared `allow`). Ask the user how to reconcile.

---

## Task 6: Update super_containers launcher configs — **DEFERRED**

Supercontainers do not currently mount cog or ember. Adding those mounts requires a container rebuild and is out of scope for this migration. Track as a follow-up:

- Rebuild personal + work supercontainers with cog rw mount (`~/Synergy/memory/` → `/cog/`) and ember ro mount (`~/Synergy/esper/{pages,index.md,log.md}` → `/ember/`)
- Inject `COG=/cog` and `EMBER=/ember` env vars
- Once rebuilt, run the deferred smoke tests (Steps 8.5 and 8.7)

For this migration, only the host-side path change matters: any super_containers config that *does* reference `~/Documents/4-Synergy/` (e.g., a workspace mount or shared helper script) must still be updated. Quick check:

- [ ] **Step 6.1: Audit super_containers for any 4-Synergy references**

```bash
grep -rn 'Documents/4-Synergy\|4-Synergy' ~/super_containers/ 2>/dev/null
```

If any hits surface, decide with the user whether to update them now (outside the cog/ember rebuild scope) or defer alongside the rebuild.

---

## Task 7: Verify clean_room

**Files:** None modified. Verification only.

- [ ] **Step 7.1: Verify SCRIPT_DIR resolution**

```bash
bash -c 'cd ~/Synergy/clean_room && SCRIPT_DIR="$(cd "$(dirname start.sh)" && pwd)"; SYNERGY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; echo "SCRIPT_DIR=$SCRIPT_DIR"; echo "SYNERGY_DIR=$SYNERGY_DIR"'
```

Expected: `SCRIPT_DIR=/Users/subelsky/Synergy/clean_room` and `SYNERGY_DIR=/Users/subelsky/Synergy`.

- [ ] **Step 7.2: Launch a clean_room shell session**

Ask user to confirm before launching the container.

```bash
~/Synergy/clean_room/start.sh shell
```

Expected: container starts, drops user into a shell.

- [ ] **Step 7.3: Inside the container, verify mounts**

Inside the container shell:
```sh
ls /workspace/
ls /workspace/esper/ | head
mount | grep -E 'workspace|esper|sources'
```

Expected: `/workspace` shows Synergy contents (CLAUDE.md, esper/, etc.). `/workspace/esper/` shows the ember subdirs. Mount table shows the expected sources.

- [ ] **Step 7.4: Exit cleanly**

```sh
exit
```

Do NOT run `/integrate` in this task. Real ingestion is exercised in Task 8.

---

## Task 8: Smoke tests

**Files:** None modified. Validation only.

- [ ] **Step 8.1: Daily driver loads cleanly**

In a new terminal:
```bash
cd ~/Synergy
claude
```

Inside the Claude session:
- Confirm the session-start banner shows `hot-memory.md` and `cog-meta/patterns.md` were loaded.
- Type `/personal` and confirm the skill activates.
- Confirm MCP servers appear connected (check via `/mcp` if available, or by invoking an apple-events / things tool).

Expected: all three load cleanly, no path errors.

- [ ] **Step 8.2: Documents access works**

Inside the daily-driver Claude session, ask it to read a known file under `~/Documents/0-Projects/`:
> Read `~/Documents/0-Projects/Build StoryField/README.md` (or whatever exists) and summarize.

Expected: read succeeds, no permission prompt (since `0-Projects` is in `additionalDirectories` + `Read(...)` allow rule).

- [ ] **Step 8.3: Ember deny rule fires**

Inside the daily-driver session, ask Claude to read raw ember storage:
> Read `~/Synergy/esper/raw/` (list contents).

Expected: deny rule triggers; Claude is blocked from reading. If it succeeds, the deny rule is misconfigured — return to Task 5.

- [ ] **Step 8.4: Bin allowlist works**

```bash
ln -s /usr/bin/date ~/Synergy/bin/today
```

Inside the daily-driver Claude session:
> Run `today` and tell me the result.

Expected: invocation succeeds with no permission prompt. Output is current date.

Cleanup:
```bash
rm ~/Synergy/bin/today
```

- [ ] **Step 8.5: Personal supercontainer cog write-back — DEFERRED**

Skipped until supercontainers are rebuilt with cog/ember mounts (see Task 6 deferred notes).

- [ ] **Step 8.6: Clean room ember integration dry run**

```bash
~/Synergy/clean_room/start.sh
```

Inside the clean_room Claude session:
> Run `/integrate` in dry-run mode (or whatever the no-write equivalent is for the user's `/integrate` skill).

Expected: integration scaffolding works end-to-end, source mounts are visible, no path errors. Exit without committing real ingest changes unless the user wants to.

- [ ] **Step 8.7: Work supercontainer cog write-back — DEFERRED**

Skipped until work supercontainer is rebuilt (see Task 6 deferred notes).

- [ ] **Step 8.8: Final report**

Surface to the user:
- Which smoke tests passed.
- Any external `4-Synergy` references found in Step 4.5 that the user still needs to update.
- Any settings.local.json conflicts surfaced in Step 5.4.
- Recommendation for next steps (e.g., update Spotlight, update aliases/shortcuts that reference the old path).

---

## Self-review notes

Plan covers all six spec phases (Pre-flight → Smoke tests). Bin allowlist (B1 wildcard), full cog scope for both supercontainers, scoped PARA additionalDirectories — all reflected in Task 5 + Task 6. No commit steps per user CLAUDE.md. No placeholders; every step has exact commands and expected output. Discovery step in Task 6 acknowledges that super_containers internal layout is not known to this plan.
