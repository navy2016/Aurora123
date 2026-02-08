---
name: skill-guide
description: Aurora Skills 编写与维护指南。用于创建、重构或审核 SKILL.md，确保符合官方最小规范并兼容 Aurora 扩展与可配置轮次。
locked: true
for_ai: false
---

# Aurora Skills 开发指南（官方规范 + Aurora 扩展）

## 1. 目标

本指南用于回答三个问题：

1. 一个 Skill 至少要写成什么样（官方最小标准）
2. Aurora 额外支持了哪些字段和行为（项目扩展）
3. turns 在哪里配、按什么优先级生效（当前实现）

## 2. 官方最小标准（必须）

每个 Skill 目录必须包含 `SKILL.md`，文件头使用 YAML frontmatter，最小只需要两个字段：

```yaml
---
name: your-skill-name
description: WHAT + WHEN（做什么 + 何时触发）
---
```

约束：

- `name` 必填，建议小写连字符，如 `weather-fetcher`
- `description` 必填，必须写清楚 WHAT 和 WHEN
- 路由阶段只依赖 frontmatter（尤其是 `name`、`description`）
- 正文（Markdown body）是在 Skill 被触发后才加载，所以“何时使用”不要只写在正文里

## 3. SKILL 正文编写原则

正文只写 How（怎么做）：

1. 用简洁步骤描述执行流程（祈使句）
2. 可变体内容放到 `references/`，正文只保留入口和选择规则
3. 重复性强、可确定执行的逻辑放 `scripts/`
4. 输出模板或素材放 `assets/`
5. 避免堆砌背景说明，优先可执行指令

## 4. Aurora 的目录发现规则（当前实现）

Aurora 会递归扫描 `skills/`：

- 识别 `SKILL.md`
- 识别 `SKILL_<language>.md`（如 `SKILL_en.md`）
- 若指定语言文件不存在，回退到 `SKILL.md`
- 目录中只要存在以上文件之一，即可被识别为一个 Skill

推荐结构：

```text
skill-name/
├── SKILL.md
├── SKILL_en.md        # 可选
├── scripts/           # 可选
├── references/        # 可选
└── assets/            # 可选
```

## 5. Aurora frontmatter 扩展字段（可选）

官方最小只要求 `name` + `description`。Aurora 额外支持以下字段：

- `enabled: true|false`
- `locked: true|false`
- `for_ai: true|false`
- `platforms: [all|desktop|mobile|windows|macos|linux|android|ios]`
- `id: custom_id`（不填时默认目录名）
- `tools: [...]`（工具定义）
- `worker_mode: reasoner|executor`（Skill Worker 执行模式）

与 turns 相关的 Aurora 扩展字段：

- `skill_max_turns`
- 兼容别名：`skillMaxTurns`、`worker_max_turns`、`workerMaxTurns`、`subagent_max_turns`、`subagentMaxTurns`、`_aurora_skill_max_turns`、`max_turns`、`maxTurns`

说明：`skill_max_turns` 是 Aurora 项目扩展，不是官方必需 frontmatter 字段。

`worker_mode` 说明：

- `reasoner`（默认）：Worker 可多轮推理与工具调用
- `executor`：Worker 在拿到首个工具输出后直接返回结果，不在 Worker 内做二次收尾

兼容别名（模式字段）：

- `workerMode`
- `skill_worker_mode`
- `skillWorkerMode`
- `subagent_mode`
- `subagentMode`
- `_aurora_worker_mode`
- `_aurora_skill_worker_mode`

## 6. turns 配置与优先级（当前实现）

### 6.1 Orchestrator（主对话编排）

键名（按读取顺序）：

- `orchestrator_max_turns`
- `orchestratorMaxTurns`
- `_aurora_max_turns`
- `max_turns`
- `maxTurns`

来源与顺序：

1. Provider `customParameters`
2. Provider `globalSettings`

默认值与范围：

- 默认 `8`
- 限制 `1..50`

### 6.2 Skill Worker（单个 skill 执行）

键名（按读取顺序）：

- `skill_max_turns`
- `skillMaxTurns`
- `worker_max_turns`
- `workerMaxTurns`
- `subagent_max_turns`
- `subagentMaxTurns`
- `_aurora_skill_max_turns`
- `max_turns`
- `maxTurns`

来源与顺序：

1. Skill frontmatter（metadata）
2. Provider `customParameters`
3. Provider `globalSettings`

默认值与范围：

- 默认 `6`
- 限制 `1..30`

补充：

- WorkerService 底层默认 `maxTurns=8`、shell timeout `45s`
- 但在聊天编排路径下会显式传入上述解析值，通常以 `6/1..30` 规则为准

## 7. 配置入口

### 7.1 Skill frontmatter 在哪里设置

在 Aurora UI：

1. `Settings`
2. `Agent Skills`
3. 选中某个 skill，点击 `Edit`
4. 直接修改 `SKILL.md` 顶部 YAML frontmatter

### 7.2 customParameters 在哪里设置

当前桌面端主要入口是 Provider 配置的两类 Custom Parameters 卡片：

1. `Settings` -> `Model Provider` -> provider 区域右上齿轮（Global Config）-> `Custom Parameters`
2. `Settings` -> `Model Provider` -> 模型行右侧齿轮（Model Config）-> `Custom Parameters`

注意：

- turns 解析当前读取 `customParameters` + `globalSettings` + skill metadata
- model-specific 的 `modelSettings` 自定义参数目前不参与 turns 解析（它主要用于请求参数覆盖）

## 8. 推荐模板

```yaml
---
name: weather-fetcher
description: 获取指定城市实时天气。当用户询问天气、温度、降雨或风力时触发。
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
1. 校验输入
2. 拉取数据
3. 返回结构化结果

## Examples
- Input: 上海天气
- Output: { ... }
```

## 9. 提交前检查清单

- frontmatter 可被 YAML 正常解析
- `name` 与 `description` 已填写且语义明确
- `description` 明确写了 WHAT + WHEN
- 正文以可执行步骤为主，避免冗长背景
- 需要多步工具调用时，已设置合理的 `skill_max_turns`
- 单次工具执行即可完成时，考虑使用 `worker_mode: executor`
