# TagMosaic 标签瓷砖图组件

按引用次数把标签铺成一张**加权 Voronoi** 拼贴：面积 = 占比，单元是互不重叠的
凸多边形，砖与砖之间留细灰缝；开关打开时单元依次落下，悬停会微抬、其余单元
变淡。用于 `/tags` 的第二种视图。

## 文件位置

- 组件：`src/components/TagMosaic.astro`（构建期算布局 + SSR 标记 + scoped 样式）
- 布局：`src/lib/voronoi-treemap.ts`（`layoutVoronoiTreemap`，power diagram 纯函数）
- 回归：`scripts/tests/voronoi-check.mjs`（Node 24 直接 import `.ts`）
- 使用页：`src/pages/tags/index.astro`
- 无独立 CSS 文件；样式写在组件 `<style>` 内，继承站点令牌。

## 快速上手

组件默认 `display: none`，由继承变量 `--tags-view-mosaic` 控制显隐。最小用法：

```astro
---
import TagMosaic from "@/components/TagMosaic.astro"

const entries = [
  { tag: "astro", href: "/tags/astro", blog: 2, moments: 0, total: 2 },
]
---

<div style="--tags-view-mosaic: block">
  <TagMosaic tags={entries} />
</div>
```

`/tags` 页不直接设变量，而是在 `tags-explorer` 上用 checkbox + `:has()` 切换
`--tags-view-mosaic: none | block`，同时隐藏胶囊列表；详见「完整示例」。

## Props

| 名称 | 类型 / 取值 | 默认 | 说明 |
| - | - | - | - |
| `tags` | `TagMosaicEntry[]` | 必填 | 每个标签一条；空数组时页面不应渲染组件 |

`TagMosaicEntry` 字段：

| 字段 | 类型 | 说明 |
| - | - | - |
| `tag` | `string` | 标签名；布局的稳定 key，显示为 `#tag` |
| `href` | `string` | 点击目标，通常是 `/tags/<tag>` |
| `blog` | `number` | 该标签的博客条目数（系列只算一次，由数据源保证） |
| `moments` | `number` | 该标签的动态条目数 |
| `total` | `number` | `blog + moments`，作为面积权重与居中数量 |

组件内部按 `total` 降序、同数按 `tag` 本地化比较排序，调用方不必预排。

## 模式 / 取值详解

- **布局**：`layoutVoronoiTreemap` 在 1000×625 逻辑画布上算加权 Voronoi
  （power diagram）：每个站点用 `2(p_j − p_i)·x ≤ |p_j|² − |p_i|² + w_i − w_j`
  的半平面裁出凸单元，再迭代权重/种子把面积拟合到 `total / Σtotal`。
  固定 PRNG + 5×3 抖动网格；误差 < 0.8% 收敛，最多 400 轮。
- **单元与灰缝**：每个凸多边形按 3 逻辑单位内缩（相邻合计 6），板底透出灰缝；
  单元外轮廓不出板。极端悬殊（如 2 个标签 80:1）时小单元仍是可见的窄条，
  但目标很小，建议回列表点。
- **渲染**：每个单元一个 bBox 定位的 HTML 砖块，`clip-path: polygon()` 画形状
  （命中区域就是多边形）；标签锚点是单元质心，宽度取
  `min(82%, 2 × 内切半径 × 0.95 / bBox 宽)`。
- **分级**：按内切半径分 `lg ≥ 55`、`md ≥ 30`、其余 `sm`；`sm` 隐藏数量、
  名字字号降一档、溢出省略。15 个标签当前全部是 `lg`。
- **色调**：`data-tone="solid"` 给前 `min(3, n)` 个且 `share ≥ 8%` 的标签
  （墨色底），其余 `plain`（`--gray-4`，悬停 `--gray-5`）。
- **显隐**：`tag-mosaic { display: var(--tags-view-mosaic, none) }`；变量由页面
  下发并继承，页面 scoped 样式不需要命中子组件根元素。
- **动效**：单元执行 `tag-tile-in 460ms cubic-bezier(.22,.85,.24,1) backwards`，
  `animation-delay: calc(var(--i) * 26ms)`（`--i` 封顶 18）。悬停/焦点时单元
  `translateY(-3px) rotate(var(--tilt)) scale(1.01,.99)`，兄弟 `opacity: .52`；
  同时 clip 的 `<a>` 上播放一次性 `tag-tile-jelly 420ms`
  （`scaleX/scaleY` 1.02/.98 → .99/1.01 → 回正），给点击前一点果冻手感。
- **比例**：容器 `aspect-ratio: 16 / 10`，`<640px` 改 `4 / 3`；多边形随容器
  拉伸，面积比例保持，窗口缩放不重排。

## 无障碍与降级

- 根元素是 `role="region"` 的 `tag-mosaic`，名字「标签占比图」；内部是链接列表。
- 每块砖是一个铺满 bBox 的 `<a>`，`clip-path` 决定可点击形状；`aria-label`
  形如「#meetup，共 2 条：博客 1 篇、动态 1 条」，视觉文本由它覆盖。
- 标签放在质心，`pointer-events: none`，点击穿透到链接；键盘 Tab 按面积从大到小
  走，Enter 进入标签页。
- **焦点环**：`clip-path` 会裁掉 anchor 的 `outline`，所以 anchor `outline: none`，
  用 `.tag-tile:has(a:focus-visible)` 的**多方向 drop-shadow** 画环。注意
  `drop-shadow()` 没有 spread，写 `drop-shadow(0 0 0 2px ring)` 整条 filter 会失效。
- 隐藏的视图用 `display: none`，不进入读屏与 Tab 序；开关是原生
  `<input type="checkbox" role="switch" autocomplete="off">`，空格键切换。
- `prefers-reduced-motion: reduce` 下去掉入场、悬停位移与 `tag-tile-jelly`，
  保留颜色/变淡。
- 无 JS 时开关仍可用：显隐全部由 checkbox + CSS `:has()` 完成。
- 不持久化：首次进入与刷新必为关闭（`autocomplete="off"` 关掉 Firefox 的表单
  状态恢复）；bfcache 前进/后退仍可能恢复 checkbox，不把「回退一定关闭」当保证。

## 注意事项

- **不要给祖先加 `overflow: hidden`**：悬停单元会抬起并投阴影，祖先裁剪会切掉。
- **灰缝不是 CSS gap**：它来自多边形内缩；改 `gap` 要改
  `layoutVoronoiTreemap` 的选项，不要给 `.tag-tile` 加 padding/margin。
- **标签在质心**：不要改回左上/右下；不规则单元的四角经常不在 bBox 里，
  左上角可能落在形状外。
- **焦点环**：保留 `:has(a:focus-visible)` 的多方向 drop-shadow；`outline` 会被
  clip 裁掉，也不要写带 spread 的 drop-shadow。
- **页面选择器**：`/tags` 的胶囊列表样式收窄在 `.tags-list`；如果复制页面结构，
  别让裸 `ul` 选择器命中组件内部的列表。
- **内容量**：极端悬殊时小单元会降级为 `sm`，仍可回列表点；量级上来后再考虑
  长尾聚合。
- **文案**：页头与 aria-label 目前是中文；站点没有 `/en/tags`。若做英文页，需
  另传本地化文案（组件没有 i18n 依赖）。
- **布局函数**：`layoutVoronoiTreemap` 是纯函数、固定 seed 确定；改算法后跑
  `node scripts/tests/voronoi-check.mjs`。
- **本地 CSS 缓存**：改完组件样式后若 dev 页面还显示旧规则，重启 `astro dev`
  （Vite 偶发不刷新 scoped style），不是代码问题。

## 完整示例（/tags 页的开关）

```astro
---
import TagMosaic from "@/components/TagMosaic.astro"
import { getAllTags } from "@/lib/content"

const tags = await getAllTags()
const entries = [...tags].map(([tag, { blog, moments }]) => ({
  tag,
  href: `/tags/${tag}`,
  blog: blog.length,
  moments: moments.length,
  total: blog.length + moments.length,
}))
const totalRefs = entries.reduce((n, entry) => n + entry.total, 0)
---

<tags-explorer>
  {tags.size > 0 && (
    <div class="tags-toolbar">
      <span class="tags-legend">面积 = 被引用次数（共 {totalRefs} 次）</span>
      <label class="tags-switch">
        <span class="tags-switch-label">瓷砖视图</span>
        <input type="checkbox" role="switch" autocomplete="off" />
        <span class="tags-switch-track" aria-hidden="true">
          <span class="tags-switch-thumb" />
        </span>
      </label>
    </div>
  )}
  <ul class="tags-list">
    {[...tags].map(([tag, { blog, moments }]) => (
      <li>
        <a href={`/tags/${tag}`}>#{tag}<tag-count>{blog.length + moments.length}</tag-count></a>
      </li>
    ))}
  </ul>
  {tags.size > 0 && <TagMosaic tags={entries} />}
</tags-explorer>

<style>
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
</style>
```

开关的全部样式与工具栏细节见 `src/pages/tags/index.astro` 的 scoped `<style>`；
核心只有一句：**checkbox 选中 → 隐藏 `.tags-list` + 把 `--tags-view-mosaic`
从 `none` 改成 `block`**。
