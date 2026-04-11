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

**When you're using Cog:** When you open Claude Code in the Synergy directory (`~/Documents/Synergy`). Cog is your productivity and personal organization console — you visit it intentionally to think, plan, reflect, and direct your life. It doesn't run in the background when you're coding in other repos.

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

Run `/integrate` in the devcontainer to process new sources. This is a batch operation — it finds everything new since the last run and processes it all.

```
# In the devcontainer (DEVCONTAINER=true required)
/integrate
```

Synergy reads your new highlights, emails, articles, and transcripts. For each source, it creates a summary page, links it to relevant topics, and updates the index. Topics emerge automatically when 3+ sources share a theme.

You don't write any of this. Synergy does all the filing, cross-referencing, and bookkeeping.

### Querying your knowledge

Use `/ember` to ask questions against your knowledge base:

```
/ember What do I know about leadership?
/ember What have I read about computer vision recently?
/ember What connections exist between my podcast interviews and my TrayVerify work?
```

Synergy searches the topic index, reads relevant pages, and synthesizes an answer with citations back to specific sources.

### Health checks

Use `/ember` in lint mode to keep Esper healthy:

```
/ember lint
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
| `/integrate` | Esper | Ingest new sources | When you have new content to process (devcontainer only) |
| `/ember` | Esper | Query + lint | When you want to search your knowledge or health-check it |
| `/housekeeping` | Both | Maintenance | Weekly — prunes, archives, audits links |
| `/reflect` | Both | Self-improvement | Weekly — mines conversations, condenses patterns |
| `/foresight` | Both | Strategic nudges | Daily — connects dots across domains |
| `/evolve` | Cog | Architecture audit | Weekly — proposes system improvements |
| `/scenario` | Cog | Decision simulation | When facing a decision with multiple paths |
| `/history` | Cog | Deep memory search | When trying to recall past conversations |
| `/explainer` | - | Writing and explanation | When drafting content |
| `/humanizer` | - | De-AI text | When rewriting AI-generated text |

## Where Does This Go?

A quick decision tree for where information lives:

**"I just learned something about myself"** — Cog observation
**"I just read an interesting article"** — Esper source (via /integrate)
**"I need to remember to do something"** — Cog action item
**"What did I read about X?"** — Esper query (via /ember)
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

These skills maintain the systems over time. Run them on a schedule or manually:

| Skill | Frequency | What it does |
|-------|-----------|-------------|
| `/foresight` | Daily (morning) | Reads both systems, surfaces one strategic nudge |
| `/integrate` | As needed | Processes new sources into Esper (devcontainer) |
| `/housekeeping` | Weekly | Archives old data, prunes hot memory, audits links, checks Esper health |
| `/reflect` | Weekly | Mines recent conversations, condenses patterns, detects threads |
| `/evolve` | Weekly | Audits the architecture itself, proposes improvements |

## Security

`/integrate` processes semi-trusted content (emails, web articles) that could contain prompt injection. It runs in a locked-down devcontainer:

- Requires `DEVCONTAINER=true` environment variable — won't run without it
- Read-only access to your source files
- Write access only to `esper/` — can't touch Cog, your home directory, or credentials
- No network access, no shell commands
- Two-phase processing: raw content is summarized first (extract), then the summary is filed (integrate) — prompt injections have to survive being summarized

## Synergy and Your Other Repos

Cog only loads when you're in the Synergy directory. When you open Claude Code in `~/Projects/trayverify/` to write code, that Claude has its own repo-specific CLAUDE.md and knows nothing about Cog. This is intentional — you don't want your coding Claude loading personal memory and cognitive architecture on every conversation.

**How knowledge flows back from other repos:**

Claude Code transcripts from your other projects get copied into `esper/raw/claude-code/` and processed by `/integrate`. So your TrayVerify coding sessions, your StoryField experiments, your podcast editing — all of that knowledge flows into Esper, gets synthesized into topic pages, and becomes searchable.

The mental model:

| Where you are | What Claude knows | Purpose |
|---------------|-------------------|---------|
| `~/Projects/trayverify/` | Repo code, repo CLAUDE.md | Write code, fix bugs |
| `~/Projects/storyfield/` | Repo code, repo CLAUDE.md | Build the installation |
| `~/Documents/Synergy/` | Cog + Esper + all domains | Think, plan, reflect, search |

**Synergy is your command center.** The other repos are where you do the work. You visit Synergy to zoom out — "how's TrayVerify going overall?", "what patterns am I seeing across my projects?", "what should I focus on this week?"

## Getting Started

1. **Cog is already running.** Every conversation with Synergy in this directory uses it.
2. **Set up Esper** by creating the directory structure and your first source manifests.
3. **Configure your devcontainer** with read-only mounts to your source directories.
4. **Run `/integrate`** to process your first batch of sources.
5. **Use `/ember`** to explore what Synergy found.
6. **Set up the pipeline** — schedule `/foresight` daily and `/housekeeping` + `/reflect` weekly.

The systems compound over time. The more you feed them, the more connections they find, the more useful they become. You curate and direct. Synergy does the grunt work.
