<!-- Auto-generated from domains.yml by /setup. Re-run /setup to regenerate. -->

Use this skill when the user discusses Creative Technology Field Notes — art x technology interviews topics. Trigger if the conversation involves:
- podcast
- Creative Technology Field Notes
- CTFN
- field notes
- interview
- episode
- guest
- art and technology
Do NOT trigger for topics belonging to other domains.

## Domain

Creative Technology Field Notes — art x technology interviews

## Memory Files

Always read on activation:
- `memory/work/podcast/hot-memory.md`

Then load additional files per the **Memory Retrieval Protocol** (see CLAUDE.md) based on the query:
- Status/task query → `memory/work/podcast/action-items.md`
- Entity/people query → `memory/work/podcast/entities.md` (if exists)
- Project query → `memory/work/podcast/projects.md` (if exists)
- Technical query → `memory/work/podcast/dev-log.md` (if exists)
- Update/observation → target file only
- Complex query → hot-memory first, then drill into referenced files

Available warm files: hot-memory, action-items, projects, observations

Historical data: read `memory/glacier/index.md`, filter by domain=podcast

## Routing

When the user shares information or asks to save something:
- Task/todo → `memory/work/podcast/action-items.md`
- Person/entity → `memory/work/podcast/entities.md`
- Project/technical → `memory/work/podcast/projects.md`
- Update/log → `memory/work/podcast/observations.md`
- Status/overview → `memory/work/podcast/hot-memory.md`

## Activation

Read the hot-memory file, then respond to the user's query using the retrieval protocol above.
