# Architecture

Cog is simple by design. Everything is plain text — markdown conventions and memory files — so Claude Code can reason over its own memory with the same Unix tools it already knows: `grep` for patterns, `find` for changes, `git diff` for history.

This isn't a framework to install. It's a set of conventions that Claude follows to scaffold and maintain a persistent memory system. You define the rules, Claude builds the structure, and you can observe every decision the model makes about how to organize its own knowledge.

## How It Works

Cog has no server, no runtime, no daemon. It's a project directory with conventions.

```
Open the project in Claude Code → Claude reads CLAUDE.md
    → memory/ is available as persistent storage
    → skills route conversations via slash commands
    → memory files update as you work
```

When you open a Cog project, Claude reads `CLAUDE.md` — the instruction set that defines persona, memory rules, domain routing, and skill behaviors. The `memory/` directory is the persistent knowledge base. Skills are markdown prompt files in `.claude/commands/`. That's the entire system.

No process to start. No session to manage. No infrastructure to maintain.

## Interface Agnostic

Cog's memory is just markdown files. Any Claude-powered tool with file access can use it:

- **Claude Code** — the primary interface. Terminal-native, skill routing via slash commands, real-time memory updates.
- **Cowork** — Claude Desktop's agentic mode. Point it at `memory/` and it inherits everything. Good for heavy document generation, multi-file research, long autonomous workflows. See [Using Cog with Cowork](/cowork).
- **Any future Claude tool** — if it can read and write files, it can use Cog's memory.

The interface determines how context is loaded and how you interact. The memory system doesn't care — it's files on disk.

## Skills

Slash commands route conversations to the right domain and behavior. Each skill is a markdown prompt file in `.claude/commands/` that tells Claude what files to load and how to behave.

**Built-in skills** ship with every Cog instance:

| Skill | Domain |
|-------|--------|
| `/personal` | Family, health, calendar, day-to-day |
| `/explainer` | Writing, explanation, long-form |
| `/humanizer` | Rewrite AI text in human voice |
| `/reflect` | Self-improvement, conversation mining |
| `/evolve` | Systems architecture audit |
| `/history` | Deep memory search, recall |
| `/foresight` | Cross-domain strategic nudge |
| `/scenario` | Decision simulation, branch modeling |
| `/housekeeping` | Memory maintenance, archival |
| `/setup` | Bootstrap domains from manifest |

**Domain skills** are auto-generated from `memory/domains.yml` — add a domain to the manifest, run `/setup`, and Cog creates the skill file, memory directories, and routing rules. No code changes needed. See the [journal entry](/journal/domain-registry) for the full story.

Skills handle their own memory loading. The main instruction set doesn't duplicate that logic — it provides the routing table so Cog knows where to look.

## Domain Registry

All memory domains are defined in a single YAML manifest (`memory/domains.yml`). The manifest is the **single source of truth** for domain structure — pipeline skills and the routing table all read from it.

```yaml
domains:
  - id: work
    path: work/acme
    type: work
    label: "Day job at Acme Corp"
    triggers: [acme, work, colleagues, projects]
    files: [hot-memory, action-items, entities, projects, dev-log, observations]
```

Each domain has a type (`personal`, `work`, `side-project`, `system`) that determines how the pipeline treats it. Work and side-project domains are automatically included in foresight scans. Domains can have subdomains for focused sub-topics.

The `/setup` skill reads the manifest and generates:
- Memory directories with starter files (hot-memory, observations, action-items, entities)
- Domain command files from `.claude/commands/_templates/domain.md`
- Updated routing table in `CLAUDE.md`

Running `/setup` is idempotent — it creates what's missing, regenerates command files from the template, and leaves everything else alone.

## Design Principles

**Simpler always wins.** Every architecture decision that survived is the simpler option. Feature velocity comes from removing complexity, not adding it. When two approaches solve the same problem, the one with fewer moving parts wins.

**Data transformation is the superpower.** The system is optimized for turning unstructured input into structured, actionable output:

- Voice note while working → entity profile update
- Photo of a document → structured tracking file
- PDF from a specialist → session notes with goals and observations
- Scattered conversation fragments → synthesized thread with narrative arc
