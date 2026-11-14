# 标签页瓷砖视图设计（/tags 可切换的占比拼贴）

日期：2026-11-05
状态：已批准（2026-11-05，对话确认）
关联页面：`/tags`（中文独有，`/en` 无 tags 路由）

> 注：布局算法（squarified treemap）已被
> `2026-11-05-tags-voronoi-design.md` 取代；开关、胶囊列表、页面与动效
> 约定继续沿用。本文件保留为历史快照。

## 背景与目标

`/tags` 目前是页头 + 胶囊标签列表：标签按条目数降序，点击进入 `/tags/<tag>`。
功能完整，但除颜色和悬停外没有可玩的东西。

目标：保留现有胶囊列表作为默认视图；在页面上加一个开关，默认关闭；打开后把标签
按引用次数占比铺成一张「地板瓷砖」拼贴——面积 = 占比，砖块留缝、圆角、带实体感，
开关打开时砖块依次落下拼合，悬停时砖块微抬、其余砖块变淡。首版不做拖拽、
不做翻面卡片。

成功标准：

1. 默认进入 `/tags` 时页头内容、胶囊列表与页脚不变；唯一新增是页头下的开关工具栏；
2. 开关默认关闭，切换即时生效、无刷新、无网络请求；不写任何存储——首次进入
   与刷新都回到胶囊列表；无 JS 时开关依然可用（纯 CSS 切换）；
3. 瓷砖面积与标签引用次数成正比（长尾标签有可读性下限，见算法）；
4. 打开时砖块依次落下；悬停/键盘聚焦时砖块微抬、其余砖块变淡；点击进入标签页；
5. 明暗主题、`sidebar`/`topbar` 两种布局、360/768/1280 宽度下均可用；
6. `prefers-reduced-motion: reduce` 下无入场动画与抬升位移；
7. `node scripts/tests/treemap-check.mjs`、`npm run format:check`、`npm run build`
   通过，人工截图验收（见测试计划）。

## 范围

**覆盖：**

- `/tags` 页开关 + 瓷砖视图 + 两视图切换；
- 拼贴布局算法（构建期计算，SSR 输出百分比坐标）；
- 悬停/聚焦/入场动效与 reduced-motion 降级；
- 组件文档 `docs/components/tag-mosaic.md` 与索引。

**不覆盖：**

- 拖拽、叠放、洗牌、翻面卡片（后续可选）；
- 按 blog/moments 拆分砖面颜色或滤镜；
- `/en/tags` 路由；
- 标签数据、标签详情页、胶囊列表样式；
- 开关状态持久化（`localStorage` / URL 参数）。

## 设计决策

| # | 决策点 | 结论 |
| - | - | - |
| 1 | 目标 | 主要让标签页更好玩，占比是给拼贴提供形状的数据，不追求图表精度 |
| 2 | 切换方式 | 页内开关，即时切换；默认关闭；不持久化 |
| 3 | 实现路线 | 构建期算 squarified treemap，SSR 输出百分比坐标；纯 CSS 切视图与动效，零客户端布局 JS |
| 4 | 视觉方向 | 中性灰瓷砖 + 少量墨色大砖；灰缝即页面底色；圆角 + 轻微材质 |
| 5 | 玩点 | 依次落下拼合 + 悬停微抬/微倾 + 兄弟砖块变淡 |
| 6 | 点击行为 | 整块砖是链接，进入 `/tags/<tag>`，与胶囊一致 |
| 7 | 长尾处理 | 权重下限 1.2% 后再归一化，避免极小砖不可点；比例对大砖近似、对小砖封顶 |
| 8 | 移动端 | 全端可用；窄屏容器比例 4/3，砖块自动拉伸，面积比例不变 |
| 9 | 无障碍 | 原生 checkbox + `role="switch"`；两视图只显示一个（`display:none` 移除出 AT 与 Tab 序）；砖块可键盘聚焦 |
| 10 | 跨组件显隐 | 组件根 `tag-mosaic` 的显隐用页面下发的 CSS 变量控制，避免页面 scoped 样式够不到子组件根元素 |

## 已考虑的替代方案

- **A. SSR 百分比坐标 + CSS 切换（采用）**：布局在构建期算好，砖块用 `left/top/
  width/height` 百分比定位，容器固定比例。无客户端 JS，无重排时机问题；窗口缩放
  时面积比例天然保持。缺点是容器比例变化时砖块形状会被轻微拉伸。
- **B. 客户端 ResizeObserver 重排**：按实际宽度算布局、可做最小砖尺寸与更优形状。
  缺点是瓷砖无法 SSR、首次打开有布局跳动、多一套 JS 与测试面；对 15 个标签的
  当前体量收益很小。未采用。
- **C. 可拖拽的砖（收藏板手感）**：更好玩，但拖拽与点击冲突、触屏和键盘退化成本高，
  也会与收藏板的身份重复。未采用。
- **D. 点击翻面展示最近文章**：信息更丰富，但多一步才到标签页，小砖放不下翻面内容，
  还要额外传最近条目。未采用。

## 数据与布局算法

### 数据

- 来源：`getAllTags()`（blog 系列只算一次 + moments 合并），页面在 frontmatter 里
  生成 `TagMosaic` 的入参。
- 每个标签的 `total = blog.length + moments.length`；`sum = Σ total` 是该页
  「引用次数」总和，一个多标签条目会为每个标签各贡献一次，因此 `sum` 可大于
  文章总数；页头开关旁的说明文案写「共 N 次引用」，不写「N 篇文章」。
- 排序沿用 `getAllTags()`：`total` 降序，同数按 `localeCompare`；布局与胶囊列表
  顺序一致。

### squarified treemap

`src/lib/treemap.ts` 新增纯函数：

```ts
type TreemapItem = { key: string; weight: number }
type TreemapRect = { key: string; x: number; y: number; w: number; h: number }

export function layoutTreemap(
  items: TreemapItem[],
  size: { width: number; height: number },
  options?: { minShare?: number },
): TreemapRect[]
```

- 权重先按 `minShare`（默认 `0.012`）封底再归一化；`minShare` 为 0 或未传时严格
  按原始权重。`Σ weight === 0` 时返回空数组，避免除零。
- 画布固定 1000×625 逻辑单位（16:10）；返回百分比坐标（`x / 1000 * 100` 等），
  保留 4 位小数。
- 用标准 squarified 算法：按权重降序，沿矩形短边铺行，行内最优长宽比；剩余
  空间递归。所有 rect 之和恰好铺满画布（允许浮点误差）。
- 返回顺序 = 布局顺序（权重降序）；调用方也可靠 `key` 映射回条目。
- 空输入返回空数组。布局纯函数、无 DOM 依赖、顺序确定。

页面 frontmatter 组装：

```ts
const entries = [...tags].map(([tag, { blog, moments }]) => ({
  tag,
  blog: blog.length,
  moments: moments.length,
  total: blog.length + moments.length,
  href: `/tags/${tag}`,
}))
const totalRefs = entries.reduce((n, e) => n + e.total, 0)
```

`totalRefs` 只给工具栏图例用；布局在 `TagMosaic.astro` 内部计算（它自己拿到
`entries` 后调用 `layoutTreemap`），页面不重复算。

### 砖块分级

按布局矩形短边（逻辑单位）分级，供字号与信息密度降级用：

- `lg`：短边 ≥ 120
- `md`：短边 ≥ 70
- `sm`：短边 < 70（隐藏数量，只留标签名，超出省略）

15 个标签时全部为 `lg` 左右（5.9% ≈ 192×192 逻辑单位），分级只在内容增长后生效。

## 组件与 DOM

### 文件与职责

| 文件 | 动作 | 职责 |
| - | - | - |
| `src/lib/treemap.ts` | 新增 | squarified 布局纯函数与百分比换算 |
| `scripts/tests/treemap-check.mjs` | 新增 | 布局纯函数的 node 断言（Node 24 直接 import `.ts`） |
| `src/components/TagMosaic.astro` | 新增 | 接收标签条目，算布局，SSR 输出 `tag-mosaic` 瓷砖图 |
| `src/pages/tags/index.astro` | 修改 | 外包 `tags-explorer`，加开关工具栏；保留原胶囊列表；引入 `TagMosaic` |
| `docs/components/tag-mosaic.md` | 新增 | 组件用法（按 `docs/components/README.md` 的八节结构） |
| `docs/components/README.md` | 修改 | 索引补一行 |

不新增客户端脚本；开关与显隐全部由原生 checkbox + CSS `:has()` 实现。

### 页面结构

```html
<tags-explorer>
  <div class="tags-toolbar">
    <span class="tags-legend">
      面积 = 被引用次数（共 17 次）
    </span>
    <label class="tags-switch">
      <span class="tags-switch-label">瓷砖视图</span>
      <input type="checkbox" role="switch" />
      <span class="tags-switch-track" aria-hidden="true">
        <span class="tags-switch-thumb"></span>
      </span>
    </label>
  </div>

  <ul class="tags-list">…现有胶囊（原样保留）…</ul>

  <TagMosaic tags={entries} />
</tags-explorer>
```

工具栏：`display: flex; align-items: center; justify-content: space-between;
gap: var(--space-s); margin-bottom: var(--space-m)`。图例用 mono、`--step--1 - 1px`、
`--muted-foreground`；**未开启瓷砖视图时 `visibility: hidden; opacity: 0`**，只占位
不显示，避免工具栏高度跳动。

> 注意：现有页面的 `ul` / `a` 是裸元素选择器。新增瓷砖的 `<ul>` 会被误伤，必须把
> 胶囊列表的选择器收窄为 `.tags-list`（声明原样保留），瓷砖内部样式只写在
> `TagMosaic.astro` 内。

`TagMosaic.astro` 输出：

```html
<tag-mosaic role="region" aria-label="标签占比图">
  <ul>
    <li
      class="tag-tile"
      data-tier="lg"
      data-tone="solid"
      style="--x:0%;--y:0%;--w:23.1%;--h:36.2%;--i:0;--tilt:-0.35deg"
    >
      <a href="/tags/astro" aria-label="#astro，共 2 条：博客 2 篇">
        <span class="tag-tile-name">#astro</span>
        <span class="tag-tile-count">2</span>
      </a>
    </li>
    …
  </ul>
</tag-mosaic>
```

- `--i`：入场延迟序号，按 `total` 降序，封顶 18，避免大数量时等待过长。
- `--tilt`：±0.35deg 交替，给悬停一点手摆感。
- `data-tone="solid"`：前 `min(3, n)` 大且 share ≥ 8% 的砖（15 个标签时是 astro、
  blog 两块）；其余 `plain`。阈值写进组件常量，便于调整。
- 若标签数为 0：不渲染开关与 `tag-mosaic`，保持现有空状态。

### 视图切换 CSS

```css
/* 页面 scoped 样式（只负责胶囊列表与变量） */
tags-explorer { display: block; --tags-view-mosaic: none; }
tags-explorer:has(.tags-switch input:checked) .tags-list { display: none; }
tags-explorer:has(.tags-switch input:checked) { --tags-view-mosaic: block; }
tags-explorer:has(.tags-switch input:checked) .tags-legend {
  visibility: visible;
  opacity: 1;
}

/* TagMosaic.astro 内部 scoped 样式 */
tag-mosaic { display: var(--tags-view-mosaic, none); }
```

用继承的 CSS 变量把「显示」下发给子组件根元素：页面 scoped 样式命中不了子组件
DOM，这样避免在页面里写 `is:global`。`<tags-explorer>` 默认 `--tags-view-mosaic:
none`。无 JS 也可切换；关闭页面状态自然丢弃，满足「默认关闭」。

## 视觉规格

- 容器：`border: 1px solid var(--border)`、`border-radius: var(--radius-2xl)`、
  `background: var(--background)`（灰缝即页面底色）、`aspect-ratio: 16 / 10`；
  `<640px` 改为 `4 / 3`。`container-type: inline-size` 供字号用 `cqw`。
- 灰缝：`--tile-gap: 8px`（<640px 为 `6px`）。每块 `left: calc(var(--x) + gap/2)`、
  `width: calc(var(--w) - gap)`，四周留缝约半格，圆角处不贴边。极小砖的灰缝
  按 `min(gap, 30% 砖宽/高)` 收缩，避免长尾砖被固定灰缝吃成 0 宽。
- 砖面：`plain` 用 `--gray-4`，悬停 `--gray-5`；`solid` 用 `--primary` 底、
  `--primary-foreground` 字。两层都有 `inset 0 1px 0` 的顶部高光与 `--radius-lg`。
  `tag-mosaic` 内的 `<ul>` 显式 `margin: 0; padding: 0; list-style: none`，清掉
  typography 的列表默认样式。
- 字：标签名 `font-weight: 500`，`clamp(0.7rem, 2.2cqw, 0.95rem)`，单行省略；
  数量用 `--font-mono`，`0.8em`，`opacity: .6`，贴右下。`sm` 隐藏数量、减小内边距。
- 墨色大砖最多 3 块，保证画面有锚点但不喧宾夺主。
- 容器不设 `overflow: hidden`，避免裁掉悬停阴影；砖块本身不会越界。
- 开关：轨道 `2.25rem × 1.25rem`、`border-radius: var(--radius-full)`、
  底 `var(--muted)`、边 `1px solid var(--border)`；滑块 `1rem` 圆点，关闭时贴左、
  开启时 `translateX(1rem)` 且轨道底换成 `var(--accent)`。标签文案 mono、
  `var(--step--1)`、`var(--muted-foreground)`；悬停变 `var(--foreground)`。
  原生输入框用裁剪式视觉隐藏（不能 `display: none`，否则不可聚焦）；
  `input:focus-visible + .tags-switch-track` 画 `2px solid var(--ring)` 焦点环。

## 交互与动效

- 入场：`tag-mosaic` 从 `display:none` 变为可见时，砖块执行
  `tile-in 460ms cubic-bezier(.22,.85,.24,1) backwards`，
  从 `opacity:0; translateY(10px) scale(.96)` 落到位；
  `animation-delay: calc(var(--i) * 26ms)`。关掉再开可重播（display 重置动画）。
  用 `backwards` 而不是 `both`：`forwards` 会一直占用 `transform`，吞掉悬停位移。
- 悬停/聚焦：砖块 `translateY(-3px) rotate(var(--tilt))`，`z-index: 2`，加柔和阴影；
  其余砖块 `opacity: .52`。选择器用
  `tag-mosaic:has(.tag-tile a:hover) .tag-tile:not(:has(a:hover))`，
  focus-visible 同理。触屏无 hover，保持静止。
- 焦点：整块 `<a>` 铺满砖面，`outline: 2px solid var(--ring); outline-offset: -3px`，
  避免焦点环被邻砖压住。
- `prefers-reduced-motion: reduce`：去掉入场动画与位移，保留颜色/透明度变化。
- 点击与键盘 Enter 均进入标签页；Tab 顺序 = 面积降序。

## 响应式与布局兼容

- `sidebar` 布局下容器约 `--measure`（40rem）；`topbar` 下随内容列变宽。
  两种布局都用同一份百分比坐标，面积比例不变。
- `<640px`：容器 4/3，字号随 `cqw` 缩小，页头插图照旧隐藏；`lg/md/sm` 分级与
  桌面一致（按逻辑单位算）。
- 窗口缩放不重排，砖块形状随容器比例轻微拉伸；这是 SSR 方案的已知取舍。

## 无障碍与降级

- 开关：原生 `<input type="checkbox" role="switch" autocomplete="off">`，
  `<label>` 文案「瓷砖视图」；焦点环画在轨道上；空格键原生切换（checkbox 的
  Enter 不是切换键）。
- 默认视图与瓷砖视图只显示一个；隐藏侧用 `display:none`，不进入读屏与 Tab 序。
- 每块砖的 `aria-label` 形如「#astro，共 2 条：博客 2 篇」；同时有动态时写
  「#meetup，共 2 条：博客 1 篇、动态 1 条」，数量与拆分来自数据；视觉上的
  `#tag` 与数字由 `aria-label` 覆盖，不重复朗读。
- 无 JS：开关照常工作（纯 CSS）；`display:none` 的视图不占 Tab 序。
- 页面仍为 `noindex`，不新增 SEO 面。

## 测试与验证

1. `node scripts/tests/treemap-check.mjs`、`npm run format:check`、`npm run build`
   通过；
2. `npm run dev` 后人工检查 `/tags`：
   - 默认视图与改动前一致（截图对比）；
   - 开关打开：瓷砖铺满、面积与占比一致、入场依次落下；
   - 悬停微抬/微倾、其余砖变淡；点击进入标签页；返回后默认关闭；
   - Tab 到开关与砖块，焦点可见，Enter 可进；
   - 明暗主题、360/768/1280、`sidebar`/`topbar` 各一组截图；
   - DevTools 模拟 `prefers-reduced-motion: reduce`：无入场位移；
3. 布局算法用 `scripts/tests/treemap-check.mjs` 回归（Node 24 直接 import
   `src/lib/treemap.ts`）：铺满、顺序、边界、空输入、零权重、minShare 封底；
   纯 CSS 显隐与视觉动效仍以人工截图验收。

## 风险与已知限制

- 标签数量很大时（约 100+），1.2% 下限会让占比失真，砖块也会接近最小可读尺寸；
  当前 15 个标签不受影响。内容量到量级后再考虑分页、聚合或客户端重排。
- 固定比例容器在极窄或极宽时砖块形状会被拉伸；面积比例不变。
- 墨色大砖的阈值（前 3、share ≥ 8%）是视觉参数，可单独调整，不影响布局。
- 纯 CSS 开关不写存储；Firefox 的刷新表单状态恢复由 `autocomplete="off"` 关闭；
  浏览器前进/后退（bfcache）仍可能恢复表单控件状态，因此「回退到本页一定关闭」
  不在保证范围内——首次进入与刷新一定关闭。
- 极端 2 标签悬殊（如 80:1）时，灰缝收缩后小砖仍能显示但目标很窄；建议回列表
  点击，量级上来后再做长尾聚合。
