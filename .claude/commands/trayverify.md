<!-- Auto-generated from domains.yml by /setup. Re-run /setup to regenerate. -->

Use this skill when the user discusses Founding CTO — AI food verification for healthcare kitchens topics. Trigger if the conversation involves:
- trayverify
- tray verify
- food verification
- healthcare kitchen
- YOLO
- Hailo
- Raspberry Pi
- computer vision
- AI HAT
- Next.js
- CTO
Do NOT trigger for topics belonging to other domains.

## Domain

Founding CTO — AI food verification for healthcare kitchens

## Memory Files

Always read on activation:
- `memory/work/trayverify/hot-memory.md`

Then load additional files per the **Memory Retrieval Protocol** (see CLAUDE.md) based on the query:
- Status/task query → `memory/work/trayverify/action-items.md`
- Entity/people query → `memory/work/trayverify/entities.md`
- Project query → `memory/work/trayverify/projects.md` (if exists)
- Technical query → `memory/work/trayverify/dev-log.md` (if exists)
- Update/observation → target file only
- Complex query → hot-memory first, then drill into referenced files

Available warm files: hot-memory, action-items, entities, projects, dev-log, observations

Historical data: read `memory/glacier/index.md`, filter by domain=trayverify

## Routing

When the user shares information or asks to save something:
- Task/todo → `memory/work/trayverify/action-items.md`
- Person/entity → `memory/work/trayverify/entities.md`
- Project/technical → `memory/work/trayverify/projects.md`
- Update/log → `memory/work/trayverify/observations.md`
- Status/overview → `memory/work/trayverify/hot-memory.md`

## Activation

Read the hot-memory file, then respond to the user's query using the retrieval protocol above.
