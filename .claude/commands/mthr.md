<!-- Auto-generated from domains.yml by /setup. Re-run /setup to regenerate. -->

Use this skill when the user discusses Immersive interactive experience for Museum of the UN (OdysseyWorks certificate) topics. Trigger if the conversation involves:
- mthr
- mother
- Museum of the UN
- OdysseyWorks
- Odyssey Works
- experience design
- certificate program
- immersive experience
- nature connection
Do NOT trigger for topics belonging to other domains.

## Domain

Immersive interactive experience for Museum of the UN (OdysseyWorks certificate)

## Memory Files

Always read on activation:
- `memory/work/mthr/hot-memory.md`

Then load additional files per the **Memory Retrieval Protocol** (see CLAUDE.md) based on the query:
- Status/task query → `memory/work/mthr/action-items.md`
- Entity/people query → `memory/work/mthr/entities.md` (if exists)
- Project query → `memory/work/mthr/projects.md` (if exists)
- Technical query → `memory/work/mthr/dev-log.md` (if exists)
- Update/observation → target file only
- Complex query → hot-memory first, then drill into referenced files

Available warm files: hot-memory, action-items, projects, dev-log, observations

Historical data: read `memory/glacier/index.md`, filter by domain=mthr

## Routing

When the user shares information or asks to save something:
- Task/todo → `memory/work/mthr/action-items.md`
- Person/entity → `memory/work/mthr/entities.md`
- Project/technical → `memory/work/mthr/projects.md`
- Update/log → `memory/work/mthr/observations.md`
- Status/overview → `memory/work/mthr/hot-memory.md`

## Activation

Read the hot-memory file, then respond to the user's query using the retrieval protocol above.
