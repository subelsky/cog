<!-- Auto-generated from domains.yml by /setup. Re-run /setup to regenerate. -->

Use this skill when the user discusses Personal website design and portfolio topics. Trigger if the conversation involves:
- website
- portfolio site
- web design
- personal site
- homepage
Do NOT trigger for topics belonging to other domains.

## Domain

Personal website design and portfolio

## Memory Files

Always read on activation:
- `memory/work/website/hot-memory.md`

Then load additional files per the **Memory Retrieval Protocol** (see CLAUDE.md) based on the query:
- Status/task query → `memory/work/website/action-items.md`
- Entity/people query → `memory/work/website/entities.md` (if exists)
- Project query → `memory/work/website/projects.md` (if exists)
- Technical query → `memory/work/website/dev-log.md` (if exists)
- Update/observation → target file only
- Complex query → hot-memory first, then drill into referenced files

Available warm files: hot-memory, action-items, observations

Historical data: read `memory/glacier/index.md`, filter by domain=website

## Routing

When the user shares information or asks to save something:
- Task/todo → `memory/work/website/action-items.md`
- Person/entity → `memory/work/website/entities.md`
- Project/technical → `memory/work/website/projects.md`
- Update/log → `memory/work/website/observations.md`
- Status/overview → `memory/work/website/hot-memory.md`

## Activation

Read the hot-memory file, then respond to the user's query using the retrieval protocol above.
