# BoardIndex 玩具柜列表与展品子页

## 1. 一句话说明

`/board` 是「玩具柜」列表页：只给入口与一句说明，点进去才加载那件展品。
四个展品子页（`/board/<slug>` 与 `/en/board/<slug>`）由一份登记驱动，
本页也负责把子页套上统一的页面外壳（crumbs、meta、语言孪生）。

## 2. 文件位置

- 列表页组件：`src/components/BoardIndex.astro`（自主元素无脚本，纯 SSR）
- 子页外壳：`src/components/BoardExhibit.astro`（按 slug 选一个 Exhibit 并套 `Layout` + `MetaPage`）
- 展品包装：`src/components/exhibits/StampsExhibit.astro`、`LenticularExhibit.astro`、
  `TicketsExhibit.astro`、`BirdsExhibit.astro`
- 登记：`src/data/board-sections.ts`（`BOARD_SECTIONS`，顺序即列表顺序）
- 路由薄壳：`src/pages/board/index.astro`、`src/pages/en/board/index.astro`、
  `src/pages/board/[slug].astro`、`src/pages/en/board/[slug].astro`
- 文案：`src/lib/i18n.ts` 的 `UI_STRINGS`（条目名与说明都只存 key）
- 样式：写在各组件的 scoped `<style>` 里，无全局 CSS 文件
- 回归：`scripts/tests/board-check.sh`（列表 + 四子页 + 脚本隔离）、
  `scripts/tests/i18n-check.sh`（子页中英孪生与切换器）

## 3. 路由表

| 中文 | 英文 | 内容 | 展品组件 |
| --- | --- | --- | --- |
| `/board` | `/en/board` | 玩具柜列表 | — |
| `/board/stamps` | `/en/board/stamps` | 邮票和拼贴 | `Board.astro` |
| `/board/lenticular-card` | `/en/board/lenticular-card` | 光栅卡 | `LenticularSection.astro` |
| `/board/tickets` | `/en/board/tickets` | 票券 | `TicketSection.astro` |
| `/board/birds` | `/en/board/birds` | 鸟类收藏板 | `BirdBoard.astro` |

slug 一律小写、多词用连字符（与 `/tags`、`/figures`、`/authors` 一致）。
`getStaticPaths` 从 `BOARD_SECTIONS` 派生，未登记的 slug 直接落站点 404。

## 4. Props

`BoardIndex.astro`：

| 名称 | 类型 | 说明 |
| --- | --- | --- |
| `locale` | `Locale`（`"zh" \| "en"`） | 决定文案与 `href` 前缀 |

`BoardExhibit.astro`：

| 名称 | 类型 | 说明 |
| --- | --- | --- |
| `slug` | `string` | 必须是 `BOARD_SECTIONS` 里已登记的 slug |
| `locale` | `Locale` | 同上 |

四个 Exhibit 组件的 props 均为 `{ locale: Locale }`；它们各自渲染
`ListingHead`（页头）+ 对应展品组件 + 只属于该展品的附注。

`BoardSection` 字段（`src/data/board-sections.ts`）：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `slug` | `string` | 路由段，也是 `EXHIBITS` 映射的键 |
| `titleKey` | `UIKey` | 条目与子页标题的文案 key |
| `descKey` | `UIKey` | 条目与子页说明的文案 key |
| `wideOnly` | `boolean?` | 宽屏才摆得开；只有 `stamps` 为 `true` |

## 5. 加第五件展品

1. `src/lib/i18n.ts`：在 `ZH_STRINGS` 与 `en` 字典各补一对文案 key（如
   `globesTitle` / `globesDesc`），两份都写，缺一份构建期 `Record<UIKey, string>` 就报错。
2. `src/data/board-sections.ts`：追加一条登记，位置即列表里的位置。
3. `src/components/exhibits/GlobesExhibit.astro`：新写一个 Exhibit，props `{ locale }`，
   结构 = `ListingHead` + 展品组件 + 附注（没有附注就不写）。
4. `src/components/BoardExhibit.astro`：import 它并在 `EXHIBITS` 里加一行 `"globes": GlobesExhibit`。

中英文两个 `[slug].astro` 与两个 `index.astro` 都不用改。列表与子页的标题、说明、
`MetaPage alternates`、面包屑、语言切换器全部随登记自动出现。

## 6. 无障碍与降级

- 列表页是 `<ul>` + `<a>`，无脚本；`ListingHead` 的 `drawer` 插图带
  `figureLabel`（`boardFigureLabel`，双语）作为无障碍名称。
- 子页都有 crumbs 回 `/board`（`Layout` 的 `crumbs`，`SiteBar` 已支持），
  以及 `MetaPage alternates` 指回中英孪生。
- 无 JS 时列表与子页的静态内容照常可读；展品自身的降级见
  [Board](./board.md)、[BirdBoard](./bird-board.md) 等各自文档。

### 窄屏语义（`< 64rem`）

手机导航仍不出现「玩具柜」入口（`src/consts.ts` 的 `NAVIGATION` 里
`mobileHidden: true`，本次未动）。但 URL 会被分享、被书签、被搜索引擎给出，
所以窄屏不白屏：

- 列表页：`wideOnly` 的条目（目前只有 `stamps`）由 `BoardIndex` 的 scoped 规则
  `li[data-wide-only] { display: none }` 藏掉，其余三条照常显示。
- `/board/stamps`：`StampsExhibit` 把 `<Board>` 包在 `<div data-wide-only>` 里，
  窄屏收起板、显示一句 `boardWideOnly`（「这件展品需要宽屏才能摆开，请在电脑上打开。」），
  页头与参考链接仍在。
- 其余三件展品今天在手机上就是可用的，不隐藏。

隐藏标记用 `data-wide-only`，**不要**复用 `data-mobile-hidden`：后者是导航专用标记，
`board-check.sh` 靠 grep 它定位导航 CSS，混用会削弱那条断言的精度。

## 7. 注意事项

- **列表页不许背上任何展品**。这是本次拆页要解决的原始毛病：列表只应给出链接与文字。
  `board-check.sh` 末尾的「列表页不背任何展品」组对此有产物级断言
  （`<stamp-board` / `<bird-board` / `<lenticular-card` / `<ticket-collage` 四类 markup、
  四件展品各自的脚本 token、展品图片 `DONGLONGDONG` 全部不得出现）。
- **脚本隔离靠 Astro 只带已渲染组件的脚本**。`BoardExhibit` 同时 import 四个 Exhibit，
  实测每个子页只引入自己那件的脚本加共用外壳（`Layout` / `SiteBar` / `EyeTracker`）。
  方案 A 就建在这条上，故 `board-check.sh` 有「子页只背自己的脚本」断言钉住：每件先正向钉
  「本页带上了自己的脚本」，再反向钉「不带其余三件」。断言单位是组件脚本里的字面量，不是
  chunk 文件名——Astro 是否把脚本提成 chunk 取决于模块图（实测少一个共用 import 就会变回
  内联），按文件名断言会在图形变化时假失败。另注意脚本挂在真正含 `<script>` 的组件上：
  光栅卡是 `LenticularCard.astro`，`LenticularSection` 自己不出脚本。
- **样式不隔离，这是选方案 A 的代价**。Astro 按模块图合并 CSS：`BoardExhibit` 静态
  import 四个 Exhibit，产出的 `BoardExhibit.*.css` 就是四件样式的并集，四个子页共用这一份
  （实测约 27.7 KB 原始 / 4.8 KB gzip）。也就是说脚本按渲染隔离、样式按模块图合并，
  上一条不构成「子页只背自己的一切」。要真隔离只能改回每页各自 import（spec 的方案 B），
  代价是中英文各写一遍、加展品要改三处——spec 已权衡过，别顺手推翻。
- **不要建 `src/components/exhibits/index.ts`**：本仓 `astro/client` 没有
  `declare module '*.astro'`，从 `.ts` import `.astro` 会是 TS2307。映射必须留在
  `BoardExhibit.astro` 的 frontmatter 里（Astro 原生处理 `.astro` import）。
  这是**类型**问题，不是隔离问题：实测把映射挪进 `.ts` 再构建，四个子页仍各自只带自己
  那件的脚本——脚本传播跟着渲染走，跟 import 写在哪个文件里无关。别拿隔离当理由。
- **附注跟着展品走**：邮票板的参考链接与 SVG 署名在 `StampsExhibit`，鸟板的授权署名
  （PolyForm Shield 1.0.0 / MIT / IOC CC BY 3.0 / AVONET CC BY 4.0）在 `BirdsExhibit`，
  两种语言都渲染。改这两段前先看许可要求。
- **语言切换器无需改动**：`src/components/LanguageSwitch.astro` 已按 `/board/` 前缀放行，
  新 slug 自动获得切换器——前提是中英孪生页都存在，否则点了就 404。
- **计数不写死在登记里**：`BoardIndex` 从 `getBoardViews` / `getBirdViews` 现算，
  光栅卡与票券没有自然计数就省略。
- **kicker 用英文单位**（`~/board · 4 exhibits`），与 `src/pages/blog/index.astro`
  的 `posts` 同款；`~/board/<slug>` 是子页页头的路径串。

## 8. 完整示例

```astro
---
// src/pages/board/index.astro —— 列表页薄壳
import BoardIndex from "@/components/BoardIndex.astro"
---

<BoardIndex locale="zh" />
```

```astro
---
// src/pages/board/[slug].astro —— 子页薄壳，加展品不必改这里
import BoardExhibit from "@/components/BoardExhibit.astro"
import { BOARD_SECTIONS } from "@/data/board-sections"

export function getStaticPaths() {
  return BOARD_SECTIONS.map(({ slug }) => ({
    params: { slug },
    props: { slug },
  }))
}

const { slug } = Astro.props
---

<BoardExhibit slug={slug} locale="zh" />
```
