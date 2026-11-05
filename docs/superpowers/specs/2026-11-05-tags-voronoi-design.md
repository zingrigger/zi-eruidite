# 标签页 Voronoi 瓷砖视图设计（替换矩形 treemap）

日期：2026-11-05
状态：已批准（2026-11-05，用户选 A 后确认）
关联页面：`/tags`（中文独有）
前置设计：`2026-11-05-tags-mosaic-design.md`（开关、胶囊列表、动效与无 JS 约定继续沿用）

## 背景与目标

第一版瓷砖视图用 squarified treemap：每块砖是矩形，圆角 + 灰缝。你给了
Kanso 的磁盘占比图和一张加权 Voronoi treemap 参考图，并在样张中选了
**A · Voronoi 锐边**。

目标：把瓷砖视图的布局从「矩形 treemap」换成**真正的加权 Voronoi
treemap**——每块砖是不规则凸多边形，面积按标签引用次数拟合，单元格铺满
整块板，砖与砖之间留细灰缝；默认胶囊列表、开关、悬停/落砖/键盘/无 JS
等既有行为全部保留。

成功标准：

1. Voronoi 单元是凸多边形，面积与 `total / Σtotal` 的误差 ≤ 1%（当前
   15 个标签；极端权重允许放宽到 3%），单元铺满板、不重叠；
2. 灰缝细而均匀（逻辑画布 1000×625 上 6 单位，约板宽的 0.6%）；单元外扩
   前的外轮廓不出板；
3. 标签名与数量落在单元内部（以单元质心为标签锚点，宽度按内切半径收），
   小单元自动降级为 `md/sm`；当前 15 个标签全部可读；
4. 默认视图、开关、纯 CSS 切换、不持久化、`autocomplete="off"`、明暗主题、
   360 / 328 / 1280、`sidebar`/`topbar`、悬停微抬 + 兄弟变淡、键盘焦点、
   无 JS、reduced-motion 全部保持；
5. `node scripts/tests/voronoi-check.mjs`、`npm run build`、改动文件
   targeted Biome check 通过；人工截图验收。

## 范围

**覆盖：**

- 用 `src/lib/voronoi-treemap.ts` 替换 `src/lib/treemap.ts`；
- `TagMosaic.astro` 的砖块几何、标签定位、焦点环与灰缝；
- `scripts/tests/voronoi-check.mjs` 替换 `treemap-check.mjs`；
- 组件文档、索引、spec/plan 文档同步。

**不覆盖：**

- 软角 / 果冻圆角（样张 B，未选）；
- 拖拽、翻面、聚合长尾；
- `/en/tags`、标签数据、胶囊列表、标签详情页；
- 开关状态持久化。

## 设计决策

| # | 决策点 | 结论 |
| - | - | - |
| 1 | 外观 | 用户选 **A · Voronoi 锐边**：直线多边形、细灰缝；不做圆角 |
| 2 | 算法 | 加权 Voronoi（power diagram）+ 迭代权重/种子拟合面积，构建期算 |
| 3 | 渲染 | 每个单元一个 HTML 砖块：bBox 定位 + `clip-path: polygon()`；不用 SVG 承载 |
| 4 | 灰缝 | 凸多边形内缩 3 逻辑单位（相邻合计 6），板底透出 |
| 5 | 标签 | 单元质心为锚点；宽度取 `2 × 内切半径 × 0.95`；按内切半径分 `lg ≥55 / md ≥30 / sm` |
| 6 | 焦点环 | `li:focus-within` 的 `drop-shadow(0 0 0 2px ring)`，避免 clip-path 裁掉 anchor 的 outline |
| 7 | 面积拟合 | `w += 0.45 × (target − area)`；每轮权重去均值；种子向质心走 0.18；停止阈值 0.8% 或 400 轮 |
| 8 | 确定性 | 固定 PRNG + 5×3 抖动网格；同一输入两次结果一致 |
| 9 | 降级 | 1 个标签时整板一块；空输入返回空；单元内缩塌陷时跳过该单元并保留一份未内缩轮廓 |

## 已考虑的替代方案

- **A. 加权 Voronoi + 锐边（采用）**：与参考图同款；面积可拟合；标签用质心；
  凸多边形内缩简单，灰缝均匀。
- **B. Voronoi + 软角**：在 A 上把顶点倒成小圆角，更像果冻；需要 SVG
  `clipPath`（objectBoundingBox）或更多顶点，标签可用面积更小。用户未选。
- **C. 保持矩形 treemap**：现有实现，风险最低，但不是用户想要的形状。

## 数据与算法

### 输入

- 沿用 `getAllTags()`：每个标签 `total = blog.length + moments.length`，
  排序、solid 阈值（前 3 且 share ≥ 8%）沿用第一版。
- 画布 1000×625；目标面积 `target_i = share_i × 1000 × 625`。

### 加权 Voronoi（power diagram）

单元 i 是满足下列条件的点集（容器为 1000×625 矩形）：

```
|x − p_i|² − w_i ≤ |x − p_j|² − w_j   (∀ j ≠ i)
```

展开成半平面：

```
2(p_j − p_i)·x ≤ |p_j|² − |p_i|² + w_i − w_j
```

对每个站点用 Sutherland–Hodgman 依次裁容器多边形；n=15 时每轮约 210 次
裁切，成本可忽略。所有单元是凸多边形，互不重叠，铺满容器。

### 拟合

1. 初始种子：5×3 网格 + 固定 PRNG 抖动 ±90/±70；权重
   `w_i = target_i × 0.35`。
2. 每轮：算单元 → 面积/质心 → `w_i += 0.45 × (target_i − area_i)`；
   空单元额外 `w_i += target_i × 0.8` 并把种子拉向板中心；非空单元种子
   向质心走 0.18；权重减去均值（power diagram 对整体平移不变）。
3. 直到最大相对面积误差 < 0.8% 或 400 轮；保留最后一轮。
4. 当前 15 个标签的实测：最大相对误差 0.55%，最小单元面积 36,563
   逻辑单位²，迭代收敛。测试会把该结果钉住。

### 内缩与输出

- 对每个凸多边形按 3 逻辑单位内缩（相邻各让 3 → 6 单位灰缝）。
- 输出：

```ts
type VoronoiCell = {
  key: string
  points: { x: number; y: number }[] // 内缩后的逻辑坐标
  box: { x: number; y: number; w: number; h: number }
  label: { x: number; y: number } // 质心，相对 box 的百分比
  inradius: number
}
```

- 内缩塌陷（面积 ≤0 或点数 <3）时跳过该单元；1 个标签时整板一块。
- 归一化后写进砖块：`--x/--y/--w/--h`（box 占板百分比）、
  `--lx/--ly`（标签锚点）、`--lw`（标签最大宽度）、
  `clip-path: polygon(<box 内百分比点>)`。

## 组件与页面

### TagMosaic.astro

- frontmatter：`layoutVoronoiTreemap(entries, {width:1000,height:625})`；
  每个 cell 算 `tier`、`tone`、`--i`、`--tilt`、标签宽度。
- 标记：

```html
<li class="tag-tile" data-tier="lg" data-tone="solid"
    style="--x:…;--y:…;--w:…;--h:…;--lx:…;--ly:…;--lw:…;
           clip-path:polygon(…%)">
  <a href="/tags/astro" aria-label="#astro，共 2 条：动态 2 条">
    <span class="tag-tile-label">
      <span class="tag-tile-name">#astro</span>
      <span class="tag-tile-count">2</span>
    </span>
  </a>
</li>
```

- 砖块 `position:absolute` 用 box；anchor 填满；`clip-path` 在 anchor 上
  （命中区域 = 多边形）；label 绝对定位在质心，`translate(-50%,-50%)`，
  `max-width: var(--lw)`，`pointer-events:none`（仍属于链接）。
- 标签文本居中（不再左上 / 右下）；`sm` 隐藏数量；名字溢出省略。
- 砖面：`plain` `--gray-4`、悬停 `--gray-5`；`solid` `--primary` /
  `--primary-foreground`；保留顶部 1px 高光（会被 clip 裁到形状内）。
- 悬停/聚焦：`li` 上 `translateY(-3px) rotate(var(--tilt)) scale(1.01,.99)`，
  `filter: drop-shadow(...)`；兄弟 `opacity: .52`；焦点用
  `li:focus-within { filter: drop-shadow(0 0 0 2px var(--ring)) }`。
- 入场：`tag-tile-in` 保持，`animation-delay: calc(var(--i) * 26ms)`；
  形状随 clip 一起落下。

### 页面

- `/tags` 的 `tags-explorer`、开关、图例、`.tags-list`、`autocomplete`
  全部不动；只替换 `TagMosaic` 的内部布局与标签排版。
- 灰缝颜色仍是页面底色；容器仍 16/10（<640px 4/3），百分比坐标随容器
  拉伸，面积比例保持。

## 无障碍与降级

- 每块砖仍是 `<a>`，`aria-label` 不变；命中区域是多边形；键盘 Tab/Enter
  不变；焦点环用 `li:focus-within` 的 drop-shadow（clip-path 会裁 anchor
  outline）。
- 标签锚点在凸单元质心（内部）；宽度按内切半径，文本不越出单元。
- `prefers-reduced-motion: reduce` 去掉入场/位移，保留颜色与变淡。
- 无 JS、默认关闭、不持久化、`autocomplete="off"` 的约定全部沿用。

## 测试与验证

1. `node scripts/tests/voronoi-check.mjs`：
   - 15 个等权 → 15 个单元、面积各 1/15 ±1%、总面积 = 画布；
   - 当前权重 2/2/1×13 → 面积误差 ≤1%，两块约 2 倍；
   - 1 个 / 2 个 / 空 / 零权重；所有点 0..1000/0..625；凸性；无 NaN；
   - 同一输入两次运行坐标完全一致；
   - 内缩后每个单元面积 >0、点在板内。
2. `npm run build`；改动文件 targeted Biome check；
3. 人工：/tags 默认胶囊、开关、Voronoi 铺满、细灰缝、两块墨色、标签在
   单元内、悬停/焦点/Enter、360/328/1280、明暗、sidebar/topbar、
   reduced-motion、无 JS 截图。
4. 删除旧的 `src/lib/treemap.ts` 与 `scripts/tests/treemap-check.mjs`；
   组件文档与 README 索引改成 Voronoi；旧 spec/plan 保留为历史快照。

## 风险与已知限制

- 权重极悬殊时 power diagram 可能让某单元被挤空；迭代有空单元恢复，但仍
  需测试兜底（当前数据不触发）。
- 内缩会让小单元变小；当前最小单元面积 36,563，安全；内容量很大时仍需
  长尾聚合（不在本期）。
- 多边形标签的宽度按内切半径估计；极细长单元的标签会降级为 `sm`。
- 布局随机种子固定；新增/删除标签会整体重排；这是构建期一次性结果。
- Voronoi 单元是凸多边形；如果以后要「凹」的有机形状，需要另做轮廓生成，
  不在本期。
