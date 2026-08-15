# Synergy User Guide

Synergy is your AI — named after the holographic computer in Jem and the Holograms. It runs in Claude Code and maintains two persistent systems that grow with you over time.

## The Two Systems

### Cog — Your Cognitive State (`memory/`)

Cog is your mind's working memory. It tracks who you are, what you're doing, what you're thinking about, and what needs to happen next.

**What goes in Cog:**
- Your identity, relationships, health, habits
- Active projects and action items
- Calendar and scheduling
- Observations about your life (timestamped, append-only)
- Entities (people, organizations, things you interact with)
- Patterns Synergy has noticed across your conversations

**When you're using Cog:** When you open Claude Code in the Synergy directory (`~/Synergy`). Cog is your productivity and personal organization console — you visit it intentionally to think, plan, reflect, and direct your life. It doesn't run in the background when you're coding in other repos.

### Esper — Your Knowledge Base (`esper/`)

Esper is your compiled knowledge — named after the image enhancement machine in Blade Runner. It takes raw inputs (highlights, articles, emails, transcripts) and reveals what's hidden: connections, themes, contradictions, synthesis.

**What goes in Esper:**
- Kindle highlights and book notes
- Saved emails and email threads
- Instapaper articles and web clippings
- Things 3 projects and tasks
- Claude chat transcripts (chatbot conversations)
- Claude Code session transcripts (from all your devcontainers)
- Git history and documentation from your codebases

**When you're using Esper:** When you want to search your accumulated knowledge, find connections across sources, or ask "what do I know about X?"

## How They Work Together

Cog knows what you're *doing*. Esper knows what you've *learned*.

They cross-reference each other. A Cog observation about your TrayVerify work might link to an Esper topic page synthesizing articles you've read about computer vision. An Esper page about leadership might link back to Cog entities — the people you actually lead.

The pipeline skills (`/housekeeping`, `/reflect`, `/foresight`) are aware of both systems and maintain the connections.

## Daily Workflow

### Just talking to Synergy

Open Claude Code in the Synergy directory. Talk normally. Synergy routes to the right domain automatically based on what you're discussing.

- Talking about your kids, health, home? That's `/personal`
- Working on TrayVerify? That's `/trayverify`
- Planning the London installation? That's `/storyfield`
- Asking about your podcast? That's `/podcast`

You can invoke domain skills explicitly (`/personal`, `/trayverify`, etc.) or just talk and let Synergy figure it out.

### Feeding Esper

Run `/integrate` in the **raw-data container** to process new sources. This is a batch operation — it finds everything new since the last run and processes it all.

```
# On the host: open the repo in the .devcontainer/ container
# (VS Code "Reopen in Container", or: devcontainer up --workspace-folder .)
/integrate
```

`/integrate` refuses to run anywhere else. It is gated on `SYNERGY_RAW=1`, which only that
container sets — see Security below.

Synergy reads your new highlights, emails, articles, and transcripts. For each source, it creates a summary page, links it to relevant topics, and updates the index. Topics emerge automatically when 3+ sources share a theme.

You don't write any of this. Synergy does all the filing, cross-referencing, and bookkeeping.

### Querying your knowledge

Use `/esper` to ask questions against your knowledge base:

```
/esper What do I know about leadership?
/esper What have I read about computer vision recently?
/esper What connections exist between my podcast interviews and my TrayVerify work?
```

Synergy searches the topic index, reads relevant pages, and synthesizes an answer with citations back to specific sources.

### Health checks

Use `/esper` in lint mode to keep Esper healthy:

```
/esper lint
```

This finds orphan pages, stale topics, missing cross-references, and suggests new topics or sources to investigate.

## The Skills

| Skill | System | Purpose | When to use |
|-------|--------|---------|-------------|
| `/personal` | Cog | Family, health, home, hobbies | Talking about your life |
| `/trayverify` | Cog | TrayVerify CTO work | Working on tray verification |
| `/mthr` | Cog | Museum of the UN experience | MTHR project work |
| `/storyfield` | Cog | Generative mural installation | StoryField project work |
| `/podcast` | Cog | Creative Technology Field Notes | Podcast planning/production |
| `/visibility` | Cog | Career strategy | Networking, portfolio, positioning |
| `/website` | Cog | Personal site | Website design work |
| `/cog` | Cog | Memory conventions, setup, add a domain | Bootstrapping or reconfiguring domains |
| `/integrate` | Esper | Ingest new sources | When you have new content to process (raw-data container only) |
| `/esper` | Esper | Query + lint | When you want to search your knowledge or health-check it |
| `/housekeeping` | Both | Maintenance | Weekly — prunes, archives, sweeps expired facts, audits links |
| `/reflect` | Both | Self-improvement | Weekly, right after housekeeping — mines conversations, consolidates patterns |
| `/foresight` | Both | Strategic nudges | Weekly or on demand — connects dots across domains |
| `/evolve` | Cog | Architecture audit | Monthly — proposes system improvements |
| `/scenario` | Cog | Decision simulation | When facing a decision with multiple paths |
| `/history` | Cog | Deep memory search | When trying to recall past conversations |
| `/explainer` | - | Writing and explanation | When drafting content |
| `/humanizer` | - | De-AI text | When rewriting AI-generated text |

## Where Does This Go?

A quick decision tree for where information lives:

**"I just learned something about myself"** — Cog observation
**"I just read an interesting article"** — Esper source (via /integrate)
**"I need to remember to do something"** — Cog action item
**"What did I read about X?"** — Esper query (via /esper)
**"What's going on with my project?"** — Cog domain hot-memory
**"Connect the dots across everything"** — /foresight (reads both)

**"Someone emailed me something important"**
- The email content → Esper (processed by /integrate)
- The action it requires → Cog action item
- The person who sent it → Cog entity

**"I had a great Claude conversation about architecture"**
- The transcript → Esper (processed by /integrate)
- Decisions made → Cog observations or action items
- Patterns noticed → Cog patterns (via /reflect)

## The Pipeline

These skills maintain the systems over time. **Run them consolidated — in one session, in order** — so later skills see what earlier ones cleaned.

| Pulse | Skills | Cadence | What it does |
|-------|--------|---------|-------------|
| Maintenance | `/housekeeping` then `/reflect` | Weekly | Archives, prunes, sweeps expired facts, rebuilds indexes — then mines conversations and consolidates patterns against the cleaned state |
| Architecture | `/evolve` | Monthly | Audits the rules the other skills follow |
| Strategic | `/foresight` | Weekly or on demand | Reads both systems, writes one nudge |
| Ingestion | `/integrate` | As needed | Processes new sources into Esper (raw-data container) |

Running everything nightly is theatrical — it generates reports nobody reads and re-logs the same
issues without resolving them.

## Security

`/integrate` processes untrusted content (emails, web articles, transcripts) that could carry prompt
injection. It runs in a purpose-built container defined at `.devcontainer/`:

- **Requires `SYNERGY_RAW=1`** — set only by that container, and won't run without it. (The old
  gate was `DEVCONTAINER=true`, which every devcontainer on the machine sets, so it was
  effectively always open.)
- **`memory/` is not mounted.** The sandbox cannot read your Cog memory at all — not read-only,
  not at all.
- Write access only to `esper/`. Source directories are mounted read-only.
- Isolated Claude config and npm cache — never your host `~/.claude`, so nothing it writes can
  persist a hook or skill that later runs on the host.
- **Allowlisted network egress** (Anthropic API and npm registry), not zero network. Shell
  commands *are* available inside the container; the boundary is the container itself.
- Two-phase processing: raw content is summarized first (extract), then the summary is filed
  (integrate) — a prompt injection has to survive being summarized.

On the host, the reverse posture applies: `WebFetch`/`WebSearch` are denied and `esper/raw/` and
`esper/_staging/` are unreadable, so untrusted text never meets your memory and your credentials.

## Synergy and Your Other Repos

Cog only loads when you're in the Synergy directory. When you open Claude Code in `~/Projects/trayverify/` to write code, that Claude has its own repo-specific CLAUDE.md and knows nothing about Cog. This is intentional — you don't want your coding Claude loading personal memory and cognitive architecture on every conversation.

**How knowledge flows back from other repos:**

Claude Code transcripts from your other projects get copied into `esper/raw/claude-code/` and processed by `/integrate`. So your TrayVerify coding sessions, your StoryField experiments, your podcast editing — all of that knowledge flows into Esper, gets synthesized into topic pages, and becomes searchable.

The mental model:

| Where you are | What Claude knows | Purpose |
|---------------|-------------------|---------|
| `~/Projects/trayverify/` | Repo code, repo CLAUDE.md | Write code, fix bugs |
| `~/Projects/storyfield/` | Repo code, repo CLAUDE.md | Build the installation |
| `~/Synergy/` | Cog + Esper + all domains | Think, plan, reflect, search |

**Synergy is your command center.** The other repos are where you do the work. You visit Synergy to zoom out — "how's TrayVerify going overall?", "what patterns am I seeing across my projects?", "what should I focus on this week?"

## Getting Started

1. **Cog is already running.** Every conversation with Synergy in this directory uses it.
2. **Set up Esper** by creating the directory structure and your first source manifests.
3. **Configure `.devcontainer/devcontainer.json`** with read-only mounts to your source directories.
4. **Run `/integrate`** to process your first batch of sources.
5. **Use `/esper`** to explore what Synergy found.
6. **Set up the pipeline** — schedule `/foresight` daily and `/housekeeping` + `/reflect` weekly.

The systems compound over time. The more you feed them, the more connections they find, the more useful they become. You curate and direct. Synergy does the grunt work.
