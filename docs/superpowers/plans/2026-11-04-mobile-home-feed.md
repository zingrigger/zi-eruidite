# 手机首页文章优先 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `<64rem` 首页 hero 收成紧凑开放 masthead（只留第一段），并把 `<40rem` 的 BlogCard 改成左侧 88px 缩略图行，让手机第一屏尽快看到最新文章。

**Architecture:** Hero 改动落在全局 `home.css` 的 `<64rem` 媒体块，同时把 topbar 专属的 `hero-card` / `latest-section` 横向内边距收进 `≥64rem`（它们只为桌面参考线服务）；BlogCard 只改它自己的 `<40rem>` 块。`≥64rem` 的 sidebar 卡片 hero、topbar 左文右图、BlogCard 桌面行全部不动。

**Tech Stack:** Astro 页面/组件 scoped `<style>`、全局 `home.css`、原生 CSS 媒体查询；无框架、无新依赖。

**Spec:** `docs/superpowers/specs/2026-11-04-mobile-home-feed-design.md`

## Global Constraints

- Hero 只改 `<64rem`；BlogCard 只改 `<40rem>`；`≥64rem` 与 `≥40rem` 桌面视觉不变。
- Hero 去掉卡片、居中、标题 `--step-2` 斜体 accent、只保留第一段；第二段手机隐藏。
- 列表缩略图 `5.5rem`、标题 `--step-1`、摘要 `--step--1` + 两行截断；无图条目整行文字。
- 不改图片资源、文章内容、数据字段或新增 `tagline`。
- BlogCard 是共享组件：`/blog`、`/tags/<tag>`、`/authors/<id>` 的 `<40rem` 列表会同步变化。
- 不自动提交 Git（系统约束）；只格式化改动文件。
- 仓库级 `npm run format:check` 改动前已有 vendored 文件错误；`home-guide-topbar-check.sh` 的 hero 断言是既有陈旧失败。

## Review Focus

- **topbar/sidebar 真正合并**：topbar 的 `hero-card, latest-section` 横向内边距只为桌面参考线；手机若保留 24px，hero 列表会比 sidebar 多缩进 24px。必须在 `<64rem` 归零、`≥64rem` 保留。
- **320px 英文第一屏**：英文第一段最长，加上 3 条缩略图行后第三条是否仍能看到；hero 不许再撑成卡片高度。
- **无图首条**：当前最新一篇没有封面；它必须是整行文字、标题与其它行不对齐是预期 lead，摘要两行截断不能把标题挤掉。
- **640 断点交叉**：hero 仍是 `<64rem` 紧凑版，BlogCard 已回到 `≥40rem` 的 14rem 左图行；不能出现手机行或卡片 hero。
- **共享列表面**：`/blog`、`/tags/<tag>`、`/authors/<id>` 的 `<40rem` 行、页头、图片链接 `aria-hidden` 与标题焦点都不能回归。

---

### Task 1: 手机紧凑 masthead

**Files:**
- Modify: `src/styles/home.css`（`hero-card` 基础规则之后新增 `<64rem>` 块）
- Modify: `src/pages/index.astro`（把 topbar 的 `hero-card, latest-section` 内边距收进 `≥64rem`）
- Modify: `src/pages/en/index.astro`（同上）
- Test: dev server + playwright-cli 测量/截图（人工核验，不新增测试文件）

**Interfaces:**
- Consumes: existing `hero-card` / `hero-text` / `hero-avatar` / `hero-figure`；`--step-2`、`--step--1`、`--space-m`、`--measure`；`data-layout`。
- Produces: `<64rem` 的统一 masthead 样式；topbar 内边距只在 `≥64rem` 生效。

- [ ] **Step 1: 记录改动前基线**

在 390×844 与 320×844 打开 `/`，分别在 sidebar / topbar 下测量：

```js
(() => {
  const R = (s) => {
    const e = document.querySelector(s);
    if (!e) return null;
    const r = e.getBoundingClientRect();
    return [Math.round(r.x), Math.round(r.top + scrollY), Math.round(r.width), Math.round(r.height)];
  };
  const cs = getComputedStyle(document.querySelector("hero-card"));
  return JSON.stringify({
    lay: document.documentElement.dataset.layout,
    w: innerWidth,
    hero: R("hero-card"),
    h1: getComputedStyle(document.querySelector("hero-card h1")).fontSize,
    pVisible: [...document.querySelectorAll("hero-card p")].filter((p) => getComputedStyle(p).display !== "none").length,
    card: [cs.backgroundColor, cs.borderTopWidth, cs.padding],
    latest: R("latest-section"),
    x: Math.round(document.querySelector("hero-card h1").getBoundingClientRect().x),
  });
})()
```

Expected: sidebar 390 hero 385、h1 step-3、两段 p、卡片有背景/边框/内边距；topbar 390 hero 约 284、两段 p、h1 x 约 40（24px 内边距）。320 sidebar hero 484。截图存 `output/playwright/`。

- [ ] **Step 2: 加手机 hero 样式**

在 `src/styles/home.css` 的 `hero-card` 块之后、`latest-section` 之前新增：

```css
@media (width < 64rem) {
  :root[data-layout] hero-card {
    background: none;
    border: 0;
    border-radius: 0;
    padding: 0;
    margin-block-end: var(--space-m);
    text-align: center;
  }

  :root[data-layout] hero-card h1 {
    font-size: var(--step-2);
    font-style: italic;
    letter-spacing: -0.02em;
    line-height: 1.25;
    color: var(--accent);
  }

  :root[data-layout] hero-card p {
    font-size: var(--step--1);
    line-height: 1.6;
    max-width: var(--measure);
    margin-inline: auto;
  }

  :root[data-layout] hero-card hero-text p:nth-of-type(n + 2) {
    display: none;
  }

  :root[data-layout] hero-card hero-avatar {
    margin-inline: auto;
  }
}
```

Notes:
- `:root[data-layout]` 是本文件里能覆盖 sidebar 基础规则的最低前缀；topbar 的 scoped 规则（斜体/accent/居中）与这里同值，不冲突。
- 第二段只是 `display:none`，DOM 与桌面内容不变。

- [ ] **Step 3: 把 topbar 内边距收进桌面**

在 `src/pages/index.astro` 找到：

```css
  /* 内容区留白：文字/卡片从竖线内侧退让，不贴参考线（仅 topbar，无背景） */
  :root[data-layout="topbar"] hero-card,
  :root[data-layout="topbar"] latest-section {
    padding-inline: var(--space-m);
  }
```

把它移到下方已有的 `@media (width >= 64rem) { ... }` 块内（作为该块第一条规则），保持声明不变。`src/pages/en/index.astro` 做同样处理。

Expected: `<64rem` 的 topbar hero/list 横向内边距为 0，与 sidebar 对齐；`≥64rem` 的参考线内边距不变。

- [ ] **Step 4: 格式化与构建**

Run: `npx biome format src/styles/home.css src/pages/index.astro src/pages/en/index.astro`
Expected: PASS（必要时 `--write` 只改这三个文件）。
Run: `npm run build`
Expected: 构建成功。

- [ ] **Step 5: 390px 验收（两种布局）**

在 390×844 打开 `/`，分别验证 sidebar / topbar：

```js
(() => {
  const hero = document.querySelector("hero-card");
  const cs = getComputedStyle(hero);
  const h1 = getComputedStyle(document.querySelector("hero-card h1"));
  const ps = [...document.querySelectorAll("hero-card p")];
  const r = hero.getBoundingClientRect();
  return JSON.stringify({
    lay: document.documentElement.dataset.layout,
    heroH: Math.round(r.height),
    x: Math.round(r.x),
    cardBg: cs.backgroundColor,
    cardBorder: cs.borderTopWidth,
    cardPadTop: cs.paddingTop,
    h1Size: h1.fontSize,
    h1Style: h1.fontStyle,
    h1Color: h1.color,
    visibleP: ps.filter((p) => getComputedStyle(p).display !== "none").length,
    p2: getComputedStyle(ps[1]).display,
    latestTop: Math.round(document.querySelector("latest-section").getBoundingClientRect().top + scrollY),
  });
})()
```

Expected: 两种布局 heroH 约 130–150、x 一致（16）、背景透明（`rgba(0, 0, 0, 0)`）、无边框、padding-top 0、h1 约 20px 斜体 accent、可见 p = 1、第二段 `none`；latestTop sidebar 约 230–260、topbar 约 290–320（topbar 顶部多 32px）。截图各一张。

- [ ] **Step 6: 320 / 430 与英文**

重复 Step 5 在 320 与 430，并打开 `/en/` 390：英文第一段也可读、只显示一段、h1 不换行成三行、latestTop 仍在首屏前半。Expected: 通过；截图。

- [ ] **Step 7: 桌面零回归**

在 1024 与 1440、sidebar 与 topbar 下验证：

- sidebar：`hero-card` 仍是 `var(--muted)` 背景、1px 边框、space-l 内边距、h1 step-3 前景色、两段可见。
- topbar：hero 仍是左文右图 flex、`padding-inline` 24px、两段可见。

Expected: 与改动前一致；各截一张图。

---

### Task 2: 手机缩略图列表

**Files:**
- Modify: `src/components/BlogCard.astro`（`<40rem` 块）
- Test: dev server + playwright-cli 测量/截图（人工核验，不新增测试文件）

**Interfaces:**
- Consumes: existing `li` / `entry-info` / `entry-head` / `entry-meta` / `> a`；`--space-xs`、`--step-1`、`--step--1`。
- Produces: `<40rem` 的缩略图行；`≥40rem` 的 14rem 左图行不变。

- [ ] **Step 1: 记录改动前基线**

390 / 320 打开 `/` 与 `/blog`，测量：

```js
(() => {
  const lis = [...document.querySelectorAll("latest-section li, .post-list li, main ul li")];
  return JSON.stringify({
    w: innerWidth,
    rows: lis.slice(0, 3).map((li) => {
      const r = li.getBoundingClientRect();
      const img = li.querySelector("a > img");
      return {
        h: Math.round(r.height),
        imgW: img ? Math.round(img.getBoundingClientRect().width) : null,
        imgH: img ? Math.round(img.getBoundingClientRect().height) : null,
      };
    }),
  });
})()
```

Expected: 390 下 102 / 322 / 298，图 179；320 下 102 / 285 / 261，图 143；`<40rem` 是 column 堆叠。截图。

- [ ] **Step 2: 改 BlogCard 的 `<40rem>` 块**

把 `src/components/BlogCard.astro` 里 `li` 的 `<40rem>` 块：

```css
    @media (width < 40rem) {
      flex-direction: column;

      > a {
        inline-size: 100%;
        max-inline-size: 32rem;
      }
    }
```

替换为：

```css
    @media (width < 40rem) {
      flex-direction: row;
      gap: var(--space-xs);

      > a {
        inline-size: 5.5rem;
        max-inline-size: none;
      }

      entry-info {
        flex: 1;
        min-inline-size: 0;
      }

      entry-info p {
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
        font-size: var(--step--1);
        line-height: 1.5;
      }
    }
```

- [ ] **Step 3: 格式化与构建**

Run: `npx biome format src/components/BlogCard.astro`
Expected: PASS（必要时 `--write` 只改这个文件）。
Run: `npm run build`
Expected: 构建成功。

- [ ] **Step 4: 390px 验收首页**

打开 `/` 390，测量：

```js
(() => {
  const lis = [...document.querySelectorAll("latest-section li")];
  return JSON.stringify({
    rows: lis.map((li) => {
      const r = li.getBoundingClientRect();
      const a = li.querySelector(":scope > a");
      const img = li.querySelector("a > img");
      const title = li.querySelector("entry-head > a");
      const p = li.querySelector("entry-info p");
      const cs = getComputedStyle(p);
      return {
        h: Math.round(r.height),
        thumbW: img ? Math.round(img.getBoundingClientRect().width) : null,
        hasImageLink: !!a,
        titleX: Math.round(title.getBoundingClientRect().x),
        pClamp: cs.webkitLineClamp,
        pFont: cs.fontSize,
      };
    }),
    latestTop: Math.round(document.querySelector("latest-section").getBoundingClientRect().top + scrollY),
  });
})()
```

Expected: 首条无图、`titleX` 16；第二条/第三条 `thumbW` 约 88、`titleX` 约 116；有图条目约 110–150px、首条约 100px；`pClamp` 为 2，`pFont` 约 14px；首屏能看到 3 条（390）。截图亮/暗各一张。

- [ ] **Step 5: 320 / 430 与英文**

320 与 430 重复 Step 4；`/en/` 390 同样检查 3 条、缩略图、两行摘要。Expected: 320 第三条仍可见（贴底也可）；英文标题不溢出。

- [ ] **Step 6: 共享列表面**

390 打开 `/blog`、`/tags/site`、`/authors/enscribe`：

- 列表 `<40rem` 均为缩略图行；
- 页头（博客页头、标签页头、作者页头）不变；
- 图片链接仍 `aria-hidden="true"`、`tabindex="-1"`；标题链接正常聚焦；
- 无横向溢出。

Expected: 通过；各截一张图。

- [ ] **Step 7: 640 与桌面**

- 640：hero 仍是紧凑 masthead（`<64rem`），BlogCard 已是 `≥40rem` 的 14rem 左图行；无手机缩略图样式。
- 1024 / 1440：BlogCard 桌面行与改动前一致。

Expected: 通过；截图。

- [ ] **Step 8: 第一屏与既有检查**

在 320 / 390 / 430，zh/en，sidebar/topbar 截第一屏：

- hero 无卡片、一段；
- 最新文章 3 条可见（390 全部；320 第三条可能贴底）；
- 无横向溢出；页面高度比改动前明显缩短。

Run:
```bash
npm run build
bash scripts/tests/i18n-check.sh
```

Expected: build 成功；i18n exit 0 / 96 PASS。`home-guide-topbar-check.sh` 的 hero 陈旧断言仍是既有失败，与本改动无关。

- [ ] **Step 9: 汇报，等待提交决定**

汇报改动文件、第一屏截图、共享列表截图；不自动 commit。
