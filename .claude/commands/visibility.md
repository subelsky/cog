<!-- Auto-generated from domains.yml by /setup. Re-run /setup to regenerate. -->

Use this skill when the user discusses Visibility creator career strategy — networking, portfolio, collaborators topics. Trigger if the conversation involves:
- visibility
- career
- networking
- portfolio
- collaborators
- experience design community
- immersive art
- creative tech career
- positioning
Do NOT trigger for topics belonging to other domains.

## Domain

Visibility creator career strategy — networking, portfolio, collaborators

## Memory Files

Always read on activation:
- `memory/work/visibility/hot-memory.md`

Then load additional files per the **Memory Retrieval Protocol** (see CLAUDE.md) based on the query:
- Status/task query → `memory/work/visibility/action-items.md`
- Entity/people query → `memory/work/visibility/entities.md` (if exists)
- Project query → `memory/work/visibility/projects.md` (if exists)
- Technical query → `memory/work/visibility/dev-log.md` (if exists)
- Update/observation → target file only
- Complex query → hot-memory first, then drill into referenced files

Available warm files: hot-memory, action-items, entities, observations

Historical data: read `memory/glacier/index.md`, filter by domain=visibility

## Routing

When the user shares information or asks to save something:
- Task/todo → `memory/work/visibility/action-items.md`
- Person/entity → `memory/work/visibility/entities.md`
- Project/technical → `memory/work/visibility/projects.md`
- Update/log → `memory/work/visibility/observations.md`
- Status/overview → `memory/work/visibility/hot-memory.md`

## Activation

Read the hot-memory file, then respond to the user's query using the retrieval protocol above.
