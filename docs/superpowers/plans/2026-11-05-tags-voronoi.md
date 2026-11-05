# 标签页 Voronoi 瓷砖视图 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `/tags` 瓷砖视图的 squarified 矩形布局换成加权 Voronoi treemap（锐边多边形、细灰缝、标签居中），开关、胶囊列表与所有既有交互保持不变。

**Architecture:** 构建期用 power diagram（半平面裁切）+ 迭代权重/种子拟合面积，输出内缩后的凸多边形；组件按单元 bBox 定位 HTML 砖块，用 `clip-path: polygon()` 画出形状，标签放在单元质心。验证过的 throwaway spike 在 `.superpowers/brainstorm/29214-1793853045/voronoi-spike.mjs`（面积误差 0.55%），实现时移植其算法。

**Tech Stack:** Astro 7、TypeScript、原生 CSS、Node 24（直接 import `.ts` 跑断言）。

**Spec:** `docs/superpowers/specs/2026-11-05-tags-voronoi-design.md`

## Global Constraints

- 包管理器用 npm；`npm run build`、targeted Biome check。
- 不引入任何新依赖；算法自己写。
- 不新增客户端脚本；开关/显隐仍纯 CSS。
- 组件、页面、动效遵守既有无 JS / 不持久化 / `autocomplete="off"` /
  `prefers-reduced-motion` 约定。
- `/tags` 中文独有；不动胶囊列表、标签详情页、`/en`。
- 新组件文档同步更新；旧 spec/plan 保留为历史快照，加 superseded 注记。
- 不自动 git commit；用户明确要求时再提交。
- 仓库级 `npm run format:check` 的 `.agents/skills` 预存失败不归本次改动；
  只保证改动文件 targeted check 通过。

## Review Focus

1. **空 / 1 个 / 2 个标签、零权重**：不除零、不 NaN；1 个标签整板一块；
   2 个标签两块都非空。
2. **极端悬殊（2 标签 80:1）**：小单元不被挤空；内缩后仍有点集；
   标签降级为 `sm`，仍可回列表点。
3. **不规则单元里的标签**：质心在单元内；宽度按内切半径；名字省略不越出
   clip；`sm` 隐藏数量。
4. **clip-path 的命中/焦点/阴影**：点击命中多边形；焦点环用 drop-shadow
   而不是被裁掉的 outline；悬停阴影跟随形状。
5. **16/10 → 4/3 拉伸 + 328px + 无 JS / reduced motion**：面积比例保持、
   不越界、开关仍可用、无入场位移。

---

## File Structure

- `src/lib/voronoi-treemap.ts` — 新布局纯函数（替代 `src/lib/treemap.ts`）。
- `scripts/tests/voronoi-check.mjs` — 新断言（替代 `treemap-check.mjs`）。
- `src/components/TagMosaic.astro` — 砖块几何、`clip-path`、居中标签、
  焦点环、灰缝。
- `docs/components/tag-mosaic.md`、`docs/components/README.md` — 文档。
- `docs/superpowers/specs/2026-11-05-tags-mosaic-design.md` — 顶部加
  superseded 注记（布局部分）。
- `/tags` 页（`src/pages/tags/index.astro`）不动。

### Task 1: Voronoi 布局纯函数 + 断言

**Files:**
- Create: `src/lib/voronoi-treemap.ts`
- Create: `scripts/tests/voronoi-check.mjs`
- Delete (Task 3): `src/lib/treemap.ts`, `scripts/tests/treemap-check.mjs`

**Interfaces:**
- Consumes: 无。
- Produces:
  ```ts
  export type VoronoiItem = { key: string; weight: number }
  export type VoronoiPoint = { x: number; y: number }
  export type VoronoiCell = {
    key: string
    points: VoronoiPoint[]   // 已内缩，逻辑坐标
    box: { x: number; y: number; w: number; h: number }
    label: { x: number; y: number } // 相对 box 的百分比（0–100）
    inradius: number         // 逻辑单位
    share: number            // 未内缩面积 / 画布面积
  }
  export function layoutVoronoiTreemap(
    items: VoronoiItem[],
    size: { width: number; height: number },
    options?: {
      gap?: number            // 默认 6（相邻各让 3）
      seed?: number           // 默认 20261105
      maxIterations?: number  // 默认 400
      tolerance?: number      // 默认 0.008
    },
  ): VoronoiCell[]
  ```
  返回顺序 = 输入顺序；空 / 全零权重返回 `[]`。

- [ ] **Step 1: 写失败的断言**

`scripts/tests/voronoi-check.mjs` 断言：

```js
import assert from "node:assert/strict"
import { layoutVoronoiTreemap } from "../../src/lib/voronoi-treemap.ts"

const SIZE = { width: 1000, height: 625 }
const BOARD = SIZE.width * SIZE.height
const polygonArea = (pts) => {
  let a = 0
  for (let i = 0; i < pts.length; i++) {
    const p = pts[i]
    const q = pts[(i + 1) % pts.length]
    a += p.x * q.y - q.x * p.y
  }
  return a / 2
}
const near = (a, b, eps) => Math.abs(a - b) <= eps

// 15 equal
const equal = layoutVoronoiTreemap(
  Array.from({ length: 15 }, (_, i) => ({ key: `t${i}`, weight: 1 })),
  SIZE,
)
assert.equal(equal.length, 15)
assert.equal(new Set(equal.map((c) => c.key)).size, 15)
for (const cell of equal) {
  assert.ok(near(cell.share, 1 / 15, 0.01), `${cell.key} share ${cell.share}`)
  assert.ok(cell.points.length >= 3)
  assert.ok(polygonArea(cell.points) > 0)
  for (const p of cell.points) {
    assert.ok(p.x >= 0 && p.x <= SIZE.width, `${cell.key} x`)
    assert.ok(p.y >= 0 && p.y <= SIZE.height, `${cell.key} y`)
  }
  assert.ok(cell.label.x >= 0 && cell.label.x <= 100)
  assert.ok(cell.label.y >= 0 && cell.label.y <= 100)
  assert.ok(Number.isFinite(cell.inradius) && cell.inradius > 0)
}

// current data 2/2/1x13
const current = layoutVoronoiTreemap(
  [
    ["astro", 2], ["blog", 2],
    ["announcement", 1], ["design", 1], ["distributed-systems", 1],
    ["meetup", 1], ["reading", 1], ["rust", 1], ["site", 1],
    ["typography", 1], ["v1.0.0", 1], ["v1.3.0", 1],
    ["v1.5.0", 1], ["v1.6.0", 1], ["v2", 1],
  ].map(([key, weight]) => ({ key, weight })),
  SIZE,
)
const byKey = new Map(current.map((c) => [c.key, c]))
assert.ok(near(byKey.get("astro").share, 2 / 17, 0.01))
assert.ok(near(byKey.get("v2").share, 1 / 17, 0.01))
assert.ok(
  current.reduce((sum, c) => sum + c.share, 0) < 1.02,
)

// deterministic
const again = layoutVoronoiTreemap(
  current.map((c) => ({ key: c.key, weight: c.key === "astro" || c.key === "blog" ? 2 : 1 })),
  SIZE,
)
assert.deepEqual(again, current)

// empty / zero
assert.deepEqual(layoutVoronoiTreemap([], SIZE), [])
assert.deepEqual(layoutVoronoiTreemap([{ key: "z", weight: 0 }], SIZE), [])

// one item -> whole board (share ~1)
const one = layoutVoronoiTreemap([{ key: "only", weight: 1 }], SIZE)
assert.equal(one.length, 1)
assert.ok(near(one[0].share, 1, 0.001))

// two items 3:1 -> both non-empty, shares ~0.75/0.25
const two = layoutVoronoiTreemap(
  [{ key: "big", weight: 3 }, { key: "small", weight: 1 }],
  SIZE,
)
assert.equal(two.length, 2)
assert.ok(two.every((c) => c.points.length >= 3))
assert.ok(near(two[0].share, 0.75, 0.03))
assert.ok(near(two[1].share, 0.25, 0.03))

// extreme 80:1 -> the small cell still exists and is not zero-area
const skew = layoutVoronoiTreemap(
  [{ key: "big", weight: 80 }, { key: "small", weight: 1 }],
  SIZE,
)
assert.equal(skew.length, 2)
assert.ok(skew.every((c) => polygonArea(c.points) > 0))
assert.ok(near(skew[1].share, 1 / 81, 0.02))

console.log("voronoi-check ok")
```

- [ ] **Step 2: 运行，确认失败**

Run: `node scripts/tests/voronoi-check.mjs`
Expected: FAIL，`ERR_MODULE_NOT_FOUND`。

- [ ] **Step 3: 实现 `layoutVoronoiTreemap`**

移植 spike 算法：容器 1000×625 → 5×3 抖动网格（固定 PRNG）→ 每轮
Sutherland–Hodgman 半平面裁出 power cell → 面积/质心 → 权重更新
`w += 0.45 * (target - area)`、空单元额外加、权重去均值、种子向质心走
0.18 → 误差 < 0.8% 或 400 轮。再对每个凸多边形内缩 `gap/2`，算 bBox、
质心、内切半径、未内缩 share。内缩塌陷时丢弃该单元；1 个标签直接整板
内缩一块。

关键公式（spec §「加权 Voronoi」）：

```
2(p_j − p_i)·x ≤ |p_j|² − |p_i|² + w_i − w_j
```

- [ ] **Step 4: 运行，确认通过**

Run: `node scripts/tests/voronoi-check.mjs`
Expected: `voronoi-check ok`。

- [ ] **Step 5: 只格式化改动文件**

Run: `npx biome format --write src/lib/voronoi-treemap.ts scripts/tests/voronoi-check.mjs`
Expected: 无错误。

### Task 2: TagMosaic 换成 Voronoi 砖块

**Files:**
- Modify: `src/components/TagMosaic.astro`

**Interfaces:**
- Consumes: `layoutVoronoiTreemap`（Task 1）。
- Produces: 新砖块标记/CSS；`/tags` 页面无需改动。

- [ ] **Step 1: 写失败检查**

Run: `grep -q "clip-path:polygon" src/components/TagMosaic.astro`
Expected: FAIL（当前只有矩形/圆角）。

- [ ] **Step 2: 改 frontmatter**

```ts
import { layoutVoronoiTreemap } from "@/lib/voronoi-treemap"

const sorted = [...tags].sort(
  (a, b) => b.total - a.total || a.tag.localeCompare(b.tag),
)
const cells = layoutVoronoiTreemap(
  sorted.map((entry) => ({ key: entry.tag, weight: entry.total })),
  { width: 1000, height: 625 },
)
const cellByKey = new Map(cells.map((cell) => [cell.key, cell]))
```

`solidKeys`、`labelOf` 保持不变。每个 entry 渲染：

```astro
const cell = cellByKey.get(entry.tag)
if (!cell) return null
const tier =
  cell.inradius >= 55 ? "lg" : cell.inradius >= 30 ? "md" : "sm"
const clip = cell.points
  .map((p) => `${((p.x - cell.box.x) / cell.box.w * 100).toFixed(2)}% ${((p.y - cell.box.y) / cell.box.h * 100).toFixed(2)}%`)
  .join(",")
```

- [ ] **Step 3: 改标记**

```astro
<li
  class="tag-tile"
  data-tier={tier}
  data-tone={tone}
  style={`--x:${(cell.box.x / 10).toFixed(3)}%;--y:${(cell.box.y / 6.25).toFixed(3)}%;--w:${(cell.box.w / 10).toFixed(3)}%;--h:${(cell.box.h / 6.25).toFixed(3)}%;--lx:${cell.label.x.toFixed(2)}%;--ly:${cell.label.y.toFixed(2)}%;--lw:${Math.min(82, ((2 * cell.inradius * 0.95) / cell.box.w) * 100).toFixed(1)}%;clip-path:polygon(${clip})`}
>
  <a href={entry.href} aria-label={labelOf(entry)}>
    <span class="tag-tile-label">
      <span class="tag-tile-name">#{entry.tag}</span>
      <span class="tag-tile-count">{entry.total}</span>
    </span>
  </a>
</li>
```

（`box` 是 1000×625 逻辑坐标：`x/10`、`y/6.25` 得百分比；标签锚点
`cell.label` 已是相对 box 的百分比。）

- [ ] **Step 4: 改样式**

- `.tag-tile` 仍 absolute，用 `--x/--y/--w/--h`；删掉 `--tile-gap` /
  `--gap-x/y`，灰缝来自多边形内缩。
- `.tag-tile > a` 填满、`display:block`、`overflow:hidden`、
  `clip-path:polygon(...)` 来自 inline、`background`/`border-radius`
  去掉（形状由 clip）；`outline:none`（焦点环改到 li）。
- `.tag-tile-label`：绝对定位在 `--lx/--ly`，`translate(-50%,-50%)`，
  `max-width:var(--lw)`，居中列；名字省略、数量在下方；`pointer-events:none`。
- 字号：`clamp(0.7rem, 2.2cqw, 0.95rem)` 保留；`sm` 隐藏数量、字号降一档。
- `data-tone="solid"` 用 `--primary` / `--primary-foreground`。
- 悬停/焦点：li `translateY(-3px) rotate(var(--tilt)) scale(1.01,.99)`；
  li `filter: drop-shadow(...)`；`li:focus-within` 用
  `drop-shadow(0 0 0 2px var(--ring))`；兄弟 opacity `.52`。
- 入场 `tag-tile-in` / `backwards` / `--i` 保持；reduced-motion 去掉
  动画与位移。
- 容器 16/10、<640px 4/3、`container-type:inline-size` 保持。

- [ ] **Step 5: 构建 + 浏览器验证**

1. `npm run build` 通过；`dist/tags/index.html` 有 15 个
   `class="tag-tile"`，每个含 `clip-path:polygon`，默认开关未勾选；
2. playwright 打开 `/tags`，开开关：多边形铺满、细灰缝、两块墨色、标签
   在单元内；hover `astro` 看抬起/变淡；Tab 看 drop-shadow 焦点环；
3. 360 / 328 / 768 / 1280、明暗、sidebar/topbar 各一张；
4. 无 JS（临时 playwright-core 脚本或 DevTools 禁用 JS）：开关仍可切；
   reduced motion：`animationName === "none"`、hover `transform === "none"`。

- [ ] **Step 6: 只格式化组件**

Run: `npx biome format --write src/components/TagMosaic.astro`
Expected: 无错误。

### Task 3: 文档、清理与收尾

**Files:**
- Modify: `docs/components/tag-mosaic.md`
- Modify: `docs/components/README.md`
- Modify: `docs/superpowers/specs/2026-11-05-tags-mosaic-design.md`（顶部注记）
- Delete: `src/lib/treemap.ts`, `scripts/tests/treemap-check.mjs`

- [ ] **Step 1: 更新组件文档**

把「squarified / 1000×625 矩形」改成「加权 Voronoi / power diagram」；
写清：

- `layoutVoronoiTreemap` 的接口、`gap` / `seed` / `tolerance`；
- 内缩 3 逻辑单位、`clip-path`、标签在质心、按内切半径分
  `lg ≥55 / md ≥30 / sm`；
- 焦点环用 `li:focus-within` 的 drop-shadow（clip 会裁 outline）；
- 极端权重、1 个标签、长尾降级；
- 旧的 1.2% minShare 段落删除。

- [ ] **Step 2: 更新索引**

`docs/components/README.md` 的 TagMosaic 行改成：

```md
- [TagMosaic 标签瓷砖图组件](tag-mosaic.md) —— 按引用次数铺开的加权 Voronoi
  瓷砖拼贴（构建期 power diagram + clip-path 多边形，纯 CSS 开关，无客户端 JS）。
```

- [ ] **Step 3: 旧 spec 加注记**

`2026-11-05-tags-mosaic-design.md` 顶部加一行：
「布局算法已被 `2026-11-05-tags-voronoi-design.md` 取代；开关、页面与动效
约定继续沿用。」

- [ ] **Step 4: 删除旧布局**

删除 `src/lib/treemap.ts` 与 `scripts/tests/treemap-check.mjs`；确认没有
其他 import 引用。

- [ ] **Step 5: 全量检查**

```bash
node scripts/tests/voronoi-check.mjs
npm run build
npx biome format src/lib/voronoi-treemap.ts scripts/tests/voronoi-check.mjs src/components/TagMosaic.astro src/pages/tags/index.astro
```

Expected: 三条全绿（仓库级 `format:check` 的 vendored 失败不在范围内）。

- [ ] **Step 6: 最终人工验收**

按 Review Focus 逐项过：默认视图/开关、Voronoi 面积、标签不越界、
焦点/悬停、328/360/640/768/1280、明暗、sidebar/topbar、reduced motion、
无 JS。关键截图留在 `.playwright-cli/`。

- [ ] **Step 7: 不自动提交**

除非用户明确要求，否则不 `git commit`。
