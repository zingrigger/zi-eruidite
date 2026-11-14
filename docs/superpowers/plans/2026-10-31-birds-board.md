# 鸟类收藏板 `/birds` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增双语 `/birds` 页面——把花叔《全球鸟类贴纸库》里「44 目各一只」共 44 张鸟贴纸做成一块可拖拽拼贴板：SSR 默认摆 5 只，其余 39 只放托盘由访客点击飞入收集，纯前端、不持久化。

**Architecture:** 数据在 `src/data/birds.ts`（44 条静态数组，名字自带 zh/en，无需 `.en.md` 孪生）；`getBirdViews(locale)` 取数；`BirdBoard.astro` 用自主定制元素 `bird-board/bird-grid/bird-piece/bird-tray` 先 SSR 铺好默认 5 只（无 JS 即成图），一段 `<script>` 接 Pointer Events 做渐进增强（拖拽 + 径向菜单 + 信息卡 + 托盘飞入 + 重置 + 双击预览）。鸟按「徽章」范式渲染（随形 `<img>` + drop-shadow，外链 webp，无齿孔）。窄屏 `<64rem` 回退只读网格铺全部 44 只。

**Tech Stack:** Astro 7（内容/数据模块 + 外链 `<img>`）、原生 Web Components（`customElements.define` + Pointer Events）、原生 CSS（Utopia `clamp` + Radix `light-dark()`，无框架）、glass-bubble（WebGL 预览复用）、Biome、bash + grep 对 `dist/` 的回归脚本、npm。

**Spec:** `docs/superpowers/specs/2026-10-31-birds-board-design.md`（44 只数据见其附录 A，逐字拷进 `birds.ts`）
**Template:** `src/components/Board.astro` 是本组件的 fork 模板——拖拽 / 径向菜单 / 信息卡 / `board-toss` 入场 / 双击预览的机制照它抄，按本计划裁剪与改名。

## Global Constraints

- 包管理器 = **npm**（本项目用 npm 非 bun）；Node `>=22.12.0`。构建 `npm run build`，格式 `npm run format` / 检查 `npm run format:check`。
- **不改 `/board`**（approach A）：`Board.astro`、`board.ts`、`board-check.sh` 的行为一字不动。对共享文件（`content.ts`、`i18n.ts`、`consts.ts`、`LanguageSwitch.astro`、`glass-bubble.css`）**只做 additive 修改**。
- **资产 = hotlink**：鸟图 URL = `https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/` + `sticker.file`（已在附录 A 拼好）。**不 vendor、不下载贴纸、`species.json` 不入库也不进 `dist/`**。
- **不持久化**：无 `localStorage`、无后端；刷新回默认 5 只。
- **无 UI/CSS 框架**：自主定制元素（带连字符）+ scoped CSS + Utopia/Radix 令牌。
- **双语**：`/birds`（zh）+ `/en/birds`（en）；新增界面文案 `ZH_STRINGS` 与 `en` **两份都补**。
- **宽屏交互门槛**：`matchMedia("(width >= 64rem)")` 命中才绑拖拽/菜单/托盘飞入。
- **授权署名（必须）**：页脚含 花叔/鸣迹 + PolyForm Shield 1.0.0 + IOC v15.2 CC BY 3.0 + AVONET CC BY 4.0 + 仓库/许可链接。
- **默认 5 只**（`default:true`）：`Aix_galericulata`（鸳鸯）、`Calypte_anna`（安氏蜂鸟）、`Aptenodytes_forsteri`（帝企鹅）、`Alcedo_atthis`（普通翠鸟）、`Ara_macao`（绯红金刚鹦鹉）。
- **回归脚本按内容 grep 定位 JS chunk**（不钉文件名，应对 Astro chunk 漂移）。
- 交付前删除 `.recon/`（临时调研目录，含 32MB `species.json` 与嵌套 `.git`，不入库）。

## Review Focus

- **外链图挂了**（GitHub raw 404 / 离线 / 限流）→ 该鸟仍显示名字、不留破图空白，板照常可用。（Task 1 的 `onerror` 兜底 + 断言）
- **窄屏 `<64rem`** → 只读网格铺全部 44 只（默认 5 + 托盘 39），无拖拽/飞入/菜单、不溢出、不破版。（Task 1 人工核验）
- **键盘用户（宽屏）** → Tab 到鸟 → Enter 唤起径向菜单 → 方向键走位 → Enter 执行/开信息卡 → Esc 收；托盘按钮可聚焦可回车加鸟。（Task 2/3 人工核验）
- **reduced-motion** → 无飞入/hover 动画，但拖拽与加鸟仍可用。（Task 3 人工核验）
- **加满 44 只** → 板不破（clip/z-order 正常、计数到 44/44）；重置精确回到默认 5 只 + 满 39 托盘。（Task 3 人工核验）
- **数据字段缺失**（`iucn` 空、`pinyin` 缺、`nameAlt` 回落）→ 信息卡优雅降级、无 `undefined` 泄漏。（Task 2 断言 + 人工核验）

---

## File Structure

**Create**
- `src/data/birds.ts` — `BirdItem` 类型 + `BIRD_ITEMS`（44 条，附录 A 逐字拷）+ 默认 5 只的 `x/y/rotate/z`。
- `src/components/BirdBoard.astro` — SSR 骨架 + scoped CSS + 客户端激活脚本（本计划的核心，fork 自 `Board.astro`）。
- `src/pages/birds/index.astro`、`src/pages/en/birds/index.astro` — zh/en 路由。
- `scripts/tests/birds-check.sh` — 回归脚本（仿 `board-check.sh`）。
- `docs/components/bird-board.md` — 组件用法文档。

**Modify（全部 additive）**
- `src/lib/content.ts` — 加 `BirdView` 类型 + `getBirdViews(locale)`。
- `src/lib/i18n.ts` — `ZH_STRINGS` 与 `en` 各加 `navBirds` + `birds*` 文案键。
- `src/consts.ts` — `NAVIGATION` 加 `{ key:"navBirds", href:"/birds", bilingual:true }`。
- `src/components/LanguageSwitch.astro` — `hasEnglishTwin` 白名单加 `/birds`、`/birds/`。
- `src/styles/glass-bubble.css` — 把 5 处 `dialog.board-preview*` 选择器扩成 `dialog.board-preview*, dialog.bird-preview*`（Task 4）。

---

## Task 1: 静态双语 `/birds`（SSR 骨架，无交互）

**Files:**
- Create: `src/data/birds.ts`、`src/components/BirdBoard.astro`（仅 SSR + CSS）、`src/pages/birds/index.astro`、`src/pages/en/birds/index.astro`、`scripts/tests/birds-check.sh`
- Modify: `src/lib/content.ts`、`src/lib/i18n.ts`、`src/consts.ts`、`src/components/LanguageSwitch.astro`

**Interfaces:**
- Produces:
  - `type BirdItem`（见 spec §6 字段）。
  - `const BIRD_ITEMS: BirdItem[]`（44 条；默认 5 只带 `default:true` + `x/y/rotate/z`）。
  - `type BirdView = { id, name, nameAlt, orderLabel, familyLabel, familyLatin, sci, pinyin?, iucn?, url, meetsQualityBar, isDefault, x?, y?, rotate? }`。
  - `async function getBirdViews(locale: Locale): Promise<BirdView[]>`（保持 IOC seq 顺序 = 数组顺序）。
  - 自定义元素名（后续 Task 依赖）：`bird-board`、`bird-grid`、`bird-piece`、`bird-tray`、`bird-menu`、`bird-card`、`bird-hint`。
  - `bird-piece` 上的数据属性（后续 Task 的信息卡/飞入依赖）：`data-id data-name data-name-alt data-order data-family data-family-latin data-sci data-pinyin data-iucn data-url`。
  - CSS 变量（bird-piece）：`--x --y --rot --z --s --sx`；图类名 `.bird-img`、名类名 `.bird-name`。

- [ ] **Step 1: 写回归脚本（先失败）** — `scripts/tests/birds-check.sh`

仿 `board-check.sh` 头部（`set -euo pipefail`、`pass/fail/assert_file/assert_has/assert_lacks/assert_match`、受控 `.env` 备份恢复 trap、`printf 'SITE_URL=https://example.com\n' > .env`、`npm run build`）。本 Task 断言：

```bash
# 导航入口
assert_has dist/index.html 'href="/birds"' "中文导航含 /birds 入口"
assert_has dist/en/index.html 'href="/en/birds"' "英文导航含 /en/birds 入口"
# zh 路由 + SSR 骨架
assert_file dist/birds/index.html "中文 /birds 路由存在"
assert_has dist/birds/index.html "<bird-board" "bird-board 容器渲染"
assert_has dist/birds/index.html "<bird-tray" "托盘渲染"
assert_match dist/birds/index.html 'bird-piece[^>]*--x:' "默认 piece 带 SSR --x"
assert_has dist/birds/index.html 'class="bird-img"' "鸟图按徽章范式渲染"
assert_has dist/birds/index.html 'raw.githubusercontent.com' "hotlink 外链入产物"
# 默认 5 只在板上
for id in Aix_galericulata Calypte_anna Aptenodytes_forsteri Alcedo_atthis Ara_macao; do
  assert_match dist/birds/index.html "bird-piece[^>]*data-id=\"$id\"" "默认 5 只之一 $id 在板上"
done
# 授权署名
assert_has dist/birds/index.html 'PolyForm' "页脚含许可署名"
assert_has dist/birds/index.html 'huashu-bird-sticker' "页脚含仓库链接"
# en 路由 + 英文名 + 无 .en 泄漏 + 切换器
assert_file dist/en/birds/index.html "英文 /en/birds 路由存在"
assert_has dist/en/birds/index.html 'Emperor Penguin' "英文页取 en 名"
assert_has dist/birds/index.html '帝企鹅' "中文页取 zh 名"
assert_lacks dist/birds/index.html 'astro.en' "中文页不泄漏 .en id"
assert_has dist/birds/index.html 'data-language-switch' "中文页有语言切换器"
```

- [ ] **Step 2: 跑脚本确认失败** — Run: `bash scripts/tests/birds-check.sh`；Expected: FAIL（`dist/birds/index.html` 不存在）。

- [ ] **Step 3: 建数据模块** — `src/data/birds.ts`

写 `export type BirdItem = {…}`（字段照 spec §6）；`export const BIRD_ITEMS: BirdItem[] = [ … ]` **逐字拷自 spec 附录 A 的 44 条**；给默认 5 只补几何（`x/y/rotate` 照 spec §6 表，`z` 依次 1..5）。文件顶部注释说明来源与 hotlink/授权。

- [ ] **Step 4: 加取数函数** — `src/lib/content.ts`

在文件末尾加 `export type BirdView = {…}` 与 `export async function getBirdViews(locale: Locale): Promise<BirdView[]>`：`import { BIRD_ITEMS } from "@/data/birds"`；按 locale 选名（zh 页 `name=zh, nameAlt=en`；en 页 `name=en, nameAlt=zh`；某语言缺失回落另一个）；`orderLabel = locale==="en" ? order : orderZh`，`familyLabel = locale==="en" ? family : familyZh`；`isDefault = !!item.default`；透传 `x/y/rotate`（仅默认件有）。保持数组顺序（IOC seq）。

- [ ] **Step 5: 加 i18n 文案** — `src/lib/i18n.ts`

`ZH_STRINGS` 与其后 `en` 对象**各补**同一组键（值分别中/英）：`navBirds`（鸟类 / Birds）、`birdsTitle`（鸟类收藏板 / Bird Board）、`birdsDesc`、`birdsTrayLabel`、`birdsReset`（重置 / Reset）、`birdsCount`（已上板 / On board）、`birdsHint`、`birdsMenuLabel`、`birdsInfo`、`birdsInfoSource`、`birdsInfoClose`、`birdsAddAria`（加入 / Add）、`birdsCredit`（署名，见 spec §10）。径向菜单 op 文案**复用**现有 `boardZoomIn/boardZoomOut/boardRotateCw/boardRotateCcw/boardMirror/boardBringFront/boardSendBack`（同图标语义）。

- [ ] **Step 6: 加导航 + 切换器白名单** — `src/consts.ts`、`src/components/LanguageSwitch.astro`

`NAVIGATION` 在 `navBoard` 项后加 `{ key: "navBirds", href: "/birds", bilingual: true }`。`LanguageSwitch.astro` 的 `hasEnglishTwin` 追加 `|| stripped === "/birds" || stripped.startsWith("/birds/")`，并把注释里的白名单说明补上 birds。

- [ ] **Step 7: 写 BirdBoard SSR 骨架 + scoped CSS** — `src/components/BirdBoard.astro`

frontmatter：`import { getBirdViews } from "@/lib/content"`、`import { t, type Locale } from "@/lib/i18n"`；`const { locale } = Astro.props`；`const views = await getBirdViews(locale)`；`const onBoard = views.filter(v=>v.isDefault)`、`const inTray = views.filter(v=>!v.isDefault)`。

标记（本 Task 只到静态，`bird-menu`/`bird-card`/`dialog` 骨架先渲染但 `hidden`，脚本 Task 2+ 才加）：
```astro
<bird-board data-tool="drag">
  <bird-grid>
    {onBoard.map(v => <bird-piece data-id={v.id} data-name={v.name} data-name-alt={v.nameAlt}
      data-order={v.orderLabel} data-family={v.familyLabel} data-family-latin={v.familyLatin}
      data-sci={v.sci} data-pinyin={v.pinyin} data-iucn={v.iucn} data-url={v.url}
      role="group" aria-label={v.name}
      style={`--x:${v.x}; --y:${v.y}; --rot:${v.rotate}deg; --z:${i+1}; --s:1; --sx:1`}>
      <img class="bird-img" src={v.url} alt={v.name} loading="lazy" decoding="async" onerror="this.hidden=true" />
      <span class="bird-name">{v.name}</span>
    </bird-piece>)}
  </bird-grid>
  <bird-tray aria-label={t(locale,"birdsTrayLabel")}>
    {inTray.map(v => <button type="button" class="tray-item" data-id={v.id} data-name={v.name} … data-url={v.url}
      aria-label={`${t(locale,"birdsAddAria")} ${v.name}`}>
      <img class="tray-thumb" src={v.url} alt="" loading="lazy" decoding="async" onerror="this.hidden=true" />
      <span class="tray-name">{v.name}</span>
    </button>)}
  </bird-tray>
  <bird-menu role="toolbar" aria-label={t(locale,"birdsMenuLabel")} hidden> …8 枚 menu-btn（图标照抄 Board.astro）… </bird-menu>
  <bird-card role="dialog" aria-label={t(locale,"birdsInfo")}" data-source-label={t(locale,"birdsInfoSource")}" hidden> …close 钮 + .card-name/.card-name-alt/.card-taxa/.card-iucn/.card-sci/.card-source… </bird-card>
  <bird-hint><button type="button" class="bird-reset">{t(locale,"birdsReset")}</button> <span class="bird-count" data-count></span> {t(locale,"birdsHint")}</bird-hint>
  <dialog class="bird-preview" aria-label={t(locale,"birdsInfo")} data-bubble-label="…"><button class="preview-close" …></button></dialog>
</bird-board>
```
（`onerror="this.hidden=true"` = 外链挂了藏图留名，满足 Review Focus 第 1 条。）

scoped `<style>`：`bird-grid` 抄 `board-grid`（中性底 `light-dark(#f5f5f4,#26221c)` + 极淡网格 + `isolation:isolate` + `overflow:clip` + `min-height:clamp(28rem,66vh,46rem)` + `padding`）；`bird-piece` 抄 `board-piece` 绝对定位（`left:calc(var(--x)*100%)` 等）；`.bird-img { height:var(--bird-h,clamp(6rem,12vw,10rem)); width:auto; filter:drop-shadow(0 3px 7px rgb(0 0 0/.28)); }`；`.bird-name` 抄 `.badge-title`（默认 `opacity:0` 占位、hover/选中/拖拽浮现）；`bird-tray` 宽屏水平滚动带（`display:flex; gap; overflow-x:auto`）、`.tray-item` 为按钮（缩略图 `height:clamp(2.5rem,5vw,3.5rem)` + `.tray-name` hover 显）；`bird-menu/bird-card` 抄 `board-menu/board-card`（含 `--menu-r:74px`/`--menu-btn:30px`、径向 transform、翻转）；`bird-hint` 抄 `board-hint`（`display:none`，`bird-board[data-interactive]` 才显）；`@keyframes bird-toss` 抄 `board-toss`（Task 3 用）；窄屏 `@media (width<64rem)`：`bird-grid`→grid、`bird-piece`→`position:static;transform:none`、`bird-tray`→静态网格且 `.tray-name` 常显、`bird-menu/bird-card/bird-hint`→`display:none`。

- [ ] **Step 8: 写 zh + en 路由 + 署名** — `src/pages/birds/index.astro`、`src/pages/en/birds/index.astro`

照 `src/pages/board/index.astro`：`import Layout/MetaPage/ListingHead/BirdBoard`、`getBirdViews`。zh 页 `title="鸟类收藏板"`、`alternates={{zh:"/birds",en:"/en/birds"}}`、`kicker={`~/birds · ${birds.length} 种`}`、`<BirdBoard locale="zh" />`；en 页对应英文、`locale="en"`。**署名**：`BirdBoard` 下方加一段 credit（文案取 `t(locale,"birdsCredit")`，含仓库链接 `https://github.com/alchaincyf/huashu-bird-sticker` 与许可 `…/blob/main/LICENSE.md`，`target=_blank rel=noopener`）。

- [ ] **Step 9: 跑脚本确认通过 + 构建** — Run: `bash scripts/tests/birds-check.sh`；Expected: PASS（全部断言绿）。

- [ ] **Step 10: 人工浏览器核验** — Run: `npm run dev`，开 `http://localhost:4321/birds` 与 `/en/birds`（用 playwright skill 或浏览器）。核验：宽屏默认 5 只散在板上、托盘 39 只可横向滚；亮/暗两主题下白边贴纸靠 drop-shadow 与板面分离、不糊；窄屏 `<64rem` 变只读网格铺全部 44 只、名字常显、无溢出；zh/en 名正确、语言切换器出现且互跳；页脚署名可见。截图存 `.playwright-cli/`。

- [ ] **Step 11: 格式化 + 提交**
```bash
npm run format
git add src/data/birds.ts src/lib/content.ts src/lib/i18n.ts src/consts.ts src/components/LanguageSwitch.astro src/components/BirdBoard.astro src/pages/birds src/pages/en/birds scripts/tests/birds-check.sh
git commit -m "Add static bilingual /birds board (SSR skeleton, 44 species)"
```

---

## Task 2: 客户端激活——拖拽 + 径向菜单 + 信息卡

**Files:** Modify `src/components/BirdBoard.astro`（加 `<script>`）、`scripts/tests/birds-check.sh`

**Interfaces:**
- Consumes: Task 1 的元素名与 `bird-piece[data-*]`、CSS 变量、`bird-menu`/`bird-card` 骨架。
- Produces: `bird-board` 挂载后置 `data-interactive`；`ops` 表（zoom/rotate/mirror/front/back）；信息卡从选中 piece 的 `dataset` 建档；`enable(on)` 随断点绑/解事件。

- [ ] **Step 1: 加脚本断言（先失败）** — `scripts/tests/birds-check.sh` 追加：
```bash
bird_js="$(grep -rl 'customElements.define("bird-board"' dist/_astro 2>/dev/null | head -1)"
[ -n "${bird_js}" ] || fail "找不到 bird-board 激活脚本（组件脚本未入产物？）"
assert_has "${bird_js}" "setPointerCapture" "拖拽用 Pointer Capture"
assert_has "${bird_js}" "matchMedia" "宽屏门槛判定"
```

- [ ] **Step 2: 跑脚本确认失败** — Run: `bash scripts/tests/birds-check.sh`；Expected: FAIL（找不到激活脚本 chunk）。

- [ ] **Step 3: 写激活脚本** — `BirdBoard.astro` 末尾加 `<script>`

`if (!customElements.get("bird-board")) customElements.define("bird-board", class extends HTMLElement { connectedCallback(){…} })`。**照抄 `Board.astro` 的 `stamp-board` 脚本并裁剪**：
- 保留：`matchMedia("(width>=64rem)")` 门槛、`dragstart` 拦截、`topZ/bottomZ`、`select/deselect`、`tool` 内部态、`ops`（zoom-in/out ×÷1.25 钳 [0.5,2.5]、rotate ±15°、mirror 切 `--sx`、front/back 改 `--z`）、径向菜单 `placeMenu/openMenu/closeMenu/settleMenu`（`--a` 从 −90° 到 +90°、右半圆放不下翻左半圆）、三条唤起入口（右键 `contextmenu` / 触屏长按 500ms `pressTimer` / 键盘 Enter·空格·菜单键·Shift+F10）、`role=toolbar` roving tabindex + 方向键、Esc 退、`placeCard/showCard/closeCard/toggleCard`、拖拽 `onDown/onMove/onUp`（阈值 4px、夹紧 `[0,1−piece/board]`、`setPointerCapture`、拖后抑制 click）、`enable(on)` 随断点设 `tabIndex` 0/−1、`resize`/断点变化收菜单与卡片、`this.dataset.interactive=""`。
- **改信息卡建档 `infoOf/fillCard`**：不再读 `aria-label + a[href]`，改读选中 piece 的 `dataset`——`.card-name=name`、`.card-name-alt=nameAlt`、`.card-taxa=`「order · family（familyLatin）」、`.card-iucn=iucn`（空则隐藏该行）、`.card-sci=`「sci · pinyin」（pinyin 空则只 sci）、`.card-source=` 用 `data-url` 建 `<a target=_blank rel=noopener>`（文本去协议头）。所有字段空值优雅降级、绝不写 `undefined`。
- **删** `/board` 专有：`data-view`/分类标签（`board-tabs`）、`data-kind` stamp/badge 分支、`denomination/postmark`、dev 编辑条相关。
- 菜单 op 的 aria/title 用 `t(locale,"board*")` 已在骨架 SSR 写好；脚本不含 i18n 字典。

- [ ] **Step 4: 跑脚本确认通过 + 构建** — Run: `bash scripts/tests/birds-check.sh`；Expected: PASS。

- [ ] **Step 5: 人工浏览器核验** — dev server 开 `/birds`。核验：拖拽 5 只顺滑、拖不出板、抓起置顶；右键/长按/Tab+Enter 唤起径向菜单，8 钮散开、贴边翻左半圆；缩放/旋转/镜像/置顶/置底生效；info 钮开信息卡、双语名 + 目·科（拉丁）+ IUCN + 学名·拼音 + 源链（点开是新标签的 webp）；`reduced-motion` 下无过渡但操作即时生效；断窗口过 64rem 门槛时菜单/卡片收起。核验信息卡对 `iucn` 空的鸟（如大斑几维）不显空行、无 `undefined`。截图。

- [ ] **Step 6: 提交**
```bash
npm run format
git add src/components/BirdBoard.astro scripts/tests/birds-check.sh
git commit -m "Activate /birds: drag, radial menu, bilingual info card"
```

---

## Task 3: 托盘点击飞入 + 重置 + 收集计数

**Files:** Modify `src/components/BirdBoard.astro`、`scripts/tests/birds-check.sh`

**Interfaces:**
- Consumes: `bird-tray .tray-item[data-*]`、`bird-grid`、`bird-toss` keyframes、Task 2 的 `enable`/拖拽绑定/`topZ`。
- Produces: `addBird(trayBtn)`（建 `bird-piece` 飞入）、`resetBoard()`、计数更新 `updateCount()`。

- [ ] **Step 1: 加断言（先失败）** — `birds-check.sh` 追加：
```bash
assert_has dist/birds/index.html 'class="bird-reset"' "重置按钮渲染"
assert_has dist/birds/index.html 'data-count' "收集计数占位渲染"
assert_match dist/birds/index.html '@keyframes bird-toss|bird-toss' "飞入关键帧入产物"
bird_js="$(grep -rl 'customElements.define("bird-board"' dist/_astro 2>/dev/null | head -1)"
assert_has "${bird_js}" "bird-enter" "飞入类名入脚本"
```
（注：`@keyframes` 在 scoped `<style>` 里，Astro 可能提为 CSS chunk；若 HTML 断言不稳，改在 `dist/_astro/*.css` 里 grep `bird-toss`。）

- [ ] **Step 2: 跑脚本确认失败** — Run: `bash scripts/tests/birds-check.sh`；Expected: FAIL（脚本里还没有 `bird-enter`/飞入逻辑）。

- [ ] **Step 3: 写飞入 + 重置 + 计数** — `BirdBoard.astro` 脚本内

- `updateCount()`：数当前 `bird-grid` 里 `bird-piece` 数 N，写 `.bird-count` 文本 = `${t?}N/44`（用骨架 `data-count` + `birdsCount` 文案；挂载即调一次显示 5/44）。
- `addBird(btn)`（仅宽屏门槛内）：读 `btn.dataset` → `document.createElement("bird-piece")`，写全套 `data-*`、`aria-label`、`role="group"`、内部 `<img class="bird-img" …onerror>` + `<span class="bird-name">`；随机落位 `x∈[0.04, 1−0.04−pw/boardW]`、`y∈[0.04, 1−0.04−ph/boardH]`（pw/ph 用建后测量或估算）、`--rot` 取 ±6° 随机、`--z=topZ+1`、`--s=1`、`--sx=1`；append 到 `bird-grid`；绑 `onDown`（拖拽）+ 双击预览（Task 4）+ `tabIndex=0`；加 `bird-enter` 类触发 `bird-toss` 飞入（`--enter-delay` 0），`animationend/cancel` 摘类；`btn.remove()`（从托盘移除）；`updateCount()`。
- 给每个 `.tray-item` 绑 `click` → `addBird`（宽屏）；窄屏不绑（只读网格）。
- `resetBoard()`：移除所有「后加的」piece（用 `data-added` 标记区分默认 5 只）、把默认 5 只复位到 SSR 初始 `--x/--y/--rot`（存一份初始值）、把托盘恢复满 39（重新 append 之前 `remove` 的按钮，或按 `inTray` 数据重建）、`updateCount()` 回 5/44。给 `.bird-reset` 绑 click。
- `prefers-reduced-motion` 命中时飞入不加 `bird-enter`（直接落位），加鸟/拖拽本身不禁用。

- [ ] **Step 4: 跑脚本确认通过 + 构建** — Run: `bash scripts/tests/birds-check.sh`；Expected: PASS。

- [ ] **Step 5: 人工浏览器核验** — dev 开 `/birds`。核验：点托盘一只 → 飞入板、随机落位、从托盘消失、计数 +1、可拖可唤菜单；连点几只不重叠卡死；把 39 只全加完 → 计数 44/44、板不破、托盘空；点重置 → 精确回默认 5 只（位置复位）+ 满 39 托盘 + 计数 5/44；`reduced-motion` 下加鸟直接落位无飞入但可用；窄屏托盘为静态网格、点击不加鸟。截图（含 mid-flight 飞入与加满态）。

- [ ] **Step 6: 提交**
```bash
npm run format
git add src/components/BirdBoard.astro scripts/tests/birds-check.sh
git commit -m "Add /birds tray fly-in, reset, and collect counter"
```

---

## Task 4: 双击原图预览（复用 glass-bubble）

**Files:** Modify `src/components/BirdBoard.astro`、`src/styles/glass-bubble.css`、`scripts/tests/birds-check.sh`

**Interfaces:**
- Consumes: `dialog.bird-preview` 骨架（Task 1）、`@/lib/glass-bubble-element` 的 `registerGlassBubble`、`@/lib/glass-bubble` 的 `GLASS_DEFAULTS`。
- Produces: `openPreview(piece)` / `closePreview()`。

- [ ] **Step 1: 加断言（先失败）** — `birds-check.sh` 追加：
```bash
assert_has dist/birds/index.html 'class="bird-preview"' "预览 dialog 骨架渲染"
assert_has src/styles/glass-bubble.css 'bird-preview' "全局样式覆盖 bird-preview"
```

- [ ] **Step 2: 跑脚本确认失败** — Run: `bash scripts/tests/birds-check.sh`；Expected: FAIL（`glass-bubble.css` 还没 `bird-preview`）。

- [ ] **Step 3: 扩全局样式（additive）** — `src/styles/glass-bubble.css`

把 5 处 `dialog.board-preview`、`dialog.board-preview::backdrop`、`dialog.board-preview glass-bubble`、`dialog.board-preview .preview-close`（含 `:hover`/`:focus-visible`）选择器各加一个并列 `dialog.bird-preview…`（逗号 additive，不改原 `board-preview` 规则、不动 `/board`）。

- [ ] **Step 4: 写预览脚本** — `BirdBoard.astro` 脚本内

顶部 `import { GLASS_DEFAULTS } from "@/lib/glass-bubble"` + `import { registerGlassBubble } from "@/lib/glass-bubble-element"`；`registerGlassBubble()`。**照抄 `Board.astro` 的 `openPreview/closePreview`**：双击 `bird-piece`（仅宽屏）→ `exitPicked()` → 取 `.bird-img` 的 `src` → 按视口算 `box=min(innerWidth−48, innerHeight−96, 620)`，`box>=280` 建 `<glass-bubble data-src data-size data-label>`、否则只静态图 → `dlg.replaceChildren(...)` → `dlg.hidden=false; dlg.showModal()`；`close` 事件把焦点还给唤起的 piece；点 `.preview-close`/背景/ Esc 关；关时摘泡（disconnect 释放 WebGL）。给默认 5 只与后加 piece 都绑 `dblclick`（在 `enable(on)`/`addBird` 里）。

- [ ] **Step 5: 跑脚本确认通过 + 构建** — Run: `bash scripts/tests/birds-check.sh`；Expected: PASS。

- [ ] **Step 6: 人工浏览器核验** — dev 开 `/birds`。核验：双击板上任一只（默认或后加）→ 弹玻璃泡预览、隔着泡拖动能折射、图是那只鸟的全分辨率原图；Esc/背景/关闭钮都能关、焦点回该鸟；`/board` 的双击预览仍照常（未被 glass-bubble.css additive 改动弄坏——顺带跑 `bash scripts/tests/board-check.sh` 确认绿）。截图（亮/暗）。

- [ ] **Step 7: 提交**
```bash
npm run format
git add src/components/BirdBoard.astro src/styles/glass-bubble.css scripts/tests/birds-check.sh
git commit -m "Add /birds double-click glass-bubble preview"
```

---

## Task 5: 组件文档 + 全量回归 + 清理

**Files:** Create `docs/components/bird-board.md`；Delete `.recon/`；（核验）跑全部回归脚本

**Interfaces:** 无（收尾）。

- [ ] **Step 1: 写组件文档** — `docs/components/bird-board.md`

照 `docs/components/board.md` 与 `docs/components/README.md` 模板，记录：一句话说明、文件位置、快速上手（`<BirdBoard locale="zh" />`）、Props、数据字段（`BirdItem`，指向 spec 附录 A）、无障碍与降级（无 JS / 窄屏 / 键盘 / 触屏 / reduced-motion）、注意事项（不持久化、hotlink 与授权、托盘飞入与重置、数据落 DOM 的 `data-*` 约定、双击预览）、与 `/board` 的关系（fork、不共享引擎）。

- [ ] **Step 2: 删除临时调研目录** — Run: `rm -rf .recon`；Expected: `.recon` 不存在（`ls -a` 确认）；`git status` 不含 `.recon`/`species.json`。

- [ ] **Step 3: 全量回归门槛** — Run:
```bash
npm run format:check && npm run build \
  && bash scripts/tests/birds-check.sh \
  && bash scripts/tests/board-check.sh \
  && bash scripts/tests/i18n-check.sh
```
Expected: 全绿（`/birds` 未破坏 `/board`、i18n、格式、构建）。

- [ ] **Step 4: 提交**
```bash
npm run format
git add docs/components/bird-board.md
git commit -m "Document bird-board component; finalize /birds"
```

---

## Self-Review（作者自查）

- **Spec 覆盖**：spec §5 路由/导航→T1；§6 数据模型→T1；§7 取数→T1；§8.1 SSR→T1；§8.2 拖拽/菜单/信息卡→T2、托盘飞入/重置→T3、双击预览→T4；§8.3 a11y/motion→T2/T3 人工核验；§8.4 窄屏→T1；§9 i18n→T1（+ LanguageSwitch）；§10 署名→T1；§11 组件文档→T5；§12 回归→各 Task + T5；§13/§14 builder 决议→已内化（导航 T1、托盘布局 T1、源链 T2、预览 T4、计数 T3、署名 T1、双语 T1）。附录 A 数据→T1 Step 3 逐字拷。无遗漏。
- **类型一致**：`BirdItem`/`BirdView`/`getBirdViews`/元素名/`data-*`/CSS 变量在 T1 定义，T2–T4 一致引用。
- **比例**：BirdBoard.astro 的完整代码不转录——计划只给元素名、`data-*`、CSS 变量、关键算法值（阈值/钳制/角度/落位范围）与「照抄 Board.astro 哪段、裁剪什么」，body 由实现者写。
- **Review Focus 落测**：外链挂→T1 `onerror` + Step 10 核验；窄屏→T1 Step 10；键盘→T2/T3 Step 5；reduced-motion→T3 Step 5；加满 44 + 重置→T3 Step 5；字段缺失→T2 Step 5。
