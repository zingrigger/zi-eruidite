# 标签页瓷砖视图 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `/tags` 增加一个默认关闭的开关，切换出按引用次数铺开的可交互瓷砖拼贴，同时完整保留现有胶囊列表。

**Architecture:** 构建期用纯函数 `layoutTreemap` 算 squarified 百分比坐标，`TagMosaic.astro` SSR 输出绝对定位砖块；开关是原生 checkbox，页面用 `:has()` 切视图，并通过继承的 CSS 变量把显隐下发给子组件根元素。全程无客户端 JS。

**Tech Stack:** Astro 7、TypeScript、原生 CSS（Utopia / Radix 令牌）、Node 24（直接 import `.ts` 做断言）。

**Spec:** `docs/superpowers/specs/2026-11-05-tags-mosaic-design.md`

## Global Constraints

- 包管理器用 npm：`npm run build`、`npm run format:check`。
- Biome：2 空格、80 列、双引号、无分号。只对改动文件跑
  `npx biome format --write <files>`，不要跑仓库级 `npm run format`（会扫到
  `.agents/skills` 的 vendored 文件）。
- 不引入框架、CSS 框架或新依赖；不新增客户端脚本。
- `/tags` 中文独有，不新增 `/en/tags`。
- 开关默认关闭、不持久化；无 JS 时仍可切换。
- 所有动效在 `prefers-reduced-motion: reduce` 下降级。
- 新组件必须补 `docs/components/tag-mosaic.md` 与
  `docs/components/README.md` 索引。
- 不自动 `git commit`；用户明确要求时再提交。

## Review Focus

1. **空标签 / 零权重**：算法不能除零或产生 NaN；页面无标签时不渲染开关与图。
2. **长尾极小标签**：1 条 vs 几百条时，砖块仍有可点尺寸，占比允许封顶近似。
3. **超长标签名 + `sm` 砖**：文字省略不溢出，`aria-label` 保留全名与拆分。
4. **边缘砖与灰缝**：360 / 1280 宽下砖块不越界、不重叠，面积和铺满容器。
5. **无 JS / reduced motion / 键盘**：开关照常可用，无入场位移，焦点环可见。

---

## File Structure

- `src/lib/treemap.ts` — 纯布局函数，不依赖 DOM。
- `scripts/tests/treemap-check.mjs` — 布局断言。
- `src/components/TagMosaic.astro` — 组件标记 + scoped 样式。
- `src/pages/tags/index.astro` — 开关工具栏、视图切换、页面数据。
- `docs/components/tag-mosaic.md` — 组件用法。
- `docs/components/README.md` — 索引补一行。

### Task 1: Treemap 布局纯函数

**Files:**
- Create: `src/lib/treemap.ts`
- Create: `scripts/tests/treemap-check.mjs`

**Interfaces:**
- Consumes: 无。
- Produces:
  ```ts
  type TreemapItem = { key: string; weight: number }
  type TreemapRect = { key: string; x: number; y: number; w: number; h: number }
  layoutTreemap(
    items: TreemapItem[],
    size: { width: number; height: number },
    options?: { minShare?: number },
  ): TreemapRect[]
  ```
  百分比坐标（0–100），返回顺序 = 权重降序。

- [ ] **Step 1: 写失败的布局断言**

创建 `scripts/tests/treemap-check.mjs`：

```js
import assert from "node:assert/strict"
import { layoutTreemap } from "../../src/lib/treemap.ts"

const SIZE = { width: 1000, height: 625 }
const area = (r) => r.w * r.h
const near = (a, b, eps = 0.5) => Math.abs(a - b) <= eps

const rects = layoutTreemap(
  [
    { key: "a", weight: 50 },
    { key: "b", weight: 25 },
    { key: "c", weight: 15 },
    { key: "d", weight: 10 },
  ],
  SIZE,
)
assert.equal(rects.length, 4)
assert.deepEqual(
  rects.map((r) => r.key),
  ["a", "b", "c", "d"],
)
assert.ok(near(rects.reduce((s, r) => s + area(r), 0), 10000))
for (const r of rects) {
  assert.ok(r.w > 0 && r.h > 0, `${r.key} has positive size`)
  assert.ok(r.x >= -0.01 && r.y >= -0.01, `${r.key} starts inside`)
  assert.ok(r.x + r.w <= 100.01, `${r.key} right edge`)
  assert.ok(r.y + r.h <= 100.01, `${r.key} bottom edge`)
}

assert.deepEqual(layoutTreemap([], SIZE), [])
assert.deepEqual(layoutTreemap([{ key: "zero", weight: 0 }], SIZE), [])

const lifted = layoutTreemap(
  [
    { key: "big", weight: 99 },
    { key: "tiny", weight: 1 },
  ],
  SIZE,
  { minShare: 0.1 },
)
const tiny = lifted.find((r) => r.key === "tiny")
assert.ok(tiny && area(tiny) > 500, `tiny lifted to ${tiny && area(tiny)}`)

const equal = layoutTreemap(
  Array.from({ length: 15 }, (_, i) => ({ key: `t${i}`, weight: 1 })),
  SIZE,
)
const avg = 10000 / equal.length
for (const r of equal) {
  assert.ok(
    Math.abs(area(r) - avg) < avg * 0.05,
    `${r.key} area ${area(r)} vs ${avg}`,
  )
}

console.log("treemap-check ok")
```

- [ ] **Step 2: 运行，确认失败**

Run: `node scripts/tests/treemap-check.mjs`
Expected: FAIL，`ERR_MODULE_NOT_FOUND`（`src/lib/treemap.ts` 不存在）。

- [ ] **Step 3: 实现 `src/lib/treemap.ts`**

用标准 squarified treemap：权重封底 → 归一化 → 按短边铺行 → 行内最优
长宽比 → 递归剩余矩形。下面是可直接落地的实现，别再引入依赖：

```ts
export type TreemapItem = { key: string; weight: number }

export type TreemapRect = {
  key: string
  x: number
  y: number
  w: number
  h: number
}

type Cell = { key: string; area: number }
type Box = { x: number; y: number; w: number; h: number }

const round = (n: number) => Math.round(n * 1e4) / 1e4

function worstRatio(row: Cell[], side: number): number {
  const sum = row.reduce((s, c) => s + c.area, 0)
  if (sum <= 0) return Number.POSITIVE_INFINITY
  const thickness = sum / side
  let worst = 0
  for (const cell of row) {
    const length = cell.area / thickness
    const ratio = Math.max(length / thickness, thickness / length)
    if (ratio > worst) worst = ratio
  }
  return worst
}

export function layoutTreemap(
  items: TreemapItem[],
  size: { width: number; height: number },
  options: { minShare?: number } = {},
): TreemapRect[] {
  const positive = items.filter((item) => item.weight > 0)
  if (positive.length === 0) return []

  const total = positive.reduce((sum, item) => sum + item.weight, 0)
  const floor = (options.minShare ?? 0.012) * total
  const weighted = positive.map((item) => ({
    key: item.key,
    weight: Math.max(item.weight, floor),
  }))
  const sum = weighted.reduce((acc, item) => acc + item.weight, 0)
  const sorted = [...weighted].sort(
    (a, b) => b.weight - a.weight || a.key.localeCompare(b.key),
  )
  const scale = (size.width * size.height) / sum
  const result: TreemapRect[] = []

  const push = (key: string, x: number, y: number, w: number, h: number) => {
    result.push({
      key,
      x: round((x / size.width) * 100),
      y: round((y / size.height) * 100),
      w: round((w / size.width) * 100),
      h: round((h / size.height) * 100),
    })
  }

  const place = (cells: Cell[], box: Box): void => {
    if (cells.length === 0) return
    if (cells.length === 1) {
      push(cells[0].key, box.x, box.y, box.w, box.h)
      return
    }

    const side = Math.min(box.w, box.h)
    const row: Cell[] = []
    let best = Number.POSITIVE_INFINITY

    for (const cell of cells) {
      const next = [...row, cell]
      const ratio = worstRatio(next, side)
      if (row.length > 0 && ratio > best) break
      row.push(cell)
      best = ratio
    }

    const rowArea = row.reduce((acc, cell) => acc + cell.area, 0)
    const rest = cells.slice(row.length)

    if (box.w >= box.h) {
      const thickness = rowArea / box.h
      let y = box.y
      for (const cell of row) {
        const h = cell.area / thickness
        push(cell.key, box.x, y, thickness, h)
        y += h
      }
      place(rest, {
        x: box.x + thickness,
        y: box.y,
        w: box.w - thickness,
        h: box.h,
      })
      return
    }

    const thickness = rowArea / box.w
    let x = box.x
    for (const cell of row) {
      const w = cell.area / thickness
      push(cell.key, x, box.y, w, thickness)
      x += w
    }
    place(rest, {
      x: box.x,
      y: box.y + thickness,
      w: box.w,
      h: box.h - thickness,
    })
  }

  place(
    sorted.map((item) => ({ key: item.key, area: item.weight * scale })),
    { x: 0, y: 0, w: size.width, h: size.height },
  )

  return result
}
```

- [ ] **Step 4: 运行，确认通过**

Run: `node scripts/tests/treemap-check.mjs`
Expected: `treemap-check ok`，退出码 0。

- [ ] **Step 5: 只格式化改动文件**

Run: `npx biome format --write src/lib/treemap.ts scripts/tests/treemap-check.mjs`
Expected: 无错误；不要跑仓库级 `npm run format`。

### Task 2: TagMosaic 组件 + 页面开关（静态视图）

**Files:**
- Create: `src/components/TagMosaic.astro`
- Modify: `src/pages/tags/index.astro`

**Interfaces:**
- Consumes: `layoutTreemap`（Task 1）。
- Produces: `TagMosaic.astro`，props 为
  `{ tags: { tag: string; href: string; blog: number; moments: number; total: number }[] }`；
  根元素 `<tag-mosaic>`；页面变量 `--tags-view-mosaic`（`none` / `block`）。

- [ ] **Step 1: 先拍基线并写失败的检查**

1. 确认 dev server 在跑（`curl -s -o /dev/null -w '%{http_code}' localhost:4321/tags`
   返回 200；否则 `npm run dev`）。用 playwright skill 打开 `/tags`，存一张
   `tags-default-before.png` 作为默认视图基线。
2. 跑一次构建并确认新标记还不存在（预期失败）：

```bash
npm run build >/dev/null
node -e '
const fs = require("fs")
const html = fs.readFileSync("dist/tags/index.html", "utf8")
if (!html.includes("tags-switch")) throw new Error("switch missing")
const tiles = [...html.matchAll(/class="tag-tile"/g)].length
if (tiles === 0) throw new Error("tiles missing")
console.log("tiles", tiles)
'
```

Expected: FAIL，`switch missing`。

- [ ] **Step 2: 实现 `TagMosaic.astro`**

frontmatter 与标记（类名、属性、内联变量必须一致）：

```astro
---
import { layoutTreemap } from "@/lib/treemap"

export type TagMosaicEntry = {
  tag: string
  href: string
  blog: number
  moments: number
  total: number
}

type Props = { tags: TagMosaicEntry[] }

const { tags } = Astro.props
const sorted = [...tags].sort(
  (a, b) => b.total - a.total || a.tag.localeCompare(b.tag),
)
const totalRefs = sorted.reduce((n, entry) => n + entry.total, 0)
const rects = layoutTreemap(
  sorted.map((entry) => ({ key: entry.tag, weight: entry.total })),
  { width: 1000, height: 625 },
)
const rectByKey = new Map(rects.map((rect) => [rect.key, rect]))
const solidKeys = new Set(
  totalRefs > 0
    ? sorted
        .filter((entry) => entry.total / totalRefs >= 0.08)
        .slice(0, 3)
        .map((entry) => entry.tag)
    : [],
)

const labelOf = (entry: TagMosaicEntry) => {
  const parts: string[] = []
  if (entry.blog > 0) parts.push(`博客 ${entry.blog} 篇`)
  if (entry.moments > 0) parts.push(`动态 ${entry.moments} 条`)
  return `#${entry.tag}，共 ${entry.total} 条${
    parts.length > 0 ? `：${parts.join("、")}` : ""
  }`
}
---

<tag-mosaic role="region" aria-label="标签占比图">
  <ul>
    {sorted.map((entry, i) => {
      const rect = rectByKey.get(entry.tag)
      if (!rect) return null
      const minDim = Math.min(rect.w * 10, rect.h * 6.25)
      const tier = minDim >= 120 ? "lg" : minDim >= 70 ? "md" : "sm"
      const tone = solidKeys.has(entry.tag) ? "solid" : "plain"
      const tilt = i % 2 === 0 ? "-0.35" : "0.35"
      return (
        <li
          class="tag-tile"
          data-tier={tier}
          data-tone={tone}
          style={`--x:${rect.x}%;--y:${rect.y}%;--w:${rect.w}%;--h:${rect.h}%;--i:${Math.min(i, 18)};--tilt:${tilt}deg`}
        >
          <a href={entry.href} aria-label={labelOf(entry)}>
            <span class="tag-tile-name">#{entry.tag}</span>
            <span class="tag-tile-count">{entry.total}</span>
          </a>
        </li>
      )
    })}
  </ul>
</tag-mosaic>
```

scoped 样式（静态部分，不含动效）：

```css
tag-mosaic {
  display: var(--tags-view-mosaic, none);
  position: relative;
  aspect-ratio: 16 / 10;
  border: 1px solid var(--border);
  border-radius: var(--radius-2xl);
  background: var(--background);
  container-type: inline-size;
}

tag-mosaic > ul {
  position: relative;
  height: 100%;
  margin: 0;
  padding: 0;
  list-style: none;
}

.tag-tile {
  position: absolute;
  left: calc(var(--x) + var(--tile-gap) / 2);
  top: calc(var(--y) + var(--tile-gap) / 2);
  width: calc(var(--w) - var(--tile-gap));
  height: calc(var(--h) - var(--tile-gap));
  --tile-gap: 8px;
  z-index: 0;
}

.tag-tile > a {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  gap: var(--space-3xs);
  box-sizing: border-box;
  width: 100%;
  height: 100%;
  padding: clamp(0.35rem, 1.2cqw, 0.75rem);
  overflow: hidden;
  color: var(--foreground);
  background: var(--gray-4);
  border-radius: var(--radius-lg);
  text-decoration: none;
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 0.12);
}

.tag-tile[data-tone="solid"] > a {
  color: var(--primary-foreground);
  background: var(--primary);
}

.tag-tile-name {
  overflow: hidden;
  font-size: clamp(0.7rem, 2.2cqw, 0.95rem);
  font-weight: 500;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.tag-tile-count {
  align-self: flex-end;
  font-family: var(--font-mono);
  font-size: 0.8em;
  opacity: 0.6;
}

.tag-tile[data-tier="sm"] > a {
  padding: var(--space-3xs);
}

.tag-tile[data-tier="sm"] .tag-tile-count {
  display: none;
}

@media (width < 640px) {
  tag-mosaic {
    aspect-ratio: 4 / 3;
  }

  .tag-tile {
    --tile-gap: 6px;
  }
}
```

- [ ] **Step 3: 接入 `/tags` 页面**

`src/pages/tags/index.astro` 的 frontmatter 保留现有 `getAllTags` import 与
`const tags = await getAllTags()`，在 import 区加一行 `TagMosaic`，在 `tags` 下方
追加：

```ts
import TagMosaic from "@/components/TagMosaic.astro"

const entries = [...tags].map(([tag, { blog, moments }]) => ({
  tag,
  href: `/tags/${tag}`,
  blog: blog.length,
  moments: moments.length,
  total: blog.length + moments.length,
}))
const totalRefs = entries.reduce((n, entry) => n + entry.total, 0)
```

模板里把原来裸的 `<ul>` 包进 `tags-explorer`，并加工具栏；列表项内容原样
不动，只给 `<ul>` 加 `class="tags-list"`：

```astro
<tags-explorer>
  {tags.size > 0 && (
    <div class="tags-toolbar">
      <span class="tags-legend">
        面积 = 被引用次数（共 {totalRefs} 次）
      </span>
      <label class="tags-switch">
        <span class="tags-switch-label">瓷砖视图</span>
        <input type="checkbox" role="switch" />
        <span class="tags-switch-track" aria-hidden="true">
          <span class="tags-switch-thumb"></span>
        </span>
      </label>
    </div>
  )}
  <ul class="tags-list">
    {[...tags].map(([tag, { blog, moments }]) => {
      const total = blog.length + moments.length
      return (
        <li>
          <a href={`/tags/${tag}`}>#{tag}<tag-count>{total}</tag-count></a>
        </li>
      )
    })}
  </ul>
  {tags.size > 0 && <TagMosaic tags={entries} />}
</tags-explorer>
```

页面 `<style>` 改三处：

1. 现有 `ul { … }` 选择器改名 `.tags-list { … }`，嵌套的 `a` / `tag-count`
   声明一个字都不动；
2. 加工具栏、图例、开关样式（值固定）：

```css
tags-explorer {
  display: block;
  --tags-view-mosaic: none;
}

tags-explorer:has(.tags-switch input:checked) .tags-list {
  display: none;
}

tags-explorer:has(.tags-switch input:checked) {
  --tags-view-mosaic: block;
}

tags-explorer:has(.tags-switch input:checked) .tags-legend {
  visibility: visible;
  opacity: 1;
}

.tags-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-s);
  min-height: 1.75rem;
  margin-bottom: var(--space-m);
}

.tags-legend {
  font-family: var(--font-mono);
  font-size: calc(var(--step--1) - 1px);
  color: var(--muted-foreground);
  visibility: hidden;
  opacity: 0;
  transition: opacity 0.2s ease;
}

.tags-switch {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2xs);
  margin-inline-start: auto;
  cursor: pointer;
}

.tags-switch-label {
  font-family: var(--font-mono);
  font-size: var(--step--1);
  color: var(--muted-foreground);
}

.tags-switch:hover .tags-switch-label {
  color: var(--foreground);
}

.tags-switch input {
  position: absolute;
  width: 1px;
  height: 1px;
  margin: -1px;
  padding: 0;
  overflow: hidden;
  clip-path: inset(50%);
  white-space: nowrap;
  border: 0;
}

.tags-switch-track {
  position: relative;
  display: inline-block;
  box-sizing: border-box;
  width: 2.25rem;
  height: 1.25rem;
  background: var(--muted);
  border: 1px solid var(--border);
  border-radius: var(--radius-full);
  transition:
    background-color 0.18s ease,
    border-color 0.18s ease;
}

.tags-switch-thumb {
  position: absolute;
  top: 50%;
  left: 0.125rem;
  width: 1rem;
  height: 1rem;
  background: var(--background);
  border-radius: var(--radius-full);
  box-shadow: 0 1px 2px rgb(0 0 0 / 0.2);
  transform: translateY(-50%);
  transition: transform 0.18s ease;
}

.tags-switch input:checked + .tags-switch-track {
  background: var(--accent);
  border-color: var(--accent);
}

.tags-switch input:checked + .tags-switch-track .tags-switch-thumb {
  transform: translate(1rem, -50%);
}

.tags-switch input:focus-visible + .tags-switch-track {
  outline: 2px solid var(--ring);
  outline-offset: 2px;
}
```

- [ ] **Step 4: 构建并断言标记**

Run: `npm run build >/dev/null`，然后跑下面的断言：

```bash
node -e '
const fs = require("fs")
const html = fs.readFileSync("dist/tags/index.html", "utf8")
if (!html.includes("tags-switch")) throw new Error("switch missing")
if (!/role="switch"(?![^>]*checked)/.test(html)) throw new Error("default should be off")
const tiles = [...html.matchAll(/class="tag-tile"/g)].length
const list = html.match(/class="tags-list"[\s\S]*?<\/ul>/)
const pills = list ? [...list[0].matchAll(/href="\/tags\//g)].length : 0
if (tiles !== pills || tiles === 0) {
  throw new Error(`tiles ${tiles} vs pills ${pills}`)
}
console.log(`tiles=${tiles} default-off`)
'
```

Expected: `tiles=15 default-off`（数量随内容变化，但两数必须相等）。

- [ ] **Step 5: 浏览器检查默认视图与切换**

用 playwright skill 打开 `http://localhost:4321/tags`：

1. 默认截图与 `tags-default-before.png` 对比：除新增工具栏外，页头与胶囊列表
   不变；
2. 点击「瓷砖视图」开关，截图：砖块铺满容器、无越界/重叠、`astro` / `blog`
   两块墨色、其余灰砖；再点一次回到列表；
3. 360px 宽截图：容器变 4/3，砖块仍在容器内，标签名超长有省略号。

- [ ] **Step 6: 格式化改动文件**

Run: `npx biome format --write src/components/TagMosaic.astro src/pages/tags/index.astro`
Expected: 无错误。

### Task 3: 动效、悬停与降级

**Files:**
- Modify: `src/components/TagMosaic.astro`

**Interfaces:**
- Consumes: Task 2 的 `.tag-tile` / `--i` / `--tilt`。
- Produces: 入场、悬停、聚焦、reduced-motion 规则。

- [ ] **Step 1: 写失败检查**

Run: `grep -q "@keyframes tag-tile-in" src/components/TagMosaic.astro`
Expected: FAIL（还没有动画）。

- [ ] **Step 2: 加动效与交互 CSS**

```css
.tag-tile {
  transition:
    transform 0.16s ease,
    opacity 0.16s ease;
}

@media (prefers-reduced-motion: no-preference) {
  .tag-tile {
    animation: tag-tile-in 460ms cubic-bezier(0.22, 0.85, 0.24, 1) backwards;
    animation-delay: calc(var(--i) * 26ms);
  }
}

@keyframes tag-tile-in {
  from {
    opacity: 0;
    transform: translateY(10px) scale(0.96);
  }

  to {
    opacity: 1;
    transform: none;
  }
}

.tag-tile:hover,
.tag-tile:focus-within {
  z-index: 2;
  transform: translateY(-3px) rotate(var(--tilt));
}

.tag-tile:hover > a,
.tag-tile:focus-within > a {
  background: var(--gray-5);
  box-shadow:
    0 8px 18px rgb(0 0 0 / 0.16),
    inset 0 1px 0 rgb(255 255 255 / 0.18);
}

.tag-tile[data-tone="solid"]:hover > a,
.tag-tile[data-tone="solid"]:focus-within > a {
  background: color-mix(in oklab, var(--primary) 88%, var(--background));
}

.tag-tile > a:focus-visible {
  border-radius: inherit;
  outline: 2px solid var(--ring);
  outline-offset: -3px;
}

tag-mosaic:has(.tag-tile a:hover) .tag-tile:not(:has(a:hover)),
tag-mosaic:has(.tag-tile a:focus-visible)
  .tag-tile:not(:has(a:focus-visible)) {
  opacity: 0.52;
}

@media (prefers-reduced-motion: reduce) {
  .tag-tile {
    transition: opacity 0.16s ease;
  }

  .tag-tile:hover,
  .tag-tile:focus-within {
    transform: none;
  }
}
```

**不要**把动画填成 `both` 或 `forwards`：动画结束后 `transform` 会被动画值
锁住，悬停的 `translateY(-3px)` 就不生效；`backwards` 只在延迟期间保持起始帧。

- [ ] **Step 3: 构建 + 浏览器验证**

1. `npm run build` 通过；
2. playwright 打开 `/tags`，打开开关：截一张动画中段、一张落定后；落定后
   hover `astro` 砖块，截图确认砖块抬起、其余变淡；
3. 键盘：`Tab` 到开关，`Space` 打开；再 `Tab` 到第一块砖，截图确认焦点环；
   `Enter` 进入 `/tags/astro`；
4. 360px 复查悬停/焦点不越出容器；超长标签名有省略号；用 `eval` 读最窄
   砖块的 `a[aria-label]`，确认含完整标签名与「博客 / 动态」拆分
   （当前没有 `sm` 砖，就以 360px 下最窄的那块为准）；
5. 用 Chrome DevTools 的 Rendering → Emulate CSS media feature
   `prefers-reduced-motion: reduce`（playwright CLI 没有媒体模拟开关），
   `eval` 确认
   `getComputedStyle(document.querySelector(".tag-tile")).animationName === "none"`
   且 hover 后 `transform` 为 `none`。

- [ ] **Step 4: 格式化**

Run: `npx biome format --write src/components/TagMosaic.astro`
Expected: 无错误。

### Task 4: 组件文档与收尾验证

**Files:**
- Create: `docs/components/tag-mosaic.md`
- Modify: `docs/components/README.md`

**Interfaces:**
- Consumes: Task 2/3 的最终 props、类名与 CSS 变量。
- Produces: 无代码接口；文档。

- [ ] **Step 1: 写组件文档**

按 `docs/components/README.md` 的八节顺序写：一句话说明、文件位置、快速上手、
Props 表、模式/取值、无障碍与降级、注意事项、完整示例。必须写清：

- props：`tags`（`TagMosaicEntry[]`，必填）与字段含义；
- 根元素 `tag-mosaic` 的显隐靠继承变量 `--tags-view-mosaic`；
- `data-tone` 阈值（前 3 且 share ≥ 8%）、`data-tier` 阈值（120 / 70）；
- 纯 CSS 开关、无持久化、bfcache 的边界；
- `prefers-reduced-motion` 降级与键盘行为。

- [ ] **Step 2: 补索引**

在 `docs/components/README.md` 的「索引」末尾加一行：

```md
- [TagMosaic 标签瓷砖图组件](tag-mosaic.md) —— 按引用次数铺开的标签瓷砖拼贴
  （构建期 squarified 布局 + SSR 百分比坐标，纯 CSS 开关切换，无客户端 JS）。
```

- [ ] **Step 3: 全量检查**

Run:

```bash
node scripts/tests/treemap-check.mjs
npm run format:check
npm run build
```

Expected: 三条全绿。

- [ ] **Step 4: 最终人工验收**

按 spec 的测试计划逐项过：默认视图、开关、悬停、键盘、明暗主题、
360/768/1280、`sidebar`/`topbar`、reduced motion、无 JS（DevTools 禁用
JavaScript 后开关仍可用）。把关键截图留在 `.playwright-cli/` 或回复里。

- [ ] **Step 5: 不自动提交**

除非用户明确要求，否则到此为止，不执行 `git commit`。
