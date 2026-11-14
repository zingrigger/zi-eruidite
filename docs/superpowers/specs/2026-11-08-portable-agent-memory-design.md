# 可移植 Agent 记忆系统（起步骨架）设计

日期：2026-11-08
状态：待批准
来源：实践 Anthropic《The components of agent memory》(2026-11-06)

## 意图与为什么

在本 blog repo 里落地文章的记忆架构，做成**项目自带、跨 harness** 的能力：任何
agent 工具（Qoder / Claude Code / dsh / …）打开这个项目都能自动加载记忆、记录要点、
离线整理。**不改造任何 harness，也不新造 harness**——全部靠 repo 里的 markdown 文件
+ 各 harness 本来就会读的指令文件（AGENTS.md）实现。

驱动：想真正实践文章原理，且不被单一工具绑死。

## 关键事实（已核实）

- 项目级记忆目录 `~/.qoder-cn/projects/-Users-rogerz-workspace-zi-eruidite/memory/`
  存在但**空**，且在 Qoder home 下、**不在 repo**——本身不跨 harness，不能当骨架。
- repo 里**没有** `.qoder/repowiki/`；repowiki 内容在 Qoder app 侧，换 harness 拿不到。
- repo 已有大半个 wiki 层：`docs/adr/`、`docs/guides/`、`docs/components/`、
  `docs/superpowers/specs/`（19 篇设计文档）。`docs/agents/domain.md` 已约定开局读
  `CONTEXT.md` + `docs/adr/`。
- 根 `AGENTS.md` 是 Qoder 自动加载的指令文件，也是跨工具事实标准注入点。

## 目标 / 非目标 / 反目标

**目标**
- 任何 harness 开局自动加载记忆 index，并知道读写 notes、按需 dreaming。
- 全部记忆是可移植 repo markdown，不依赖 Qoder 专属存储。
- 用最小骨架跑通完整回路：note → dream → index/wiki。

**非目标**
- 不改造 / 不新造 harness。
- 不替换 Qoder 的用户/项目 auto-memory 或 repowiki（共存，只是不当可移植骨架）。
- 不做独立跑 LLM 循环的 dreaming 脚本/agent（那会滑向"新 harness"）。
- 不把 dreaming 做成 skill（耦合 harness 技能系统，违背可移植）；用 md runbook。
- 不一次性把 19 篇 specs 迁进新 wiki。

**反目标（即便"能跑"也算失败）**
- 记忆只在 Qoder 生效（违背可移植）。
- index 膨胀超过 ~200 行 / 25KB（文章教训：注入层必须小）。
- notes wholesale 复制 docs/ 而非蒸出要点。
- dreaming 不对照原始来源校验就信任旧笔记（文章：未校验的错误会被下游信任）。

## 约束

- 纯 docs + 指令文件改动，不动站点代码、不影响构建产物。
- 追加 AGENTS.md 段落，不破坏现有内容。
- markdown 风格与现有 docs/specs 一致。
- 可移植性依赖 harness 读 AGENTS.md（不读则手动把它指向 AGENTS.md / MEMORY.md）；
  **不加适配文件**（用户决定）。

## 考虑过的方案

- **A 复用 docs/ + 记忆索引（选定）**：新增 `docs/memory/{MEMORY.md,notes/,DREAM.md}`，
  wiki 直接用现有 docs/，AGENTS.md 做注入点。新增面最小、完全可移植、长在现有约定上。
- B 独立 `memory/` 子系统：1:1 照搬四层，干净但 wiki 与 docs/ 重复、新增面大、要迁移。
- C 极简 `CONTEXT.md` + `MEMORY.md`：最省，但装不下 notes/journal/dreaming 完整回路，实践偏薄。

选 A 因为它复用既有 wiki、新增面最小，且注入点 AGENTS.md 天然跨 harness。

## 设计（A 的具体形态）

**四层 + dreaming 的可移植映射**

| 文章层 | repo 实现 |
| - | - |
| Transcripts 原始记录 | git 历史 + `docs/superpowers/specs/`·`plans/`（耐久的设计/实现记录）。harness 会话日志留在各自侧，不依赖。journal 暂不建，不够再加。 |
| Memory Notes 要点笔记 | `docs/memory/notes/*.md`，小而 dated，一条一个观察（决策/坑/已验证规则/偏好）。 |
| Representations / Wiki | 现有 `docs/adr`·`guides`·`components`·`specs`；某主题笔记长多了再由 dreaming 蒸成 `docs/memory/wiki/<topic>.md`。 |
| Injected Context | `docs/memory/MEMORY.md`，短索引（<200 行），开局经 AGENTS.md 指令加载，链向 notes + wiki。 |
| Dreaming | `docs/memory/DREAM.md` runbook（详见下）。 |

**注入机制**
- AGENTS.md 加 "Project memory" 段：开局读 `docs/memory/MEMORY.md`；学到耐久要点就写
  `docs/memory/notes/`；整理就照 `docs/memory/DREAM.md` 跑。
- 不加适配文件。注入依赖 harness 读 AGENTS.md；若某 harness 不读，手动把它指向
  AGENTS.md / MEMORY.md。

**dreaming 形态与触发（我的 call）**
- 用 **md runbook**（`docs/memory/DREAM.md`）作唯一可移植载体，**不做 skill**。
  理由：md 在任何能读文件的 harness 都生效；skill 耦合具体 harness 的技能系统
  （位置/格式/调用方式各异），违背可移植。日后若想要 Qoder 里 `/dream` 手感，可加
  薄 skill 指向同一 md，但 md 始终是 source of truth。
- DREAM.md 含两部分：
  1. **dreaming 过程**（每次 run 做什么）：读 notes/specs（自上次 run 起）→对照
     git/文件纠错→更新/链接 wiki→把关键条提升进 MEMORY.md→保持索引 <200 行→记录
     本次 run 时间戳。
  2. **调度安装指南**：在每个 harness 建一个定时任务，prompt 固定为「读
     `docs/memory/DREAM.md` 并执行 dreaming 过程」，周期按需（如每周日）。Qoder 用
     `qoder_cron`，其他 harness 用各自定时任务功能。任务只是薄触发器，逻辑始终在
     repo md 里、随版本控制走；换 harness 重建任务即可。
- 起步手动跑通；之后按安装指南在 Qoder（及用到的其他 harness）注册定时任务。

**我的 call（待你在批准时核对）**
- 位置 `docs/memory/`；notes 文件名 `YYYY-MM-DD-<slug>.md`（kebab-case）。
- journal.md / wiki/ 暂不建，按需再加。
- dreaming 用 md 不用 skill；定时任务 prompt 指向 repo DREAM.md。

## 起步骨架（walking skeleton）

1. 建 `docs/memory/MEMORY.md`（播种短索引）+ `docs/memory/notes/`，从现有 specs/guides
   蒸 2-3 条真笔记（如 layout-switch 决策、i18n 孪生文件规则、deploy 强推机制）。
2. AGENTS.md 追加 "Project memory" 段。
3. 写 `docs/memory/DREAM.md` runbook（dreaming 过程 + 跨 harness 定时任务安装指南）。
4. 手动跑一次 dream：把几篇 specs 蒸进 MEMORY.md + 链 wiki，验证回路转得起来。
5. （可选）按安装指南在 Qoder 注册周日定时任务，prompt 指向 DREAM.md。

跑通后再长大（journal、wiki 主题页、更多 harness 的定时任务、导出 repowiki 内容）。

## 留给实现者 / 后续

- 是否导出 repowiki 现有内容进 docs/（先查它有没有内容）。
- notes 精确字段约定（日期/来源链接/置信度），实现时定。
- 自动 dreaming 是否 auto-commit 改动：起步手动留给人审；定时任务阶段再定。

## 验证

- 在 Qoder（本 harness）开局确认 AGENTS.md "Project memory" 段被加载、MEMORY.md 被读。
- 跑一次 dream：index 更新且保持 <200 行、笔记对照 specs 校验过。
- 定时任务 prompt 指向 repo DREAM.md，逻辑随 repo 版本控制（注册后验证一次触发）。
- `bun run format:check`；docs-only 改动不影响 `bun run build`。