# 手机顶栏两行布局 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `<64rem` 的全局顶栏改成两行（品牌+操作 / 六个栏目），让条高与 `--bar-nav-height` 同源，修掉导航逐字断行、320px 操作区出屏和文章页 TOC 被压 40px。

**Architecture:** 只动 `SiteBar.astro` 的手机端 scoped CSS 与 `layout.css` 的条高 token。`site-bar` 在 `<64rem` 变两行 grid，`bar-inner` 变 `display: contents`：品牌自动落第一行第一列，`bar-actions` 显式落第一行第二列，`nav` 跨两列落第二行。`≥64rem` 的 sidebar / topbar 完全不动；无 JS、无新组件。

**Tech Stack:** Astro scoped `<style>`、原生 CSS grid、现有 CSS 变量；无框架、无新依赖。

**Spec:** `docs/superpowers/specs/2026-11-04-mobile-header-design.md`

## Global Constraints

- 只改 `<64rem`；`≥64rem` 的 sidebar / topbar 像素级不变。
- 不新增 JS、组件或依赖；导航文案继续走 `t(locale, key)`。
- 手机隐藏 `bar-brand eye-tracker`、`#layout-toggle`、`#fullwidth-toggle`；主题与语言切换保留。
- `--bar-nav-height` 是条高的唯一来源；实际条高与 token 误差 ≤1px；TOC 的 `top` 与 `scroll-padding-block-start` 继续读它。
- 六个栏目单行、不换行；`font-size: var(--step--1)`；触控行高 44px。
- 设计系统最小视口 328px；验证 320 / 328 / 360 / 390 / 430 × zh / en × sidebar / topbar。
- 不自动提交 Git（系统约束）；完成后由用户决定。
- 只格式化改动的文件：仓库级 `npm run format` 会扫到 vendored `.agents/skills`。

## Review Focus

- **英文 320px**：六项只剩约 7px 间距，字体回退或字号变化会把导航顶出视口；测 `/en/` 的 `scrollWidth`。
- **文章页 TOC**：条高或边框算术错 1px 就会让吸顶 TOC 钻进栏下；测 `/blog/v1-posts` 滚动后的 `toc.top`。
- **非分区页**：`/404`、`/figures/*` 的顶层面包屑会变成第 7 项；测 6 项且 `[data-crumb]` 不渲染。
- **topbar 手机**：`page-nav` 为 `display: contents` 时共享 grid 仍要吸顶、不重新露出眼睛；测 `localStorage.layout=topbar`。
- **桌面泄漏**：新 `@media` 若选择器权重不够会波及 `≥64rem`；测 1024 / 1440 两种布局的 `site-bar` 计算样式与截图。

---

### Task 1: 手机两行顶栏

**Files:**
- Modify: `src/styles/layout.css`（`<64rem` 的 `--bar-nav-height`）
- Modify: `src/components/SiteBar.astro`（`<style>` 末尾新增手机端块）
- Test: dev server + playwright-cli 测量矩阵与截图（项目对可视样式约定人工核验；不新增测试文件）

**Interfaces:**
- Consumes: `site-bar` / `bar-inner` / `bar-brand` / `bar-actions` / `nav > ul` 现有 DOM；`--step--1`、`--space-3xs`、`--border`；`--bar-nav-height`。
- Produces: `<64rem` 的两行 `site-bar` grid；`--bar-nav-height: 6rem`；隐藏 `#layout-toggle`、`#fullwidth-toggle`、`bar-brand eye-tracker`。

- [ ] **Step 1: 记录改动前的失败基线**

启动 dev server（若未运行：`npm run dev`），用 playwright skill 在 390×844 打开中文首页，记录：

- `site-bar` 高 90px；导航链接 16×48；`document.documentElement.scrollWidth` 无横向溢出；
- `/blog/v1-posts` 滚动 400 后 `page-toc` 的 `getBoundingClientRect().top` 为 50（条高 90）；
- 320×844 下 `bar-actions` 右缘 361 > 320，页面横向溢出。

Expected: 上述现状成立，证明问题存在。截图存 `output/playwright/`。

- [ ] **Step 2: 改条高 token**

`src/styles/layout.css` 的 `html` 内 `<64rem` 块：

```css
--bar-nav-height: 6rem;
```

只改这一行；`--bar-toc-height` 与 `scroll-padding-block-start` 的公式保持不动。

- [ ] **Step 3: 在 `src/components/SiteBar.astro` 的 `<style>` 末尾加入手机端块**

```css
/* ---------- 手机：品牌+操作一行，六个栏目一行 ---------- */
@media (width < 64rem) {
  /* 两行高度由 --bar-nav-height 统一约束；1fr 吃掉底边边框后的剩余高度 */
  :root[data-layout] site-bar {
    display: grid;
    grid-template-columns: 1fr auto;
    grid-template-rows: 1fr 2.75rem;
    align-items: center;
    gap: 0;
    block-size: var(--bar-nav-height);
    padding-block: 0;
  }

  /* 让品牌、导航、操作成为同一网格的子项（sidebar 的 bar-brand 本就是 contents） */
  :root[data-layout] bar-inner {
    display: contents;
  }

  /* 触屏没有指针；布局/全宽切换在手机上无效或只剩换皮 */
  :root[data-layout] bar-brand eye-tracker,
  :root[data-layout] #layout-toggle,
  :root[data-layout] #fullwidth-toggle {
    display: none;
  }

  /* 导航跨两列落第二行；品牌自动落第一行第一列，操作显式落第一行第二列 */
  :root[data-layout] site-bar nav {
    position: relative;
    grid-column: 1 / -1;
    grid-row: 2;
    align-self: stretch;
    min-width: 0;
  }

  /* 两行之间的极淡虚线；伪元素不占行高 */
  :root[data-layout] site-bar nav::before {
    content: "";
    position: absolute;
    inset-block-start: 0;
    inset-inline: 0;
    border-block-start: 1px dashed
      color-mix(in oklab, var(--border) 45%, transparent);
    pointer-events: none;
  }

  :root[data-layout] site-bar nav > ul {
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    gap: 0;
    block-size: 100%;
    margin: 0;
  }

  :root[data-layout] site-bar nav > ul > li {
    display: flex;
    align-items: center;
    block-size: 100%;
  }

  :root[data-layout] site-bar nav > ul > li > a {
    display: inline-flex;
    align-items: center;
    block-size: 100%;
    font-size: var(--step--1);
    line-height: 1;
    white-space: nowrap;
    color: var(--muted-foreground);
  }

  :root[data-layout] site-bar nav > ul > li > a[aria-current="page"] {
    color: var(--foreground);
  }

  /* 手机固定六个栏目：顶层/子级面包屑都不进导航 */
  :root[data-layout] site-bar nav [data-crumb],
  :root[data-layout] site-bar nav ul ul {
    display: none;
  }

  :root[data-layout] site-bar bar-actions {
    grid-column: 2;
    grid-row: 1;
    justify-self: end;
    align-self: center;
    margin-inline: 0 -0.5rem;
    gap: var(--space-3xs);
  }
}
```

Notes for the implementer:
- 这段必须放在 `SiteBar.astro` 现有 `<style>` 的最后：它用 `:root[data-layout]`（0,2,1）覆盖两个布局的移动端声明，靠源顺序取胜。
- 不要给品牌显式 `grid-column`：sidebar 的 `bar-brand` 是 `display: contents`，显式放置会落到错误元素上；让品牌自动占据第一行第一列。
- 第一行由 `1fr` 吃掉「96px − 44px − 底边边框」的剩余（约 50–51px）；不要写死 52px，否则整条会变成 98px。
- 不改 `bar-brand a span` 的现有显示规则（sidebar `≥26rem` 显示站名，topbar 始终隐藏）；不改两个布局的底边边框（sidebar 2px 实线渐变 / topbar 1px 虚线）。
- 不引入 `overflow-x: clip` 或横向滚动；320px 的英文已核算能放下。

- [ ] **Step 4: 格式化与构建前检查**

Run: `npm run format:check`
Expected: PASS。若失败，只格式化两个改动文件：`npx biome format --write src/components/SiteBar.astro src/styles/layout.css`，再跑一次。

- [ ] **Step 5: 390px 中文 sidebar 验收**

用 playwright skill 在 390×844 打开 `/`，测量：

```js
(() => {
  const bar = document.querySelector("site-bar").getBoundingClientRect();
  const links = [...document.querySelectorAll("site-bar nav > ul > li > a")];
  return {
    barH: Math.round(bar.height),
    count: links.length,
    heights: links.map((a) => Math.round(a.getBoundingClientRect().height)),
    widths: links.map((a) => Math.round(a.getBoundingClientRect().width)),
    overflow:
      document.documentElement.scrollWidth >
      document.documentElement.clientWidth,
  };
})()
```

Expected: `barH: 96`，`count: 6`，每个 `heights` 为 44，`widths` 约 28–60，`overflow: false`。亮/暗主题各截一张图。

- [ ] **Step 6: 断点 × 语言 × 布局矩阵**

对 320 / 328 / 360 / 390 / 430 × `/` 与 `/en/` × sidebar / topbar（topbar 用 `localStorage.layout="topbar"` 后 reload；验完清回）重复 Step 5 的测量，并额外检查：

- `document.documentElement.scrollWidth <= clientWidth`；
- 六个链接都在一行（每个 `heights` 为 44，没有逐字堆叠）；
- `bar-actions` 最右缘 ≤ `innerWidth`（320px 下尤其要看）；
- 第二行六个标签都可见（英文 `Moments` 最宽，约 59px）。

Expected: 全部通过。至少保存 320 en sidebar、390 zh topbar 两张图。

- [ ] **Step 7: 文章页 TOC 对齐**

在 390 sidebar 打开 `/blog/v1-posts`，`scrollTo(0, 400)`，测量：

```js
(() => {
  const bar = document.querySelector("site-bar").getBoundingClientRect();
  const toc = document.querySelector("page-toc").getBoundingClientRect();
  return { bar: Math.round(bar.height), tocTop: Math.round(toc.top) };
})()
```

Expected: `bar: 96`，`tocTop: 96`（±1）。截图。

- [ ] **Step 8: 非分区页与 topbar 文章页**

- 390 sidebar 打开 `/404`：导航恰好 6 项，顶层面包屑 `[data-crumb]` 不显示，无横向溢出。
- 390 topbar 打开任意文章页（如 `/blog/v1-posts`）：`#fullwidth-toggle` 不显示，`bar-actions` 只剩主题（若有英文孪生再加 EN），第一行不换行。

Expected: 两条都成立。

- [ ] **Step 9: 桌面零回归**

在 1024 与 1440 宽、两种布局下：

```js
getComputedStyle(document.querySelector("site-bar")).display
```

Expected: `flex`（不是 `grid`），sidebar 仍是固定侧栏、topbar 仍是单行顶栏；与改动前截图一致。

- [ ] **Step 10: 既有检查**

Run:
```bash
npm run build
bash scripts/tests/i18n-check.sh
bash scripts/tests/home-guide-topbar-check.sh
```

Expected: 全部通过（build 成功、i18n 断言全 PASS、home-guide 断言全 PASS）。

- [ ] **Step 11: 汇报，等待提交决定**

汇报改动文件、测量矩阵结果与截图路径；不自动 commit。
