# /board 拆成列表 + 展品子页

日期：2026-11-08
状态：已批准（命名于同日定稿）

## 意图与为什么

`/board` 现在一页堆了四件东西（邮票拼贴板、光栅卡、票券、鸟类收藏板），内容过载。
这块地已经变成作者「试验自己喜欢的东西」的 lab，后面还会继续往里加。改成 `/blog`
那样的形状：列表页只给入口，点进去才加载那件东西。

## 目标

- `/board` 成为列表页，视觉语言照 `/blog`：`ListingHead` + 一列条目卡片。
- 四件东西各有子页，中英各一套，共 8 个详情路由。
- 加第五件的成本 = 一条数据 + 一个 Exhibit 组件，中英文自动都有。
- 消除现在 `board/index.astro` 与 `en/board/index.astro` 两份几乎重复的页面。
- 只属于某件东西的附注跟着它走：邮票板的参考链接、鸟板的授权署名。

## 非目标

- 不放开手机端。
- 不给子页写长文，页头一句说明足够。
- 不做列表缩略图。
- 不改四件东西本身的组件行为（`Board` / `LenticularSection` / `TicketSection` /
  `BirdBoard` 内部不动）。
- 不做搜索、筛选、排序、持久化。

## 反目标（技术上跑通也算失败）

- 列表页把四件东西的脚本与资源又全加载回来——那正是本次要解决的毛病。
- 加第五件还要改中英文两处页面文件。
- 子页在手机上白屏。
- 鸟板授权署名在搬迁中丢失。

## 约束

- 无 UI 框架、无 CSS 框架；自主定制元素 + Utopia 流体令牌 + Radix `light-dark()`。
- 每个子页必须有 `/en/board/<同 slug>` 孪生页，否则语言切换器 404。
  `LanguageSwitch.astro` 已按 `/board/` 前缀放行，本身不用改。
- 四个测试脚本现在断言内容住在 `dist/board/index.html`，必须改指新路径。
- Astro 只把渲染过的组件脚本带上页面（`docs/components/board.md:147` 已记录这条
  行为）。本方案依赖它，**实现时必须查一次产物确认**，不靠推测。
- dev 布局编辑器随 `Board.astro` 走，端点 `/api/board/layout` 不变。

## 考虑过的做法

**A. 一份数据 + 动态路由（选定）**
`src/data/board-sections.ts` 存四条登记；每件一个 Exhibit 组件；
`board/[slug].astro` 与 `en/board/[slug].astro` 用 `getStaticPaths` 出 8 页；
列表页读同一份登记。加第五件只碰数据与组件。

**B. 手写 8 个子页**
每页只 import 自己那个组件，产物隔离最直白，不用赌 Astro 的脚本传播行为。
但中英文各写一遍，正是现在两份重复页面的毛病；加第五件要改三处。
**否掉**：作者明说了后面还要往里加，B 恰好在这件事上最差。

**C. 路由按 slug 直接映射到裸组件（未展开即否）**
省掉 Exhibit 包装层。但鸟板的授权署名、邮票板的参考链接需要各自的附注位置，
包装层省不掉。

## 对话中已定的（作者决定）

- 列表 + 子页的形状，照 blog 列表页。
- 四个子项：邮票和拼贴、光栅卡、票券、鸟类收藏板。
- 手机上暂时不放开：`NAVIGATION` 的 `mobileHidden: true` 保持不动。
- **列表页显示名「玩具柜」**；原先叫「收藏板」的那一件展品改叫**「邮票和拼贴」**，
  避免列表页与其第一条目同名。第四项仍叫「鸟类收藏板」。路由 `/board` 不变。

## 我的判断（作者可驳回）

- **slug 全小写**：`stamps` / `lenticular-card` / `tickets` / `birds`。与 `/tags`、
  `/figures`、`/authors` 一致。作者原话写过 `TicketCard`、`lenticularCard`，那是组件名，
  不适合当 URL；已在对话中提出，未被驳回。
- **窄屏列表藏掉 stamps 那一条**，等于今天 `board-section { display: none }` 的语义。
  其余三条照常显示（它们今天在手机上就是可见的）。
- **`/board/stamps` 窄屏不白屏**：留页头 + 一行「此展品需要宽屏」提示。
- **列表卡片不放缩略图**：条目没有现成图片资产；渲染活的迷你版会把四件东西又全
  加载回列表页。卡片 = 标题链接 + 小字计数 + 一句说明，形状取自 `BlogCard`。
- **子页带 crumbs** 回 `/board`（`SiteBar.astro` 已支持）。
- **列表整体做成一个组件** `BoardIndex.astro`（吃 `locale`），两个 index 页面各剩几行。
  只有四条条目，不另拆卡片组件。
- **计数不写死在登记里**：由列表页从现有 `getBoardViews` / `getBirdViews` 算；
  光栅卡与票券没有自然计数，省略。

## 命名与文案

| 位置 | zh | en |
| --- | --- | --- |
| 列表页标题 / 导航标签 / crumbs | 玩具柜 | Toy Cabinet |
| 条目一（slug `stamps`） | 邮票和拼贴 | Stamps & Collage |
| 条目二（slug `lenticular-card`） | 光栅卡 | Lenticular Card |
| 条目三（slug `tickets`） | 票券 | Tickets |
| 条目四（slug `birds`） | 鸟类收藏板 | Bird Board |

「Toy Cabinet」是我的判断：取「柜」的直译，且与列表页页头已在用的 `drawer`（三层抽屉
归档柜）插图同族。条目二/三/四的英文名沿用今天页面上已有的写法。

`navBoard` 这个 UI key 不改名，只换值（zh 收藏板 → 玩具柜，en Board → Toy Cabinet）。
条目四的标题与说明继续用现成的 `birdsTitle` / `birdsDesc`，登记里引用而不复制。
其余条目的标题与说明作为 `L10n` 内联在登记里。

slug 仍是 `stamps`：显示名扩成「邮票和拼贴」后它略窄，但短、好记，且组件本就叫
`stamp-board`；不为此改路由。

## 落地形状

新增：

- `src/data/board-sections.ts` — 登记：`slug`、`title: L10n`、`desc: L10n`、
  `mobileHidden?`。文案双语内联，沿用 `src/data/board.ts` 的 `L10n` 惯例。
- `src/components/BoardIndex.astro` — `ListingHead` + `<ul>` 条目，吃 `locale`。
- `src/components/exhibits/{Stamps,Lenticular,Tickets,Birds}Exhibit.astro` —
  各含页头 + 调用现有组件 + 只属于它的附注，吃 `locale`。
- `src/components/exhibits/index.ts` — slug → Exhibit 映射，两个路由文件共用。
- `src/pages/board/[slug].astro`、`src/pages/en/board/[slug].astro`。

重写：

- `src/pages/board/index.astro`、`src/pages/en/board/index.astro` — 变成薄壳。

每个子页自带 `MetaPage alternates={{ zh: "/board/<slug>", en: "/en/board/<slug>" }}`。
sitemap 自动收录新路由，无需改 `astro.config.ts`。

界面文案新增走 `UI_STRINGS`，zh / en 两份都补：列表页说明（`boardDesc` 之类）、
窄屏「需要宽屏」提示。`navBoard` 只换值，crumbs 标签直接复用它。

## 测试与文档

改断言路径：

- `scripts/tests/board-check.sh` — 邮票断言指 `dist/board/stamps/index.html`，
  票券断言指 `dist/board/tickets/index.html`；导航 `href="/board"` 与
  `data-mobile-hidden` 断言指列表页。今天那条「`board-section` 被 scoped CSS
  `display:none`」的断言要换机制：`board-section` 不复存在，窄屏隐藏改由列表条目
  与 stamps 展品的宽屏提示承担，断言随之改写。
- `scripts/tests/lenticular-check.sh` — ZH/EN 指 `…/board/lenticular-card/index.html`。
- `scripts/tests/birds-check.sh` — 指 `…/board/birds/index.html`；保留 `/birds` 已移除断言。
- `scripts/tests/board-layout-check.sh` — `curl $BASE/board` 找 `<board-editor` 改指
  `$BASE/board/stamps`。
- `scripts/tests/i18n-check.sh` — `/en/board` 断言仍成立；补子页孪生与切换器断言。

新增断言：每个子页的产物 HTML 不含另外三件展品的脚本（验证方案 A 的前提）。

文档同步：`docs/components/board.md`（§2 路由、§6 窄屏、§9 编辑器 URL）、
`bird-board.md`、`lenticular-card.md`、`ticket-card.md`、`AGENTS.md` 的 dev 编辑器小节；
按组件文档约定新增 `docs/components/board-index.md` 记列表与路由结构。

## 验证

`bun run format:check`、`bun run build`，上述五个测试脚本全绿，
`bash scripts/tests/i18n-check.sh` 全绿。dev server 手动走：`/board` 列表、四个子页、
四个 `/en/` 孪生页、每页语言切换器、窄屏视口下的列表与 stamps 提示、
dev 保存浮条在 `/board/stamps` 仍可写回。

## 留给实现者

登记与 Exhibit 的确切类型签名、动态组件选择在 Astro frontmatter 里的写法、
列表卡片的具体 CSS、窄屏提示的措辞。