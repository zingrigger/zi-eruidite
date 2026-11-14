# 动态活动图手机横滑年历 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 `<40rem` 下活动图被压缩到 3px 格子、月份标签重叠的回归：恢复 10px 格子的横向滚动年历，默认定位到最近一次活跃日，并补齐 sticky 周几栏、右侧渐隐、滑动提示与键盘可访问性。

**Architecture:** 只改 `ActivityGraph.astro`：给滚动容器加一层定位壳与渐隐/提示节点；`<40rem` 用媒体查询把网格从自适应 `minmax(0,1fr)` 切回固定 `var(--cell)` 列并允许 `overflow-x:auto`；脚本在初次渲染与切年后把 `scrollLeft` 对准最后一个活跃格。`≥40rem` 的桌面网格与视觉完全不动。

**Tech Stack:** Astro 组件（`<style is:global>` + 模块脚本）、原生 CSS 媒体查询、原生 scroll/offsetLeft；无框架、无新依赖。

**Spec:** `docs/superpowers/specs/2026-11-04-moments-activity-mobile-design.md`

## Global Constraints

- 只改 `<40rem`；`≥40rem` 的网格、卡片、图例、tooltip 与数据逻辑不变。
- 保留 `--cell: 10px`、`--gap: 3px`；不新增颜色 token。
- 默认定位到最后一个 `data-level > 0` 的格子；无活跃日时当前年退到 `[data-today]`，历史年份回到最左。
- 周几栏在 `<40rem` sticky；右侧渐隐滚到末端隐藏；「横向滑动」提示只在 `<40rem` 显示。
- 滚动容器 `tabindex="0"`、`role="group"`、`aria-label="动态年历，可横向滚动"`；网格继续 `aria-hidden`，活跃日仍由 `sr-list` 提供。
- 不新增依赖、组件或数据字段；不改 moments 时间轴/页头/发布器。
- 不自动提交 Git（系统约束）。
- 只格式化改动文件；仓库级 `npm run format:check` 在改动前已有 vendored 文件错误。

## Review Focus

- **稀疏数据定位**：2026 只有 7 月的 5 条动态，今天是 11 月；初始滚动必须停在 7 月 30 日（最后活跃），不能停在空的 11 月。
- **320px 月份标签**：固定 10px 格子后，相邻月份标签矩形仍不能重叠；53 周网格宽度必须 > 容器宽。
- **sticky 周几栏**：横向滚动 100px 后，一/三/五的 x 坐标不变，且背景遮住滚过的格子。
- **桌面泄漏**：`≥40rem` 不能出现横向滚动、渐隐或提示；640 / 1024 / 1440 与改动前一致。
- **键盘与边缘手势**：`tabindex=0` 的容器能 Tab 聚焦并用方向键滚动；`overscroll-behavior-inline: contain` 不让滚动链到页面。

---

### Task 1: 横滑年历与滚动定位

**Files:**
- Modify: `src/components/ActivityGraph.astro`（模板、`<style is:global>`、模块脚本）
- Test: dev server + playwright-cli 测量/截图（项目对可视样式约定人工核验；不新增测试文件）

**Interfaces:**
- Consumes: 现有 `.activity-scroll` / `.activity-grid` / `[data-grid]` / `[data-today]` / `.activity-cell[data-level]`；`renderGrid`、`buildYearData`、`formatCaption`、`renderSrList`；`--cell`、`--gap`、`--weeks`。
- Produces: `.activity-scroll-wrap`、`[data-scroll]`、`.activity-fade`、`.activity-scroll-hint`；脚本内 `focusScroll()` / `updateFade()`（不导出）；滚动容器上的 `is-at-end` 类。

- [ ] **Step 1: 记录改动前的失败基线**

dev server 打开 `/moments`，在 390×844 与 320×844 测量：

```js
(() => {
  const cell = document.querySelector(".activity-cell").getBoundingClientRect();
  const grid = document.querySelector(".activity-grid").getBoundingClientRect();
  const months = [...document.querySelectorAll(".activity-month")].slice(0, 4).map((m) => {
    const r = m.getBoundingClientRect();
    return { t: m.textContent, left: r.left, right: r.right };
  });
  return {
    cell: [Math.round(cell.width), Math.round(cell.height)],
    gridW: Math.round(grid.width),
    months,
    scrollable:
      document.querySelector(".activity-scroll").scrollWidth >
      document.querySelector(".activity-scroll").clientWidth,
  };
})()
```

Expected: 390 下 cell `3×3`、gridW 约 315、相邻月份间隙 1–7px、`scrollable:false`；320 下月份标签重叠（前一个 `right` > 后一个 `left`）。截图存 `output/playwright/`。

- [ ] **Step 2: 模板加滚动壳、渐隐与提示**

把现有 `<div class="activity-scroll">…</div>` 换成：

```html
<div class="activity-scroll-wrap">
  <div
    class="activity-scroll"
    data-scroll
    tabindex="0"
    role="group"
    aria-label="动态年历，可横向滚动"
  >
    <div
      class="activity-grid"
      data-grid
      aria-hidden="true"
      style={`--weeks: ${defaultData.weeks}`}
      set:html={renderGrid(defaultData, todayStr)}
    ></div>
  </div>
  <span class="activity-fade" aria-hidden="true"></span>
</div>
<span class="activity-scroll-hint" aria-hidden="true">横向滑动</span>
```

提示放在滚动壳之后、`.activity-foot` 之前。

- [ ] **Step 3: 加 CSS**

在 `.activity-scroll` 基础规则旁新增：

```css
.activity-scroll-wrap {
  position: relative;
}

.activity-grid {
  position: relative; /* 让 cell.offsetLeft 相对网格内容计算 */
}

.activity-fade {
  display: none;
}

.activity-scroll-hint {
  display: none;
}
```

在 `<style is:global>` 末尾新增：

```css
@media (width < 40rem) {
  .activity-scroll {
    overflow-x: auto;
    overscroll-behavior-inline: contain;
  }

  .activity-grid {
    grid-template-columns: var(--gutter, 20px) repeat(
        var(--weeks, 53),
        var(--cell)
      );
    grid-template-rows: auto repeat(7, var(--cell));
    inline-size: max-content;
  }

  /* 周几栏在横滑时贴住左侧；背景盖住滚过的格子 */
  .activity-weekday {
    position: sticky;
    left: 0;
    z-index: 1;
    justify-self: stretch;
    inline-size: 100%;
    text-align: right;
    background: var(--background);
  }

  .activity-fade {
    display: block;
    position: absolute;
    inset-block: 0;
    inset-inline-end: 0;
    inline-size: 24px;
    background: linear-gradient(to right, transparent, var(--background));
    pointer-events: none;
    transition: opacity 0.15s;
  }

  .activity-scroll.is-at-end + .activity-fade {
    opacity: 0;
  }

  .activity-scroll-hint {
    display: flex;
    justify-content: flex-end;
    margin-top: var(--space-3xs);
    font-family: var(--font-mono);
    font-size: calc(var(--step--1) - 1px);
    color: var(--muted-foreground);
  }
}
```

- [ ] **Step 4: 脚本加定位与渐隐状态**

在 `const tooltip = …` 后补：

```js
const scroll = root.querySelector<HTMLElement>("[data-scroll]")
const fade = root.querySelector<HTMLElement>(".activity-fade")
```

并把守卫改为同时要求 `scroll`、`fade` 非空。在 `hideTooltip` 之前新增：

```js
const updateFade = () => {
  const atEnd =
    scroll.scrollLeft + scroll.clientWidth >= scroll.scrollWidth - 1
  scroll.classList.toggle("is-at-end", atEnd)
}

const focusScroll = () => {
  const active = [
    ...grid.querySelectorAll<HTMLElement>(
      '.activity-cell[data-level]:not([data-level="0"])',
    ),
  ]
  const target =
    active[active.length - 1] ??
    grid.querySelector<HTMLElement>("[data-today]")
  if (!target) {
    scroll.scrollLeft = 0
    updateFade()
    return
  }
  const max = scroll.scrollWidth - scroll.clientWidth
  scroll.scrollLeft = Math.max(
    0,
    Math.min(target.offsetLeft - scroll.clientWidth + 64, max),
  )
  updateFade()
}

scroll.addEventListener("scroll", updateFade, { passive: true })
window.addEventListener("resize", updateFade, { passive: true })
focusScroll()
```

在 `select.addEventListener("change", …)` 更新完 `grid` / `caption` / `srList` 之后调用 `focusScroll()`。

- [ ] **Step 5: 格式化与构建检查**

Run: `npx biome format src/components/ActivityGraph.astro`
Expected: PASS（必要时 `--write` 只改这一个文件）。
Run: `npm run build`
Expected: 构建成功。

- [ ] **Step 6: 390px 验收**

在 390×844 打开 `/moments`，测量：

```js
(() => {
  const scroll = document.querySelector(".activity-scroll");
  const cell = document.querySelector(".activity-cell").getBoundingClientRect();
  const active = [
    ...document.querySelectorAll('.activity-cell[data-level]:not([data-level="0"])'),
  ];
  const last = active[active.length - 1].getBoundingClientRect();
  const s = scroll.getBoundingClientRect();
  const weekdays = [...document.querySelectorAll(".activity-weekday")].map((w) =>
    Math.round(w.getBoundingClientRect().x),
  );
  const months = [...document.querySelectorAll(".activity-month")];
  const gaps = months.slice(1).map((m, i) => {
    const a = months[i].getBoundingClientRect();
    const b = m.getBoundingClientRect();
    return Math.round(b.left - a.right);
  });
  return {
    cell: [Math.round(cell.width), Math.round(cell.height)],
    gridW: Math.round(document.querySelector(".activity-grid").getBoundingClientRect().width),
    scrollLeft: Math.round(scroll.scrollLeft),
    lastActiveVisible: last.left >= s.left && last.right <= s.right,
    minMonthGap: Math.min(...gaps),
    weekdays,
    hint: getComputedStyle(document.querySelector(".activity-scroll-hint")).display,
    fade: getComputedStyle(document.querySelector(".activity-fade")).opacity,
  };
})()
```

Expected: cell `10×10`、gridW 约 709、`scrollLeft > 0`、`lastActiveVisible:true`、`minMonthGap` ≥ 20、周几栏 x 一致、hint `flex`、fade `1`。截图存 `output/playwright/`。

- [ ] **Step 7: 断点与桌面矩阵**

- 320 / 360 / 639：重复 Step 6；cell 仍 10×10，`minMonthGap` ≥ 20，last active 可见。
- 滚动 120px 后：周几栏 x 不变；滚到 `scrollLeft = scrollWidth - clientWidth` 时 fade opacity 为 0。
- 640 / 1024 / 1440：`.activity-scroll` 的 `scrollWidth === clientWidth`，无渐隐/提示（`display:none`），月份标签不重叠，卡片高度与改动前一致；各截一张图。

Expected: 全部通过。

- [ ] **Step 8: 年份切换定位**

当前内容只有 2026。临时新建 `src/content/moments/2025-12-31-test.md`：

```md
---
date: 2025-12-31
---

临时测试条目。
```

等 dev 重新收集后，在 390 下切到 2025：

- 图注变为「1 条动态 · 2025 年」；
- 网格、sr 列表更新；
- `scrollLeft` 停在 2025-12-31 附近（最后一个活跃格可见）；
- 渐隐状态正确。

验完用 DeleteFile 删除临时文件，reload 确认年份选项回到只剩 2026。Expected: 通过。

- [ ] **Step 9: 暗色、键盘与边缘手势**

- 390 暗色：周几栏背景、渐隐、格子、图例正常；截图。
- Tab 聚焦 `.activity-scroll` 后按 ArrowRight，`scrollLeft` 增加且焦点环可见。
- `overscroll-behavior-inline` 计算值为 `contain`。
- 桌面 hover tooltip 仍正常（移动格出现日期提示）。

Expected: 通过。

- [ ] **Step 10: 既有检查**

Run:
```bash
npm run build
bash scripts/tests/i18n-check.sh
```

Expected: build 成功；i18n exit 0 / 96 PASS。`home-guide-topbar-check.sh` 的 hero 断言是既有陈旧失败，与本改动无关。

- [ ] **Step 11: 汇报，等待提交决定**

汇报改动文件、测量结果、截图路径；不自动 commit。
