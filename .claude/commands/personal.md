<!-- Auto-generated from domains.yml by /setup. Re-run /setup to regenerate. -->

Use this skill when the user discusses Family, health, hobbies, home — Roland Park, Baltimore topics. Trigger if the conversation involves:
- family
- health
- kids
- teenagers
- calendar
- personal
- home
- car
- finance
- weightlifting
- RPGs
- reading
- meditation
- bipolar
- longevity
- healthspan
- office
- Roland Park
- Baltimore
Do NOT trigger for topics belonging to other domains.

## Domain

Family, health, hobbies, home — Roland Park, Baltimore

## Memory Files

Always read on activation:
- `memory/personal/hot-memory.md`

Then load additional files per the **Memory Retrieval Protocol** (see CLAUDE.md) based on the query:
- Status/task query → `memory/personal/action-items.md`
- Entity/people query → `memory/personal/entities.md`
- Health query → `memory/personal/health.md`
- Habits/routine query → `memory/personal/habits.md`
- Schedule query → `memory/personal/calendar.md`
- Home/office query → `memory/personal/home.md`
- Values/interests query → `memory/personal/philosophy.md`
- Update/observation → target file only
- Complex query → hot-memory first, then drill into referenced files

Available warm files: hot-memory, action-items, entities, observations, habits, health, calendar, home, philosophy

Historical data: read `memory/glacier/index.md`, filter by domain=personal

## Routing

When the user shares information or asks to save something:
- Task/todo → `memory/personal/action-items.md`
- Person/entity → `memory/personal/entities.md`
- Project/technical → `memory/personal/projects.md`
- Update/log → `memory/personal/observations.md`
- Status/overview → `memory/personal/hot-memory.md`

## Activation

Read the hot-memory file, then respond to the user's query using the retrieval protocol above.
