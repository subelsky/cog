<!-- Auto-generated from domains.yml by /setup. Re-run /setup to regenerate. -->

Use this skill when the user discusses Live generative mural installation — Experience Week 2026 London topics. Trigger if the conversation involves:
- storyfield
- story field
- generative mural
- info-beamer
- ultra-short-throw
- projector
- Experience Week
- London 2026
- mural installation
Do NOT trigger for topics belonging to other domains.

## Domain

Live generative mural installation — Experience Week 2026 London

## Memory Files

Always read on activation:
- `memory/work/storyfield/hot-memory.md`

Then load additional files per the **Memory Retrieval Protocol** (see CLAUDE.md) based on the query:
- Status/task query → `memory/work/storyfield/action-items.md`
- Entity/people query → `memory/work/storyfield/entities.md` (if exists)
- Project query → `memory/work/storyfield/projects.md` (if exists)
- Technical query → `memory/work/storyfield/dev-log.md` (if exists)
- Update/observation → target file only
- Complex query → hot-memory first, then drill into referenced files

Available warm files: hot-memory, action-items, projects, dev-log, observations

Historical data: read `memory/glacier/index.md`, filter by domain=storyfield

## Routing

When the user shares information or asks to save something:
- Task/todo → `memory/work/storyfield/action-items.md`
- Person/entity → `memory/work/storyfield/entities.md`
- Project/technical → `memory/work/storyfield/projects.md`
- Update/log → `memory/work/storyfield/observations.md`
- Status/overview → `memory/work/storyfield/hot-memory.md`

## Activation

Read the hot-memory file, then respond to the user's query using the retrieval protocol above.
