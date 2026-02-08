---
name: skill-guide
description: Aurora Skills authoring and maintenance guide for creating, refactoring, or reviewing SKILL.md files with the official minimum format and Aurora runtime extensions.
locked: true
for_ai: false
---

# Aurora Skills Guide (Official Minimum + Aurora Extensions)

## 1. Purpose

This guide answers three practical questions:

1. What a Skill must include at minimum (official baseline)
2. What Aurora adds on top (project extensions)
3. Where turns are configured and how priority works (current implementation)

## 2. Official Minimum Format (Required)

Each Skill directory must contain `SKILL.md` with YAML frontmatter at the top. The minimum required fields are:

```yaml
---
name: your-skill-name
description: WHAT + WHEN
---
```

Requirements:

- `name` is required; use lowercase hyphenated names like `weather-fetcher`
- `description` is required and must clearly describe WHAT and WHEN
- Routing depends on frontmatter metadata (especially `name` and `description`)
- The Markdown body is loaded only after trigger, so usage conditions must not live only in the body

## 3. Writing the SKILL Body

Keep the body focused on How:

1. Write concise, imperative steps
2. Put variant-heavy details in `references/`; keep body as workflow and selection logic
3. Put repeatable deterministic logic in `scripts/`
4. Put templates/materials in `assets/`
5. Prefer executable instructions over long background explanations

## 4. Aurora Discovery Rules (Current)

Aurora recursively scans `skills/` and recognizes:

- `SKILL.md`
- `SKILL_<language>.md` (for example, `SKILL_en.md`)
- If the requested language file is missing, it falls back to `SKILL.md`
- A directory is treated as a Skill if at least one of the files above exists

Recommended structure:

```text
skill-name/
├── SKILL.md
├── SKILL_en.md        # optional
├── scripts/           # optional
├── references/        # optional
└── assets/            # optional
```

## 5. Aurora Frontmatter Extensions (Optional)

Official minimum requires only `name` and `description`. Aurora also supports:

- `enabled: true|false`
- `locked: true|false`
- `for_ai: true|false`
- `platforms: [all|desktop|mobile|windows|macos|linux|android|ios]`
- `id: custom_id` (defaults to folder name when omitted)
- `tools: [...]` (tool definitions)
- `worker_mode: reasoner|executor` (Skill Worker execution mode)

Aurora turns-related extension fields:

- `skill_max_turns`
- Alias keys: `skillMaxTurns`, `worker_max_turns`, `workerMaxTurns`, `subagent_max_turns`, `subagentMaxTurns`, `_aurora_skill_max_turns`, `max_turns`, `maxTurns`

Note: `skill_max_turns` is an Aurora extension, not an official required field.

`worker_mode` behavior:

- `reasoner` (default): Worker may run multi-turn reasoning/tool loops
- `executor`: Worker returns immediately after the first tool output (no in-worker second-pass synthesis)

Alias keys for mode:

- `workerMode`
- `skill_worker_mode`
- `skillWorkerMode`
- `subagent_mode`
- `subagentMode`
- `_aurora_worker_mode`
- `_aurora_skill_worker_mode`

## 6. Turns Configuration and Priority (Current)

### 6.1 Orchestrator (main chat loop)

Keys (read order):

- `orchestrator_max_turns`
- `orchestratorMaxTurns`
- `_aurora_max_turns`
- `max_turns`
- `maxTurns`

Sources (priority order):

1. Provider `customParameters`
2. Provider `globalSettings`

Defaults and limits:

- Default `8`
- Clamped to `1..50`

### 6.2 Skill Worker (single skill execution)

Keys (read order):

- `skill_max_turns`
- `skillMaxTurns`
- `worker_max_turns`
- `workerMaxTurns`
- `subagent_max_turns`
- `subagentMaxTurns`
- `_aurora_skill_max_turns`
- `max_turns`
- `maxTurns`

Sources (priority order):

1. Skill frontmatter metadata
2. Provider `customParameters`
3. Provider `globalSettings`

Defaults and limits:

- Default `6`
- Clamped to `1..30`

Additional runtime note:

- `WorkerService` base defaults are `maxTurns=8` and shell timeout `45s`
- In chat orchestration, explicit resolved values are passed, so the `6/1..30` rule usually applies

## 7. Configuration Entry Points

### 7.1 Where to set Skill frontmatter

In Aurora UI:

1. `Settings`
2. `Agent Skills`
3. Select a skill and click `Edit`
4. Edit YAML frontmatter directly at the top of `SKILL.md`

### 7.2 Where to set customParameters

Desktop entry points are the two Custom Parameters cards under provider configuration:

1. `Settings` -> `Model Provider` -> provider-level gear button (Global Config) -> `Custom Parameters`
2. `Settings` -> `Model Provider` -> model row gear button (Model Config) -> `Custom Parameters`

Current behavior note:

- Turns resolution reads `customParameters`, `globalSettings`, and skill metadata
- Model-specific `modelSettings` custom params currently do not participate in turns resolution (they mainly override request params)

## 8. Recommended Template

```yaml
---
name: weather-fetcher
description: Fetch real-time weather for a city. Trigger when users ask about weather, temperature, rain, or wind.
enabled: true
for_ai: true
platforms: [desktop]
skill_max_turns: 10
worker_mode: reasoner
---
```

```markdown
# Weather Fetcher

## Instructions
1. Validate the input city
2. Fetch weather data
3. Return structured output

## Examples
- Input: Weather in Shanghai
- Output: { ... }
```

## 9. Pre-commit Checklist

- Frontmatter parses as valid YAML
- `name` and `description` are present and precise
- `description` clearly covers WHAT + WHEN
- Body is actionable and concise
- `skill_max_turns` is set when multi-step tool execution is expected
- Use `worker_mode: executor` when a single tool call is enough
