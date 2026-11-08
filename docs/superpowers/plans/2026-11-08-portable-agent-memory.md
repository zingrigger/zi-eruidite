# 可移植 Agent 记忆系统（起步骨架）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 blog repo 里用纯 markdown + AGENTS.md 落地文章四层记忆 + dreaming，跨 harness 可移植。

**Architecture:** 新增 `docs/memory/{MEMORY.md,notes/,DREAM.md}`；wiki 复用现有 docs/；AGENTS.md 追加注入段；dreaming 是 md runbook（含跨 harness 定时任务安装指南），不做 skill、不造 harness。

**Tech Stack:** Markdown、AGENTS.md 约定、Biome（format:check）、Bun/npm、qoder_cron（可选定时任务）。无应用代码、无框架。

**Spec:** `docs/superpowers/specs/2026-11-08-portable-agent-memory-design.md`

## Global Constraints

- 不改造 / 不新造 harness；纯 repo markdown + AGENTS.md。
- 全部记忆是可移植 repo markdown；记忆文件**不得**引用 `~/.qoder-cn/` 绝对路径或把 repowiki 当骨架。
- `MEMORY.md` 注入层 **< 200 行 / 25KB**。
- dreaming 用 md runbook，**不做 skill**；定时任务 prompt 固定指向 repo `DREAM.md`。
- **不加适配文件**（CLAUDE.md/QODER.md）；注入只靠 AGENTS.md。
- notes 文件名 `YYYY-MM-DD-<slug>.md`（kebab-case）；位置 `docs/memory/`。
- 不动站点代码；docs-only。markdown 风格与现有 docs/specs 一致。
- **Commit 步骤需用户显式批准后才执行**（session 规则）；未批准则留改动给人审。
- 包管理器按用户偏好；验证命令以 `bun` 为例，`npm run …` 等价。

## Review Focus

1. **索引膨胀 > 200 行 / 25KB** → 注入层过大（文章教训）。Task 1 验证 `wc`，Task 2 DREAM 含 size guard。
2. **dreaming 不校验旧笔记** → 下游信任错误。Task 2 DREAM 含 reconcile-against-source 步骤。
3. **notes wholesale 复制 docs** → 无蒸馏价值。Task 1 note 结构（短、一条观察、source link）。
4. **可移植性破坏**：记忆文件引用 Qoder 专属路径 / repowiki。Task 1/2/3 grep 验证无依赖。
5. **定时任务 prompt 漂移**（逻辑抄进 prompt 而非指向 md）→ 不随版本控制。Task 5 cron prompt = 固定指针字符串。

---

## File Structure

- Create `docs/memory/MEMORY.md` — 短索引（注入层）：Notes 指针、Wiki 指针（复用 docs/）、Consolidation 指针、Promoted key facts、`Last dream:` 行。
- Create `docs/memory/notes/2026-11-08-{layout-switch,i18n-twin-files,deploy-force-push}.md` — 3 条蒸馏要点。
- Create `docs/memory/DREAM.md` — Part 1 dreaming 过程 + Part 2 调度安装指南。
- Modify `AGENTS.md` — 追加 `## Project memory` 段（仅追加，不改现有内容）。
- (Optional) Qoder 定时任务（`qoder_cron`）— 薄触发器，prompt 指向 DREAM.md。

---

### Task 1: Seed memory（notes + MEMORY.md 索引）

**Files:**
- Create: `docs/memory/notes/2026-11-08-layout-switch.md`
- Create: `docs/memory/notes/2026-11-08-i18n-twin-files.md`
- Create: `docs/memory/notes/2026-11-08-deploy-force-push.md`
- Create: `docs/memory/MEMORY.md`

**Interfaces:**
- Produces: `docs/memory/MEMORY.md`（索引，< 200 行，含 `Last dream:` 行）；`docs/memory/notes/*.md`（3 条）。Task 2/3/4 按这些路径引用。

- [ ] **Step 1: 写 3 条 seed notes**

每条用此结构（< ~15 行，蒸馏非复制）：

```markdown
# <标题>
Date: 2026-11-08
Source: <相对链接到 spec/guide>
Type: decision | gotcha | verified-rule | preference

<1–3 句显著观察>
```

固定来源与要点（据此写，不要整段抄源文）：
- layout-switch — Source `docs/superpowers/specs/2026-10-07-layout-switch-design.md`；要点：`<html data-layout>` 是布局唯一信号（sidebar/topbar），两布局共用一份骨架，访客经切换按钮运行时切换（`localStorage.layout`）。
- i18n-twin-files — Source `docs/guides/i18n.md`；要点：英文 = 同目录 `.en.md` 孪生文件，blog loader 用自定义 `generateId` 保留 `.en`；未翻译有 badge/noindex/占位规则。
- deploy-force-push — Source `docs/guides/deployment.md`；要点：hexo 式部署 = build + 强推 `dist/` 到 `DEPLOY_REPO`/`DEPLOY_BRANCH`；`CNAME` 必须放 `public/` 源码（全量覆盖会清掉 GitHub 生成的 CNAME）。

- [ ] **Step 2: 验证 notes**

Run: `wc -l docs/memory/notes/*.md`
Expected: 每条 < ~15 行。用 Grep 确认每条含 `Source:` 链接且链接目标存在；无 `~/.qoder-cn` / repowiki 引用。

- [ ] **Step 3: 写 MEMORY.md 索引**

固定结构（< 200 行）：

```markdown
# Project Memory Index

注入层，开局读。保持 < 200 行 / 25KB。

## Notes
- [layout-switch](notes/2026-11-08-layout-switch.md) — <一行摘要>
- [i18n-twin-files](notes/2026-11-08-i18n-twin-files.md) — <一行摘要>
- [deploy-force-push](notes/2026-11-08-deploy-force-push.md) — <一行摘要>

## Wiki（结构化知识，复用 docs/）
- `docs/adr/` — 架构决策
- `docs/guides/` — how-to
- `docs/components/` — 组件用法
- `docs/superpowers/specs/` — 设计文档

## Consolidation
整理 / 纠错 / 提升记忆见 [DREAM.md](DREAM.md)。

## Promoted key facts
- <从 3 条 notes 蒸出的耐久事实，各带 source 链接>

Last dream: 2026-11-08
```

- [ ] **Step 4: 验证索引**

Run: `wc -l docs/memory/MEMORY.md` → Expected < 200。
用 Grep 确认无 `~/.qoder-cn` / repowiki 引用；Notes/Wiki/DREAM 链接路径存在（DREAM.md 下个 Task 建，此处仅确认相对路径写法正确）。

- [ ] **Step 5: Commit（需用户批准）**

```bash
git add docs/memory/notes docs/memory/MEMORY.md
git commit -m "feat(memory): seed portable project memory notes and index"
```

---

### Task 2: DREAM.md runbook

**Files:**
- Create: `docs/memory/DREAM.md`

**Interfaces:**
- Consumes: `docs/memory/notes/`、`docs/memory/MEMORY.md`（Task 1）。
- Produces: dreaming 过程；固定 cron prompt 字符串（Task 5 用）：`Read docs/memory/DREAM.md and execute the dreaming procedure (Part 1).`

- [ ] **Step 1: 写 Part 1 — dreaming 过程**

固定步骤（顺序不可省，尤其 2 与 5）：
1. 读 `MEMORY.md` 的 `Last dream:` 行；用 `git log --since=<last dream>` + `docs/memory/notes/` 找出此后新增/变更的 notes 与 specs。
2. **对照来源校验**每条 note（git/文件）：修正错误或标记存疑——不盲信旧笔记。
3. 更新/链接 wiki（现有 `docs/adr`·`guides`·`components`·`specs`）；某主题笔记长多了才蒸成 `docs/memory/wiki/<topic>.md`。
4. 把关键耐久事实**提升**进 `MEMORY.md` 的 Promoted key facts（带 source）。
5. **尺寸守卫**：`MEMORY.md` 保持 < 200 行 / 25KB；超了就把次要条下沉回 notes/wiki。
6. 更新 `MEMORY.md` 底部 `Last dream: <今天>`。

- [ ] **Step 2: 写 Part 2 — 调度安装指南**

固定内容：
- 定时任务 prompt **必须**是此字符串（逻辑留在 repo，勿抄进 prompt）：
  `Read docs/memory/DREAM.md and execute the dreaming procedure (Part 1).`
- Qoder：用 `qoder_cron` 建每周任务（如周日），prompt 同上。
- 其他 harness：用各自定时任务功能，prompt 同上。
- 任务只是薄触发器；逻辑随 repo 版本控制，换 harness 重建任务即可。

- [ ] **Step 3: 验证 runbook**

用 Grep 确认 DREAM.md 含：reconcile/校验步骤、`200` 尺寸守卫、固定 prompt 字符串。
确认过程逻辑不依赖 `~/.qoder-cn` 绝对路径（`qoder_cron` 仅作为 Part 2 一个 harness 示例出现，可接受）。

- [ ] **Step 4: Commit（需用户批准）**

```bash
git add docs/memory/DREAM.md
git commit -m "feat(memory): add dreaming runbook and cross-harness scheduling guide"
```

---

### Task 3: AGENTS.md 注入段

**Files:**
- Modify: `AGENTS.md`（末尾追加，不改现有内容）

**Interfaces:**
- Consumes: `docs/memory/MEMORY.md`、`notes/`、`DREAM.md`（Task 1/2）。

- [ ] **Step 1: 追加 `## Project memory` 段**

固定文案（spec 固定的注入 copy）：

```markdown
## Project memory

本 repo 自带可移植记忆（跨 harness）。开局读 `docs/memory/MEMORY.md`（注入层索引，
保持短）。学到耐久、显著的要点（决策/坑/已验证规则/偏好）就写一条
`docs/memory/notes/YYYY-MM-DD-<slug>.md`（蒸馏，非复制）。要整理/纠错/提升记忆，
照 `docs/memory/DREAM.md` 跑（可手动，也可由定时任务触发）。
```

- [ ] **Step 2: 验证追加**

Run: `git diff AGENTS.md` → Expected 仅末尾追加，现有内容无改动。
用 Grep 确认含 `Project memory`；引用的 3 个路径存在。

- [ ] **Step 3: Commit（需用户批准）**

```bash
git add AGENTS.md
git commit -m "feat(memory): wire project memory injection into AGENTS.md"
```

---

### Task 4: 跑通回路（手动 dream pass）

**Files:**
- Modify: `docs/memory/MEMORY.md`（按 DREAM.md 提升新事实、更新 Last dream）

**Interfaces:**
- Consumes: `docs/memory/DREAM.md` Part 1（Task 2）。

- [ ] **Step 1: 手动执行 DREAM.md Part 1 一次**

选 2–3 篇 specs（如 `2026-10-17-board-collection-design.md`、`2026-10-21-lenticular-card-design.md`），
对照来源校验，蒸 1–2 条新耐久事实进 MEMORY.md 的 Promoted key facts（带 source），更新 `Last dream:`。

- [ ] **Step 2: 验证回路**

Run: `wc -l docs/memory/MEMORY.md` → Expected < 200。
确认新事实带 source 链接、无未校验断言。
Run: `bun run format:check` → Expected PASS（docs-only 不影响 build）。

- [ ] **Step 3: Commit（需用户批准）**

```bash
git add docs/memory/MEMORY.md
git commit -m "chore(memory): run first dream pass to verify consolidation loop"
```

---

### Task 5（可选）: 注册 Qoder 周日定时任务

**Files:** 无文件改动（`qoder_cron` 动作）。

**Interfaces:**
- Consumes: DREAM.md Part 2 固定 prompt 字符串（Task 2）。

- [ ] **Step 1: 先与用户确认**（创建定时任务是 side-effecting 动作）

确认周期（建议每周日，具体时刻用户定）与 prompt = 固定字符串。

- [ ] **Step 2: 经 `qoder_cron` 创建**

用 mcp_get 查 `qoder_cron` schema 后创建；prompt 必须是：
`Read docs/memory/DREAM.md and execute the dreaming procedure (Part 1).`

- [ ] **Step 3: 验证**

列出定时任务，确认 prompt 指向 repo DREAM.md（非内联逻辑）；可选触发一次验证。

---

## Self-Review

- **Spec coverage:** 四层映射（Task 1 notes+index、wiki 复用 docs/、Task 2 dreaming）；注入（Task 3）；调度安装指南（Task 2 Part 2 + Task 5）；起步骨架 5 步全覆盖；反目标（尺寸守卫 Task 1/2、校验 Task 2、蒸馏 Task 1、可移植 grep Task 1/2/3）均有验证。
- **Type/路径一致:** `docs/memory/MEMORY.md`、`notes/YYYY-MM-DD-<slug>.md`、`DREAM.md`、固定 prompt 字符串在各 Task 一致。
- **Proportion:** docs-only 小特性，plan 以结构 + 固定字符串为主，未转录全文。