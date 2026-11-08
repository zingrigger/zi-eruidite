# /board 拆成玩具柜列表 + 展品子页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `/board` 从四段堆叠的单页改成「玩具柜」列表页 + 四个展品子页（中英各一套），registry 驱动，手机端不放开。

**Architecture:** 一份 `BOARD_SECTIONS` 登记（slug + 指向 `UI_STRINGS` 的文案 key + 窄屏标记）驱动列表与路由。四个 Exhibit 组件各自包住「页头 + 现有组件 + 只属于它的附注」，由 `BoardExhibit.astro` 按 slug 选一个并套上页面外壳；`BoardIndex.astro` 渲染整个列表页。四个路由文件都是薄壳。现有 `Board` / `LenticularSection` / `TicketSection` / `BirdBoard` 内部一行不改。

**Tech Stack:** Astro 7（无 UI 框架）、原生 CSS（Utopia 令牌 + Radix `light-dark()`）、自主定制元素、Biome、bash 产物断言脚本。

**Spec:** `docs/superpowers/specs/2026-11-08-board-index-split-design.md`

## Global Constraints

- 包管理器：仓库同时跟踪 `bun.lock` 与 `package-lock.json`；测试脚本内部一律调 `npm run build`，不要改写它们。
- 无 UI 框架、无 CSS 框架。样式用自主定制元素选择器 + CSS 自定义属性；断点沿用 `64rem`。
- slug 全小写：`stamps` / `lenticular-card` / `tickets` / `birds`。
- 显示名：列表页「玩具柜」/「Toy Cabinet」；条目「邮票和拼贴」/「Stamps & Collage」、「光栅卡」/「Lenticular Card」、「票券」/「Tickets」、「鸟类收藏板」/「Bird Board」。
- 路由 `/board` 不变；`NAVIGATION` 的 `mobileHidden: true` 不动；`navBoard` 这个 UI key 不改名，只换值。
- 每个子页必须有 `/en/board/<同 slug>` 孪生页，且带 `MetaPage alternates`。
- `src/components/LanguageSwitch.astro` **不改**：它已按 `/board/` 前缀放行，子页自动获得切换器。
- 新增界面文字必须同时补 `UI_STRINGS` 的 `zh` 与 `en` 两份（`Record<UIKey, string>` 会在构建期抓缺漏）。
- 鸟板授权署名（PolyForm Shield 1.0.0 / MIT / IOC CC BY 3.0 / AVONET CC BY 4.0）必须保留。
- 提交信息沿用仓库现有风格：`feat(board): …`、`docs(components): …`（祈使句、中文）。
- 每个 Task 结束时 `npm run format:check` 与 `npm run build` 必须通过，且该 Task 涉及的测试脚本全绿。

## Review Focus

spec 沉默、但真实访客会撞上的五类输入/条件，按咬人概率排序。每条都在归属 Task 里有测试钉住。

1. **列表页把展品的脚本与图片又全加载回来**（本次要解决的原始毛病）。访客打开 `/board` 只应拿到链接与文字。→ Task 3 Step 1 的 `assert_lacks` 组。
2. **子页串进兄弟展品的脚本**。`BoardExhibit.astro` import 了全部四个 Exhibit，若 Astro 把未渲染组件的脚本也传播进来，每个子页都会背上另外三件的 JS。→ Task 2 Step 1 的隔离断言（注意 `/_astro/` 前缀，见该步说明）。
3. **窄屏直接敲 `/board/stamps`**。导航入口在手机上藏着，但 URL 可以被分享、被书签、被搜索引擎给出；不能白屏。→ Task 2 Step 1 的宽屏提示断言 + Task 3 Step 1 的列表条目标记断言。
4. **`/board/<不存在的 slug>`**。`getStaticPaths` 只生成四条，其余应落到站点 404，而不是渲染出 `undefined` 标题或崩掉构建。→ Task 2 Step 1 的 `assert_lacks … aria-label="undefined"` 与产物不存在断言。
5. **旧 `/birds` 路由的撤销断言被新路由误伤**。`/board/birds` 含子串 `/birds`，`birds-check.sh` 现有的 `assert_lacks dist/sitemap-0.xml '/birds'` 会假失败，掩盖真正的回归。→ Task 3 Step 1 把该断言改成主机锚定的精确串。

---

### Task 1: 界面文案与展品登记

**Files:**
- Modify: `src/lib/i18n.ts:78`（`navBoard` zh 值）、`:167`（`navBoard` en 值）、`:63-146`（`ZH_STRINGS` 追加）、`:152-238`（en 字典追加）
- Create: `src/data/board-sections.ts`
- Test: `scripts/tests/board-check.sh:54`

**Interfaces:**
- Consumes: `UIKey`、`t(locale, key)`、`Locale`（均来自 `src/lib/i18n.ts`，签名不变）
- Produces:
  - `BoardSection = { slug: string; titleKey: UIKey; descKey: UIKey; wideOnly?: boolean }`
  - `BOARD_SECTIONS: BoardSection[]`，顺序即列表顺序：`stamps`(wideOnly: true)、`lenticular-card`、`tickets`、`birds`
  - 新 UI key：`boardDesc`、`boardWideOnly`、`boardPieceUnit`、`boardFigureLabel`、`stampsTitle`、`stampsDesc`、`stampsRefsLabel`、`stampsSvgCredit`、`lenticularDesc`、`ticketsTitle`、`ticketsDesc`

- [ ] **Step 1: 把导航标签断言改成新名字（ failing test ）**

`scripts/tests/board-check.sh:54`，把

```bash
assert_has dist/index.html '收藏板' "中文导航收藏板标签"
```

改为

```bash
assert_has dist/index.html '玩具柜' "中文导航玩具柜标签"
assert_has dist/en/index.html 'Toy Cabinet' "英文导航 Toy Cabinet 标签"
```

- [ ] **Step 2: 跑测试确认它失败**

Run: `bash scripts/tests/board-check.sh`
Expected: FAIL —`dist/index.html 未找到 玩具柜`（构建会成功，断言在导航段失败）

- [ ] **Step 3: 改 `navBoard` 的值并追加新 key**

`src/lib/i18n.ts`：`navBoard` zh 改 `"玩具柜"`、en 改 `"Toy Cabinet"`（key 名不动）。
在 `ZH_STRINGS` 与 en 字典里各追加同一组 key，值如下（zh / en）：

| key | zh | en |
| --- | --- | --- |
| `boardDesc` | 把喜欢的东西一件件摆出来，点进去才看得到全貌。 | A cabinet of things I like — open one to see it whole. |
| `boardWideOnly` | 这件展品需要宽屏才能摆开，请在电脑上打开。 | This exhibit needs a wide screen — open it on a desktop. |
| `boardPieceUnit` | 件 | items |
| `boardFigureLabel` | 三层抽屉的玩具柜，指针划过哪一层就抽出哪一层 | A three-drawer toy cabinet; the pointer pulls out whichever drawer it passes |
| `stampsTitle` | 邮票和拼贴 | Stamps & Collage |
| `stampsDesc` | 邮票与技术栈徽章的可拖拽拼贴；右键拿起可缩放、旋转、镜像、调叠放。 | A draggable collage of stamps and tech-stack badges — right-click a piece to scale, rotate, mirror and restack. |
| `stampsRefsLabel` | 参考 | References |
| `stampsSvgCredit` | 部分 SVG 来自 df.fenx.work/llm-things | Some SVGs come from df.fenx.work/llm-things |
| `lenticularDesc` | 两张邮票随视角左右翻转，带弹簧手感。 | Two stamps flip with your viewing angle, on a spring. |
| `ticketsTitle` | 票券 | Tickets |
| `ticketsDesc` | 一组图片主题票券，悬停有 3D 倾斜。 | A set of picture-themed tickets that tilt in 3D on hover. |

光栅卡标题复用现成的 `boardLensTitle`（已是 光栅卡 / Lenticular Card）；鸟类复用现成的
`birdsTitle` / `birdsDesc`。不新增重复 key。

- [ ] **Step 4: 建登记模块**

`src/data/board-sections.ts`：`import type { UIKey } from "@/lib/i18n"`，导出上面的
`BoardSection` 类型与 `BOARD_SECTIONS` 数组。文案一律存 key、不存字符串——与
`blogTitle` / `birdsTitle` 同为界面文案，归 `i18n.ts` 统一管（AGENTS.md 的 i18n 约定）。
spec 写的是 `title: L10n` 内联，落地统一改成 key 引用：spec 已要求鸟板那条「引用而不复制」，
四条都用 key 最省，且构建期的 `Record<UIKey, string>` 能抓缺漏。
`wideOnly` 只有 `stamps` 为 true。

- [ ] **Step 5: 跑测试确认通过**

Run: `bash scripts/tests/board-check.sh`
Expected: 全绿。此时 `/board` 仍是旧的四段单页，其余断言不受影响。

- [ ] **Step 6: 格式检查 + 提交**

Run: `npm run format:check`
Expected: 无格式问题（有问题先 `npm run format`）

```bash
git add src/lib/i18n.ts src/data/board-sections.ts scripts/tests/board-check.sh
git commit -m "feat(board): 玩具柜文案与展品登记，导航标签改名"
```

---

### Task 2: 四个展品子页

**Files:**
- Create: `src/components/exhibits/StampsExhibit.astro`、`LenticularExhibit.astro`、`TicketsExhibit.astro`、`BirdsExhibit.astro`
- Create: `src/components/BoardExhibit.astro`
- Create: `src/pages/board/[slug].astro`、`src/pages/en/board/[slug].astro`
- Modify: `scripts/tests/board-check.sh`（追加子页断言）、`scripts/tests/board-layout-check.sh:111`
- Test: `scripts/tests/board-check.sh`、`scripts/tests/board-layout-check.sh`

**Interfaces:**
- Consumes: `BOARD_SECTIONS`、`BoardSection`（Task 1）；`t`、`Locale`；现有组件 `Board.astro`、`LenticularSection.astro`、`TicketSection.astro`、`BirdBoard.astro`，四者 props 均为 `{ locale: Locale }`；`ListingHead.astro` props `{ kicker, title, desc?, figure?, figureLabel?, figureWidth? }`；`Layout.astro` props `{ crumbs?: { label: string; href: string }[], article? }`；`MetaPage.astro` props `{ title?, description?, alternates?: { zh: string; en: string }, … }`
- Produces:
  - 四个 Exhibit 组件，props 均为 `{ locale: Locale }`，各自渲染 `ListingHead` + 对应现有组件 + 自己的附注
  - `BoardExhibit.astro`，props `{ slug: string; locale: Locale }`，渲染完整页面外壳（`Layout` + `MetaPage` + crumbs + 选中的 Exhibit）
  - 8 个产物页面：`dist/board/<slug>/index.html` 与 `dist/en/board/<slug>/index.html`

**slug → Exhibit 映射放在 `BoardExhibit.astro` 的 frontmatter里**（Astro 原生处理 `.astro`
import）。**不要**建 `src/components/exhibits/index.ts`：本仓 `astro/client` 没有
`declare module '*.astro'`，从 `.ts` import `.astro` 会是 TS2307。

- [ ] **Step 1: 写子页断言（ failing test ）**

在 `scripts/tests/board-check.sh` 末尾追加。注意 `assert_lacks` 的脚本名**必须带
`/_astro/` 前缀**：`Board.astro_astro_type_script` 是 `BirdBoard.astro_astro_type_script`
的子串，不带前缀会把鸟板页误判成含邮票板脚本。

```bash
# ---------- 四个展品子页：路由就位 ----------
for slug in stamps lenticular-card tickets birds; do
  assert_file "dist/board/${slug}/index.html" "中文展品子页 /board/${slug}"
  assert_file "dist/en/board/${slug}/index.html" "英文展品子页 /en/board/${slug}"
  assert_has "dist/board/${slug}/index.html" 'hreflang="en"' "子页输出 en alternate"
  assert_has "dist/en/board/${slug}/index.html" 'hreflang="zh-CN"' "英文子页输出 zh alternate"
  assert_has "dist/board/${slug}/index.html" '玩具柜' "子页 crumbs 回列表页"
done

# ---------- 子页只背自己的脚本（Review Focus 2） ----------
assert_lacks dist/board/lenticular-card/index.html '/_astro/Board.astro_astro_type_script' "光栅卡页不含邮票板脚本"
assert_lacks dist/board/lenticular-card/index.html '/_astro/BirdBoard.astro_astro_type_script' "光栅卡页不含鸟板脚本"
assert_lacks dist/board/lenticular-card/index.html '/_astro/TicketSection.astro_astro_type_script' "光栅卡页不含票券脚本"
assert_lacks dist/board/stamps/index.html '/_astro/BirdBoard.astro_astro_type_script' "邮票页不含鸟板脚本"
assert_lacks dist/board/birds/index.html '/_astro/Board.astro_astro_type_script' "鸟板页不含邮票板脚本"
assert_lacks dist/board/tickets/index.html '/_astro/Board.astro_astro_type_script' "票券页不含邮票板脚本"

# ---------- 不存在的 slug 不产出页面（Review Focus 4） ----------
[ ! -f dist/board/nope/index.html ] || fail "未知 slug 竟产出了页面"
pass "未知 slug 不产出页面"

# ---------- 窄屏直接访问 stamps 不白屏（Review Focus 3） ----------
assert_has dist/board/stamps/index.html 'data-wide-only' "邮票板宿主带窄屏隐藏标记"
assert_has dist/board/stamps/index.html '这件展品需要宽屏' "窄屏宽屏提示入 SSR"
assert_has dist/en/board/stamps/index.html 'needs a wide screen' "英文窄屏提示"

# ---------- 附注跟着展品走 ----------
assert_has dist/board/stamps/index.html 'df.fenx.work/llm-things' "邮票板参考与 SVG 署名"
assert_has dist/en/board/stamps/index.html 'df.fenx.work/llm-things' "英文页同样保留 SVG 署名"
assert_has dist/board/birds/index.html 'PolyForm' "鸟板授权署名随展品搬迁"
assert_has dist/board/birds/index.html 'huashu-bird-sticker' "鸟板仓库链接随展品搬迁"
```

同时把 `scripts/tests/board-layout-check.sh:111` 的 `curl -s "$BASE/board"` 改为
`curl -s "$BASE/board/stamps"`（编辑条随 `Board.astro` 搬到了子页）。

- [ ] **Step 2: 跑测试确认失败**

Run: `bash scripts/tests/board-check.sh`
Expected: FAIL —`缺少 dist/board/stamps/index.html`

- [ ] **Step 3: 写四个 Exhibit 组件**

每个 props 都是 `{ locale: Locale }`，结构统一为
`<ListingHead kicker={`~/board/<slug>`} title={t(locale, titleKey)} desc={t(locale, descKey)} />`
+ 现有组件 + 附注。各自的具体责任：

- `StampsExhibit.astro`：`<Board locale>` 包在 `<div data-wide-only>` 里；另渲染
  `<p class="wide-notice">{t(locale,"boardWideOnly")}</p>`。scoped 样式两条：
  `.wide-notice { display: none }`，以及
  `@media (width < 64rem) { [data-wide-only] { display: none } .wide-notice { display: block } }`。
  附注 = `stampsRefsLabel` + 两条参考链接
  （`https://df.fenx.work/llm-things/`、`https://marijanapav.com/stamps`，`target="_blank"`
  `rel="noopener noreferrer"`）+ `stampsSvgCredit`。两种语言都渲染——今天英文页漏了
  SVG 署名，这次补上。
- `LenticularExhibit.astro`：只有页头 + `<LenticularSection locale>`，无附注。
- `TicketsExhibit.astro`：只有页头 + `<TicketSection locale>`，无附注。
- `BirdsExhibit.astro`：页头 + `<BirdBoard locale>` + 授权署名段，整段从
  `src/pages/board/index.astro:48-65` 搬过来（含注释、`birdsCredit`、仓库与许可两个链接），
  样式 `.birds-credit` 一并搬入本组件 scoped style。

窄屏隐藏用 `data-wide-only` 属性，**不要**复用 `data-mobile-hidden`：后者是导航专用标记，
`board-check.sh:62-64` 靠 grep 它定位导航 CSS，混用会让那条断言失去精度。

- [ ] **Step 4: 写 `BoardExhibit.astro` 页面外壳**

props `{ slug: string; locale: Locale }`。frontmatter 里 import 四个 Exhibit 并建映射
`const EXHIBITS = { stamps: StampsExhibit, "lenticular-card": LenticularExhibit, tickets: TicketsExhibit, birds: BirdsExhibit }`
（不写类型注解，让 TS 推断；避免从 `astro/types` 引组件工厂类型），取
`const Component = EXHIBITS[slug as keyof typeof EXHIBITS]` 后 `<Component locale={locale} />`。
`getStaticPaths` 只产出这四个 slug，故映射不会取空。从 `BOARD_SECTIONS` 按 slug 取条目，渲染：

- `Layout crumbs={[{ label: t(locale,"navBoard"), href: localePath("/board", locale) }]}`
- `MetaPage slot="head" title={t(locale, titleKey)} description={t(locale, descKey)} alternates={{ zh: `/board/${slug}`, en: `/en/board/${slug}` }}`
- 选中的 Exhibit

- [ ] **Step 5: 写两个薄壳路由**

`src/pages/board/[slug].astro` 与 `src/pages/en/board/[slug].astro`，各只有：

```astro
export function getStaticPaths() {
  return BOARD_SECTIONS.map(({ slug }) => ({ params: { slug } }))
}
```

加 `const { slug } = Astro.params`，然后 `<BoardExhibit slug={slug} locale="zh" />`
（英文文件为 `"en"`）。`getStaticPaths` 从登记派生，所以加第五件不需要碰路由文件。

- [ ] **Step 6: 跑测试确认通过**

Run: `bash scripts/tests/board-check.sh`
Expected: 全绿（旧 `/board` 单页此时仍在，新旧并存）

Run: `bash scripts/tests/board-layout-check.sh`
Expected: 全绿，含 `B5：dev 渲染编辑条`

**若 Step 1 的隔离断言失败**，说明 Astro 确实传播了未渲染组件的脚本。不要靠猜改断言：
先 `grep -o '/_astro/[^"]*\.js' dist/board/lenticular-card/index.html` 看实际引入了什么，
再决定是把映射拆成四个只在各自路由里 import 的分支，还是别的隔离手段。这是 spec 点名
要实测的前提，结果要写进提交信息。

- [ ] **Step 7: 格式检查 + 提交**

Run: `npm run format:check`

```bash
git add src/components/exhibits src/components/BoardExhibit.astro \
        "src/pages/board/[slug].astro" "src/pages/en/board/[slug].astro" \
        scripts/tests/board-check.sh scripts/tests/board-layout-check.sh
git commit -m "feat(board): 四个展品各立子页，附注随展品走"
```

---

### Task 3: 玩具柜列表页

**Files:**
- Create: `src/components/BoardIndex.astro`
- Rewrite: `src/pages/board/index.astro`、`src/pages/en/board/index.astro`
- Modify: `scripts/tests/board-check.sh`、`scripts/tests/lenticular-check.sh:101-102,141-143`、`scripts/tests/birds-check.sh:56,59-104`、`scripts/tests/i18n-check.sh:190-193`
- Test: 上述四个脚本

**Interfaces:**
- Consumes: `BOARD_SECTIONS`（Task 1）；`getBoardViews(locale): Promise<BoardView[]>`、`getBirdViews(locale): Promise<BirdView[]>`（`src/lib/content.ts:181,240`）；`ListingHead`、`Layout`、`MetaPage`、`t`、`localePath`
- Produces: `BoardIndex.astro`，props `{ locale: Locale }`，渲染完整列表页外壳（`Layout` + `MetaPage` + `ListingHead` + `<ul>`）；`/board` 与 `/en/board` 不再含任何展品 markup

- [ ] **Step 1: 迁移三个脚本的断言并加列表断言（ failing test ）**

**`board-check.sh`**：按段落注释定位，**不要按行号**（Task 1/2 已让行号漂移）。
从「板 SSR 静态渲染」段到「拿起物件的三条入口与浮层几何」段为止，其中所有
`dist/board/index.html` 改指 `dist/board/stamps/index.html`、`dist/en/board/index.html`
改指 `dist/en/board/stamps/index.html`（含那两条 `assert_file`；列表页自身的存在由下面
新增的列表断言与 `i18n-check.sh` 覆盖）。「板下票券组静态展示区」「票券图片主题 + 切换控件」
「票券悬停倾斜」「倾斜变量名不得撞」四段改指 `dist/board/tickets/index.html` 与英文对应页。
最后那段「层叠上下文回归」grep 的是 `dist/_astro/*.css`，与页面路径无关，不动。
「导航入口双语就位」段的四条与「移动端不展示」段的 `:58-59,62-64` 仍指列表页与首页，不动。

删掉「移动端不展示」段里那两条 `board-section\[…\]{display:none}` 断言（`board-section`
不复存在），换成：

```bash
assert_has dist/board/index.html 'data-wide-only' "列表里 stamps 条目带窄屏隐藏标记"
wide_css="$(grep -lE 'data-wide-only' dist/board/index.html dist/_astro/*.css 2>/dev/null | head -1)"
[ -n "${wide_css}" ] || fail "找不到 data-wide-only 规则（HTML 与 CSS chunk 都没有）"
assert_match "${wide_css}" '\[data-wide-only\]\{display:none\}' "窄屏隐藏 stamps 列表条目"
```

追加列表页断言：

```bash
# ---------- 玩具柜列表页 ----------
assert_file dist/board/index.html "中文列表页产出"
assert_file dist/en/board/index.html "英文列表页产出"
# ListingHead 有 scoped style，h1 会带 data-astro-cid-*，故用正则跨过属性
assert_match dist/board/index.html 'listing-title[^>]*>玩具柜' "列表页标题"
assert_has dist/en/board/index.html 'Toy Cabinet' "英文列表页标题"
for slug in stamps lenticular-card tickets birds; do
  assert_has dist/board/index.html "href=\"/board/${slug}\"" "列表含 ${slug} 入口"
  assert_has dist/en/board/index.html "href=\"/en/board/${slug}\"" "英文列表含 ${slug} 入口"
done
assert_has dist/board/index.html '邮票和拼贴' "条目一改名生效"

# ---------- 列表页不背任何展品（Review Focus 1） ----------
assert_lacks dist/board/index.html '<stamp-board' "列表页不含邮票板"
assert_lacks dist/board/index.html '<bird-board' "列表页不含鸟板"
assert_lacks dist/board/index.html '<lenticular-card' "列表页不含光栅卡"
assert_lacks dist/board/index.html '<ticket-collage' "列表页不含票券"
assert_lacks dist/board/index.html '/_astro/Board.astro_astro_type_script' "列表页不含邮票板脚本"
assert_lacks dist/board/index.html '/_astro/BirdBoard.astro_astro_type_script' "列表页不含鸟板脚本"
assert_lacks dist/board/index.html 'DONGLONGDONG' "列表页不加载展品图片"
```

**`lenticular-check.sh`**：`:101-102` 改为
`ZH=dist/board/lenticular-card/index.html`、`EN=dist/en/board/lenticular-card/index.html`。
`:141-143` 那两条「卡 + 原邮票各一份」的 `assert_count_ge … 2` 依赖同页共存，拆开后必失败；
改为在卡页数 ≥1，并另钉邮票页仍含这两张图：

```bash
assert_count_ge "${ZH}" 'DONGLONGDONG-2' 1 "云海图在卡里（邮票已迁至 /board/stamps）"
assert_count_ge "${ZH}" 'DONGLONGDONG-3' 1 "星夜图在卡里（邮票已迁至 /board/stamps）"
assert_has dist/board/stamps/index.html 'DONGLONGDONG-2' "原邮票仍在邮票子页"
assert_has dist/board/stamps/index.html 'DONGLONGDONG-3' "原邮票仍在邮票子页"
```

**`birds-check.sh`**：`:60-104` 的 `dist/board/index.html` 改指 `dist/board/birds/index.html`、
`dist/en/board/index.html` 改指 `dist/en/board/birds/index.html`。`:59` 那条
`assert_file dist/board/index.html "中文 /board 路由存在"` **保留不动**——它现在验的是列表页存在。
`:76` 的 `assert_file dist/en/board/index.html` 同理保留。
`:56` 必须改成主机锚定的精确串，否则 `/board/birds` 含子串 `/birds` 会假失败（Review Focus 5）：

```bash
assert_lacks dist/sitemap-0.xml 'https://example.com/birds' "sitemap 不含旧独立 /birds 路由"
```

`:54-55` 的 `href="/birds"` 断言不用改：`href="/board/birds"` 不含该子串。

**`i18n-check.sh`**：`:190-193` 三条仍成立，保留；在其后追加

```bash
for slug in stamps lenticular-card tickets birds; do
  assert_file "dist/en/board/${slug}/index.html" "en 展品子页 ${slug} 产出"
  assert_has "dist/board/${slug}/index.html" "href=\"/en/board/${slug}\"" "子页语言切换器指向英文孪生"
  assert_has "dist/en/board/${slug}/index.html" "href=\"/board/${slug}\"" "英文子页切换器指回中文"
done
```

- [ ] **Step 2: 跑四个脚本确认失败**

Run: `bash scripts/tests/board-check.sh`
Expected: FAIL —列表页仍是旧单页，`assert_lacks '<stamp-board'` 命中

- [ ] **Step 3: 写 `BoardIndex.astro`**

props `{ locale: Locale }`。渲染：

- `Layout`（无 crumbs）
- `MetaPage slot="head" title={t(locale,"navBoard")} description={t(locale,"boardDesc")} alternates={{ zh:"/board", en:"/en/board" }}`
- `ListingHead kicker={`~/board · ${BOARD_SECTIONS.length} exhibits`} title={t(locale,"navBoard")} desc={t(locale,"boardDesc")} figure="drawer" figureLabel={t(locale,"boardFigureLabel")}`
  （kicker 用英文单位，与 `src/pages/blog/index.astro:19` 的 `posts` 同款；`figure="drawer"`
  与「柜」同族，`ListingHead` 的 `INK_COMPENSATION` 已登记 drawer 的光学补偿，不用另调）
- `<ul>` 遍历 `BOARD_SECTIONS`，每条 `<li data-wide-only={section.wideOnly || undefined}>`，
  内含 `<a href={localePath(`/board/${slug}`, locale)}>{t(locale,titleKey)}</a>`、
  计数（若有）与 `<p>{t(locale,descKey)}</p>`

计数在 frontmatter 算，不写死在登记里：
`const counts: Record<string, number> = { stamps: (await getBoardViews(locale)).length, birds: (await getBirdViews(locale)).length }`。
渲染成 `{count} {t(locale,"boardPieceUnit")}`；`lenticular-card` 与 `tickets` 无计数，省略。

卡片形状取自 `src/components/BlogCard.astro:93-177`（标题链接 `--step-1`、小字 meta、
说明段 `--muted-foreground`），但**不放缩略图**。窄屏隐藏规则写在组件 scoped style：
`@media (width < 64rem) { li[data-wide-only] { display: none } }`。

- [ ] **Step 4: 把两个 index 页面改成薄壳**

`src/pages/board/index.astro` 与 `src/pages/en/board/index.astro` 各自只剩 import 与
`<BoardIndex locale="zh" />`（英文 `"en"`）。删掉原有的四段 markup、`board-section`
窄屏规则、`.birds-credit` 样式与那段共用 `desc`（参考链接已在 Task 2 搬进 StampsExhibit）。

- [ ] **Step 5: 跑四个脚本确认通过**

Run: `bash scripts/tests/board-check.sh && bash scripts/tests/lenticular-check.sh && bash scripts/tests/birds-check.sh && bash scripts/tests/i18n-check.sh`
Expected: 四个全绿

- [ ] **Step 6: 格式检查 + 提交**

Run: `npm run format:check`

```bash
git add src/components/BoardIndex.astro src/pages/board/index.astro \
        src/pages/en/board/index.astro scripts/tests/board-check.sh \
        scripts/tests/lenticular-check.sh scripts/tests/birds-check.sh \
        scripts/tests/i18n-check.sh
git commit -m "feat(board): /board 改为玩具柜列表，四件展品各归子页"
```

---

### Task 4: 文档同步

**Files:**
- Create: `docs/components/board-index.md`
- Modify: `docs/components/board.md`（§2 路由、§6 窄屏、§9 编辑器 URL）、`docs/components/bird-board.md`、`docs/components/lenticular-card.md`、`docs/components/ticket-card.md`、`AGENTS.md`（dev 收藏板布局编辑器小节）
- Test: `npm run format:check`、`npm run build`

**Interfaces:**
- Consumes: Task 1–3 落地的实际路径与组件名
- Produces: 无代码接口

- [ ] **Step 1: 写 `docs/components/board-index.md`**

按 `docs/components/README.md` 的模板，记：列表页与四个子页的路由表、`BOARD_SECTIONS`
字段、`BoardIndex` / `BoardExhibit` 的 props、加第五件展品的两步操作（补 UI key + 追加
登记 + 写一个 Exhibit + 在 `BoardExhibit` 映射里加一行）、窄屏语义、slug 命名约定。

- [ ] **Step 2: 改四篇组件文档与 AGENTS.md 的路径引用**

把「住在 `/board` 页面某段」的描述改成对应子页；`board.md` §9 的 dev 编辑器 URL 改
`/board/stamps`；§6 窄屏那段改成「列表条目隐藏 + 子页留宽屏提示」，并说明
`Board.astro` 内部的只读网格回退仍未被启用（与今天一致）。`AGENTS.md` 的
「dev 收藏板布局编辑器」小节把 `/board` 改 `/board/stamps`，并补一句列表页结构。

- [ ] **Step 3: 验证路径引用已迁移**

Run: `grep -rn "dist/board/index.html" docs/components/`
Expected: 无输出（组件文档里的产物路径都已迁到子页）。**只查 `docs/components/`**——
`docs/superpowers/` 下的 spec 与 plan 会正当地提到旧路径，别把它们算进来。

Run: `grep -n "/board/stamps" docs/components/board.md AGENTS.md`
Expected: 两个文件都有命中（dev 编辑器 URL 已改指子页）

Run: `npm run format:check && npm run build`
Expected: 均通过

- [ ] **Step 4: 提交**

```bash
git add docs/components/board-index.md docs/components/board.md \
        docs/components/bird-board.md docs/components/lenticular-card.md \
        docs/components/ticket-card.md AGENTS.md
git commit -m "docs(board): 同步玩具柜列表与展品子页的路由与窄屏语义"
```

---

### Task 5: 全量验证与浏览器走查

**Files:**
- 无新增/修改（只跑验证；发现缺陷回到对应 Task 修，修完重跑本 Task）
- Test: `scripts/tests/` 全部相关脚本

**Interfaces:**
- Consumes: Task 1–4 的全部产物
- Produces: 无

- [ ] **Step 1: 跑全部回归脚本**

Run: `npm run format:check && npm run build && bash scripts/tests/board-check.sh && bash scripts/tests/lenticular-check.sh && bash scripts/tests/lenticular-motion-check.sh && bash scripts/tests/birds-check.sh && bash scripts/tests/board-source-patch-check.sh && bash scripts/tests/board-layout-check.sh && bash scripts/tests/i18n-check.sh`
Expected: 全绿。`lenticular-motion-check.sh` 与 `board-source-patch-check.sh` 是纯离线、
路径无关的，本次不该受影响——若它们红了，说明改到了不该改的东西。

- [ ] **Step 2: 起 dev server 走查宽屏**

Run: `npm run dev`（另开终端，默认 `http://localhost:4321`）

用浏览器逐个走，每项都要看到预期结果：

- `/board`：标题「玩具柜」，四条条目，只有 stamps 与 birds 带计数，无缩略图，
  页面不加载任何展品图片（Network 面板里不应出现 `DONGLONGDONG-*`）
- 四条条目逐个点进去：`/board/stamps`、`/board/lenticular-card`、`/board/tickets`、
  `/board/birds`，各自只渲染那件东西，crumbs 能点回 `/board`
- 每个子页的语言切换器：切到 `/en/board/<同 slug>` 且页面正常，再切回来
- `/en/board`：标题 "Toy Cabinet"，四条英文条目
- `/board/stamps` 宽屏：拖拽、右键浮层、双击原图预览、dev「保存布局」浮条都在；
  点保存后终端可见写回、页面 reload
- `/board/birds`：授权署名段在板下方，托盘可收集
- `/board/不存在的slug`：落到站点 404

- [ ] **Step 3: 窄屏走查（视口宽 < 64rem，如 390×844）**

- 导航里**没有**「玩具柜」入口（`mobileHidden` 未动）
- 直接访问 `/board`：列表只有三条，stamps 那条不出现
- 直接访问 `/board/stamps`：页头在、板不在、显示「这件展品需要宽屏才能摆开，请在电脑上打开。」——不白屏
- `/board/lenticular-card`、`/board/tickets`、`/board/birds`：与今天一样正常可用

- [ ] **Step 4: 关掉 dev server，确认工作树干净**

Run: `git status`
Expected: 无未提交改动（走查若发现缺陷，回对应 Task 修复并提交后重跑本 Task）