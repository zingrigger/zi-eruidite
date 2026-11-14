# mdxcn endpoint 与 chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在一篇纯 Markdown 博客文章中试用 mdxcn 的 endpoint 与 chat 内容模型，并用本站静态自定义元素呈现接近官网的视觉结构。

**Architecture:** 保留 mdxcn 的官方 MDX 示例作为文档源码，同时用 `<api-endpoint>`、`<api-chat>` 和 chat 子元素输出 SSR 静态 HTML。endpoint/chat 样式分别放在独立 CSS 文件，由 `Layout.astro` 全局导入；不引入 React、MDX、motion 或客户端脚本。

**Tech Stack:** Astro 7、Sätteri Markdown、原生 HTML 自定义元素命名、原生 CSS、Bash 3.2、Biome、npm。

**Spec:** `docs/superpowers/specs/2026-11-14-mdxcn-endpoint-design.md`

## Global Constraints

- 文章保持 `.md`，不引入 MDX、React 或新的运行时依赖。
- 样式使用本站原生 CSS、Utopia 变量和 Radix 色彩变量，不使用 Tailwind。
- 自定义元素必须先输出可读静态 HTML；本次不添加 JavaScript 激活逻辑。
- endpoint 与 chat 的结构必须在生产构建产物中保留。
- 作者引用必须通过 `src/content/authors/openai.md` 的内容 schema 校验。
- 使用 npm 工作流验证：`npm run format:check`、`npm run build`。

## Review Focus

1. **Markdown 原始 HTML 保留**：Sätteri 不应把 `<api-endpoint>` / `<api-chat>` 当作普通文本或丢弃子节点——由构建产物结构检查覆盖 Task 4。
2. **Chat speaker 合并**：连续 agent 消息必须共用一个 speaker，不应为每条消息重复渲染 agent——由文章结构检查和构建产物检查覆盖 Task 3/4。
3. **官网视觉层级**：外层 stage、内层虚线 frame、标题压边框和三列对齐必须分层实现——由 CSS 结构审阅覆盖 Task 3。
4. **窄屏可读性**：长 API 路径和对话内容不能撑破文章列——由 endpoint/chat 的 media query 和 CSS 审阅覆盖 Task 2/3。
5. **全站回归**：全局 CSS 导入不能破坏既有页面，内容 schema 与静态路由必须继续生成——由 `npm run build` 覆盖 Task 4。

---

### Task 1: 固定离线 wiring 检查

**Files:**
- Modify: `scripts/tests/endpoint-check.sh`
- Test: `scripts/tests/endpoint-check.sh`

**Interfaces:**
- Consumes: article path、Layout path、endpoint/chat CSS paths。
- Produces: 失败时返回非 0，成功时输出 `endpoint component wiring: ok`。

- [x] **Step 1: 写失败检查**

  让脚本断言文章包含 `<api-endpoint>`、`<api-chat>`、`<chat-frame>`、`<chat-messages>`，Layout 导入两份 CSS，且两份 CSS 存在并包含 `--chat-stage`。

- [x] **Step 2: 运行确认当前实现失败**

  Run: `bash scripts/tests/endpoint-check.sh`

  Expected: 在 chat frame 结构和新 stage 样式尚未加入时返回非 0。

- [x] **Step 3: 实现后重新运行**

  Run: `bash scripts/tests/endpoint-check.sh`

  Expected: 输出 `endpoint component wiring: ok`。

### Task 2: endpoint 静态展示

**Files:**
- Create: `src/styles/endpoint.css`
- Modify: `src/layouts/Layout.astro`
- Modify: `src/content/blog/mdxcn-endpoint/index.md`

**Interfaces:**
- Consumes: mdxcn endpoint 的 method/path、说明、参数、request、response 内容模型。
- Produces: 静态 `<api-endpoint>` 结构和全局 endpoint 样式。

- [x] **Step 1: 在文章中写入 endpoint MDX 源码示例**

  保留 `<Endpoint>`、参数表、request 和 JSON response，作为官方组件写法的说明，不让它承担本站运行时渲染职责。

- [x] **Step 2: 写入静态 endpoint HTML**

  使用 `<api-route>`、`<api-params>`、`<api-blocks>` 和 `<api-block>` 表达同一内容，确保无 MDX 时仍能被浏览器直接解析。

- [x] **Step 3: 添加 endpoint CSS 并接入 Layout**

  提供边框、参数三列布局、request/response 区块，以及窄屏下参数转为纵向布局。

- [x] **Step 4: 运行 wiring 检查**

  Run: `bash scripts/tests/endpoint-check.sh`

  Expected: endpoint 部分通过。

### Task 3: chat 官网结构适配

**Files:**
- Create: `src/styles/chat.css`
- Modify: `src/layouts/Layout.astro`
- Modify: `src/content/blog/mdxcn-endpoint/index.md`

**Interfaces:**
- Consumes: mdxcn chat 的 `you` / `agent` turns、旁注和 session 标题模型。
- Produces: `<api-chat><chat-frame>...` 静态结构；连续 agent 消息共用一个 `<chat-turn>`。

- [x] **Step 1: 写入 Chat MDX 源码示例**

  使用官方示例的 `you: ...` / `agent: ...` 轮次，包含一条斜体旁注。

- [x] **Step 2: 组织静态 chat 结构**

  外层使用 `<api-chat>`，内层使用 `<chat-frame>`；每个 speaker 使用一个 `<chat-turn>`，同一 speaker 的多条消息放在 `<chat-messages>` 中。

- [x] **Step 3: 添加官网视觉层级**

  `api-chat` 提供浅色 stage；`chat-frame` 提供虚线边框和内边距；header 绝对定位到上边框中间；turn 使用提示符、speaker、message 三列；窄屏收窄列宽和内边距。

- [x] **Step 4: 运行 wiring 检查**

  Run: `bash scripts/tests/endpoint-check.sh`

  Expected: endpoint/chat wiring 输出 ok。

### Task 4: 全量验证与交付记录

**Files:**
- Modify: `docs/superpowers/specs/2026-11-14-mdxcn-endpoint-design.md`
- Create: `docs/superpowers/plans/2026-11-14-mdxcn-endpoint-chat.md`

**Interfaces:**
- Consumes: Tasks 1–3 的文件、构建产物和验证命令。
- Produces: 可供后续维护者理解决策、结构和验证边界的 spec/plan 文档。

- [x] **Step 1: 运行格式与差异检查**

  Run: `git diff --check && npm run format:check`

  Expected: 无 diff 空白错误，Biome 报告无格式修正。

- [x] **Step 2: 运行生产构建**

  Run: `npm run build`

  Expected: 构建成功，文章和作者路由生成，内容 schema 校验通过。

- [x] **Step 3: 检查构建产物**

  Run: `rg -q '<api-chat' dist/blog/mdxcn-endpoint/index.html`，并在 `dist/_astro/*.css` 中检索 `api-chat`。

  Expected: HTML 包含静态 chat 结构，构建 CSS 包含 chat 样式。

- [x] **Step 4: 更新 spec 与 plan**

  记录最终取舍：官网 React/MDX 组件未直接安装；本站通过静态自主定制元素复现内容模型和视觉层级；本次不实现交互 tabs、复制按钮或真实聊天。
