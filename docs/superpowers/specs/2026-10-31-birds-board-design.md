# 鸟类收藏板 `/birds` 设计

> 状态：待用户批准。日期：2026-10-31。
> 参照现有实现：`src/components/Board.astro`、`src/data/board.ts`、`src/pages/board/index.astro`、
> `docs/superpowers/specs/2026-10-17-board-collection-design.md`。

## 1. 意图与背景（why）

用户想「参考 `/board` 集成 [alchaincyf/huashu-bird-sticker](https://github.com/alchaincyf/huashu-bird-sticker)，
单开一个 `/birds` 页面玩玩」。经对话收敛为：

- 从花叔《全球鸟类贴纸库》取 **「44 目各一只」共 44 张招牌鸟贴纸**（不是原提的 365 只蜂鸟——365 枚自由拖拽件在性能与「拼贴」语义上都不成立）。
- 做成一块 **可拖拽拼贴的收藏板**：板上 SSR 默认摆 **5 只**，其余 **39 只**放在「托盘」里，由访客 **自己点上来收集**。
- 纯前端玩具、**不持久化**（刷新回默认 5 只，与 `/board` 同哲学）。

为什么值得做：`/board` 是「作者手工策展」的静态拼贴；`/birds` 把它变成「访客参与收集」的互动玩具，
顺带展示这个双语站消化外部数据集（IOC 分类 + 43 语言鸟名 + 保护等级）的能力。

## 2. 数据来源与授权（constraints）

- **来源**：`alchaincyf/huashu-bird-sticker`，分类依据 IOC 世界鸟类名录 v15.2。
- **资产策略 = hotlink（用户拍板的 b 方式）**：鸟贴纸用
  `https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/<sticker.file>`
  直接外链，**本地零体积、不 vendor、不下载贴纸**。
- **数据获取**：recon 阶段只 sparse-checkout 了 `data/species.json`（32MB，**仅调研用**，
  已抽出 44 条到本文档附录 A）。**构建产物与仓库里都不含 `species.json`**；`src/data/birds.ts`
  由附录 A 手工落成静态数组。`.recon/` 是临时目录，交付前删除、不入库。
- **授权（必须在页脚署名，见 §10）**：
  - 贴纸 = PolyForm Shield 1.0.0（可商用；唯一限制是不得用于「与鸣迹竞争的观鸟/识鸟/图鉴类 App 或网站」——本站是个人博客，不触发该限制）。
  - 数据 = MIT；分类与多语种鸟名 = IOC v15.2（CC BY 3.0）；形态生态 = AVONET（CC BY 4.0）。
- **44 只清单**：见附录 A（含 `id`/目/科/中英名/学名/拼音/IUCN/质量线/hotlink URL），已由 recon 确定并经用户过目批准。

## 3. 目标 / 非目标 / 反目标

**Goals**
- 双语路由 `/birds`（zh）与 `/en/birds`（en）。
- **SSR 静态骨架**：默认 5 只 `bird-piece` 铺在板上，无 JS 也成图（可看、信息在 DOM）。
- **客户端渐进增强**：拖拽移动、径向菜单（缩放/旋转/镜像/置顶/置底/信息）、托盘点击飞入、重置。
- 鸟按 **「徽章」范式**渲染：随形 + `drop-shadow`、webp `<img>`，**无齿孔、无邮票框**。
- **信息卡**：zh/en 名 + 目/科 + IUCN + 学名 + 拼音 + 源链（hotlink URL）。
- **窄屏 `<64rem` 回退**：只读响应式网格，展示全部 44 只（无拖拽/托盘飞入/菜单）。
- **页脚授权署名**。
- **导航入口** + **回归脚本** `scripts/tests/birds-check.sh` + **组件文档** `docs/components/bird-board.md`。

**Non-goals**
- 不持久化（无 localStorage、无后端）；刷新回默认 5 只。
- 不 vendor 贴纸、不做 Astro 图片优化（外链 webp，浏览器自行缩放）。
- 不做搜索/筛选/分类标签（44 只一屏托盘够翻）。
- 不做键盘调位（与 `/board` 一致：拖拽仅指针；但保留可聚焦 + 径向菜单键盘入口）。
- **不改 `/board` 一行**（approach A）。
- 不用全部 365 蜂鸟、不用全 11064 种；只 44 目各一只。

**Anti-goals（技术上能跑也算失败）**
- 把成百上千张贴纸塞进板导致卡顿。
- `/birds` 连带弄坏 `/board`（`board-check.sh` 回归红）。
- 漏掉授权署名（许可合规问题）。
- 外链失效时整块空白、无兜底。

## 4. 方案（approaches）

- **A · 自建同级组件（用户选定）**：新建 `BirdBoard.astro` + `src/data/birds.ts`，
  **借用** `/board` 成熟的拖拽 / 径向菜单 / 信息卡 / `board-toss` 入场「范式」，但**不动 `/board` 一行**；
  裁掉鸟用不到的部分（齿孔邮票框、stamp/badge 分类标签、dev 布局编辑器），加上「托盘 + 点击飞入」。
  → 零回归风险、最快落地。代价：重复一部分交互 JS。
- **B · 抽公共引擎**：把拖拽 + 径向菜单 + 信息卡提炼成 `src/lib/board-engine.ts`，两板共用。
  → DRY，但要重构 heavily-tested 的 `/board`，风险/工作量更大。**deferred**：等出现第三个「board 类」页面再按 rule of three 抽。
- **C · 给 `Board.astro` 加 `mode` 分支**：**rejected**——鸟与邮票差异够大，只会把 1500 行的 `Board.astro` 搅得更乱。

**用户选 A。**

## 5. 落位与页面结构

新建路由，与 `/board` 平级：

- `src/pages/birds/index.astro`（zh）
- `src/pages/en/birds/index.astro`（en）

骨架沿用现成范式：

```astro
---
import Layout from "@/layouts/Layout.astro"
import MetaPage from "@/components/MetaPage.astro"
import ListingHead from "@/components/ListingHead.astro"
import BirdBoard from "@/components/BirdBoard.astro"
import { getBirdViews } from "@/lib/content"
const birds = await getBirdViews("zh")   // en 路由传 "en"
---
<Layout>
  <MetaPage slot="head" title="鸟类收藏板"
    description="44 目各一只鸟类贴纸，摆成一块可拖拽的收藏板；点托盘自己收集。"
    alternates={{ zh: "/birds", en: "/en/birds" }} />
  <ListingHead kicker={`~/birds · ${birds.length} 种`} title="鸟类收藏板" desc="…" />
  <BirdBoard locale="zh" />
</Layout>
```

- 导航：`src/consts.ts` 的 `NAVIGATION` 加 `{ key: "navBirds", href: "/birds", bilingual: true }`。
- i18n：`src/lib/i18n.ts` 的 `ZH_STRINGS` 与 `en` 各补 `navBirds`（zh「鸟类」/ en「Birds」）等 key（见 §9）。

## 6. 数据模型：`src/data/birds.ts`

```ts
export type BirdItem = {
  id: string          // 稳定键 = 学名下划线形式（Struthio_camelus），与 hotlink 文件同名
  order: string       // 目·英（Struthioniformes）
  orderZh: string     // 目·中（鸵鸟目）
  family: string      // 科·英（Ostriches）
  familyLatin: string // 科·拉丁（Struthionidae）
  familyZh: string    // 科·中（鸵鸟科）
  sci: string         // 学名（Struthio camelus）
  en: string          // 英文名（Common Ostrich）
  zh: string          // 中文名（非洲鸵鸟）
  pinyin?: string     // 拼音（fēi zhōu tuó niǎo）
  iucn?: string       // 保护等级（LC/NT/VU/EN/CR；空=未评估）
  url: string         // hotlink webp 绝对 URL
  meetsQualityBar: boolean
  default?: boolean   // 是否默认 5 只之一
  x?: number; y?: number; rotate?: number  // 仅默认 5 只给初始几何（x/y 为 0–1 板宽高占比，rotate 为 deg）
}
export const BIRD_ITEMS: BirdItem[] = [ /* 附录 A 的 44 条 */ ]
```

- **名字自带 zh+en，无需 `L10n` / `.en.md` 孪生**（比 `/board` 简单）。
- 顺序 = IOC `seq`（附录 A 已按此排好），消费方直接沿用。
- **默认 5 只**（`default:true`）：鸳鸯、安氏蜂鸟、帝企鹅、普通翠鸟、绯红金刚鹦鹉。
  建议初始几何（builder 可按视觉微调）：
  | id | x | y | rotate |
  |--|--|--|--|
  | Aix_galericulata（鸳鸯） | 0.10 | 0.14 | -4 |
  | Calypte_anna（安氏蜂鸟） | 0.36 | 0.06 | 5 |
  | Aptenodytes_forsteri（帝企鹅） | 0.60 | 0.16 | -3 |
  | Alcedo_atthis（普通翠鸟） | 0.16 | 0.52 | 4 |
  | Ara_macao（绯红金刚鹦鹉） | 0.56 | 0.50 | -5 |

## 7. 取数：`src/lib/content.ts`

```ts
export type BirdView = {
  id: string
  name: string        // 按 locale：zh 页取 zh，en 页取 en；缺失回落另一语言
  nameAlt: string     // 另一语言名（信息卡并列展示）
  orderLabel: string  // locale 命中：zh→orderZh，en→order
  familyLabel: string // zh→familyZh，en→family（拉丁科名 familyLatin 始终另带，信息卡用）
  familyLatin: string
  sci: string
  pinyin?: string
  iucn?: string
  url: string
  meetsQualityBar: boolean
  isDefault: boolean
  x?: number; y?: number; rotate?: number
}
export async function getBirdViews(locale: Locale): Promise<BirdView[]>
```

- 实现：`BIRD_ITEMS.map(...)`，按 locale 选名（沿用现有 `pick()` 思路，但源字段是 `zh`/`en` 而非 `L10n`），保持数组顺序（IOC seq）。
- 保留 `async` 以对齐既有 `await getBoardViews(...)` 调用风格。
- 不做 draft 过滤（44 只均发布态）；如日后要临时下架某只，加 `draft?: boolean` + filter。

## 8. 渲染与交互（核心）：`src/components/BirdBoard.astro`

自主定制元素（带连字符，符合项目惯例）：`bird-board`（宿主）、`bird-grid`（板面）、
`bird-piece`（每只鸟）、`bird-tray`（托盘）。scoped CSS 选择器。

**数据落 DOM（沿用 `/board` 的 board-card「数据住 DOM」惯例）**：每只鸟的完整信息以 `data-*`
挂在 `bird-piece`（默认 5 只，SSR）与 `bird-tray` 里的按钮（39 只，SSR）上——
`data-id / data-name / data-name-alt / data-order / data-family / data-family-latin / data-sci /
data-pinyin / data-iucn / data-url`。信息卡与「点击飞入」新建的 piece 全部从这些 `data-*` 取，
脚本里不再另养一份数据。

### 8.1 SSR 静态骨架（无 JS 也看全）

- `bird-grid`：板面样式沿用 `/board` 的 `board-grid`——中性底（`light-dark(#f5f5f4,#26221c)`）+
  极淡网格 + `isolation:isolate` + `overflow:clip` + 流体 `min-height: clamp(28rem,66vh,46rem)` + `padding`。
- 默认 5 只渲染为 `bird-piece`：
  `position:absolute; left:calc(var(--x)*100%); top:calc(var(--y)*100%); transform:rotate(var(--rot)) scale(var(--s)) scaleX(var(--sx))`，
  `--x/--y/--rot/--z/--s/--sx` 由 SSR 内联 `style` 下发。
- 每只 `bird-piece` 内是「徽章」范式：
  ```html
  <img src={url} class="bird-img" alt={name} loading="lazy" decoding="async"
       width height onerror=… />
  <span class="bird-name">{name}</span>
  ```
  - `.bird-img { height: var(--bird-h, clamp(6rem,12vw,10rem)); width:auto; filter: drop-shadow(0 3px 7px rgb(0 0 0 / .28)); }`（随形、有贴纸投影、无框）。
  - `.bird-name`：默认隐形但占位（同 `/board` `.badge-title`），hover / 选中 / 拖拽时浮现。
  - `width`/`height` 或 `aspect-ratio` 防 CLS；`onerror` 兜底（外链挂了→隐藏图、常显名字，不留空白，见 §13）。
- `bird-tray`（板下方）：SSR 渲染其余 39 只为 `<button data-id …>`，每枚 = 缩略图 + 小名字。
  无 JS 时是静态一览（点击无反应）；「点托盘加鸟」提示行仅在 `bird-board[data-interactive]` 下亮出（同 `/board` hint 惯例，不承诺不存在的交互）。

### 8.2 客户端激活（渐进增强）

`customElements.define("bird-board", class extends HTMLElement { connectedCallback(){…} })`，逻辑照搬 `/board` 的 `stamp-board` 并裁剪：

- **媒体门槛**：`matchMedia("(width >= 64rem)")` 不匹配则**不绑**拖拽 / 托盘飞入 / 径向菜单（窄屏只读，见 §8.4）。
- 挂载即 `this.dataset.interactive = ""`（亮出提示行）。`this.addEventListener("dragstart", e=>e.preventDefault())` 兜住外链图的原生拖拽。
- **拖拽**（默认 5 只 + 后加的 piece 都绑）：`pointerdown` 缓存板宽高、记起点与起始 `--x/--y`、`setPointerCapture`、抬 `--z` 到 topZ+1；`pointermove` 像素→百分比、夹紧 `x∈[0,1-pieceW/boardW]`、`y∈[0,1-pieceH/boardH]`、置 `dragged`（阈值 4px）；`pointerup` 收尾。只改内存 CSS 变量，不持久化。
- **径向菜单**（`bird-menu`，结构 + 图标 + 定位算法照搬 `/board` 的 `board-menu`）：缩放±、旋转±15°、镜像、置顶、置底、信息。三条入口：鼠标右键、触屏长按 500ms、键盘（Tab 到 piece 按 Enter/空格/菜单键/Shift+F10）。`role="toolbar"` + roving tabindex + 方向键走位 + Esc 退。
- **信息卡**（`bird-card`，照搬 `board-card`）：从选中 piece 的 `data-*` 建档——大字 `name` + 次要 `nameAlt`、`orderLabel · familyLabel（familyLatin）`、`IUCN`（有则显示）、`sci` + `pinyin`（zh 页）、源链 `data-url`（`target=_blank rel=noopener`，文本去协议头）。定位/翻转算法同 `/board`。
- **托盘点击飞入**：点托盘按钮 →
  1. 用按钮的 `data-*` 在 `bird-grid` 里 `createElement("bird-piece")`，写入同款 `data-*` 与 `--x/--y/--rot/--z/--s/--sx`；
  2. **随机散点落位**：`x∈[0.04, 1-0.04-pieceW/boardW]`、`y∈[0.04, 1-0.04-pieceH/boardH]` 取随机（避免正中重叠），`rot` 取 ±6° 随机，`z` = topZ+1；
  3. 复用 `board-toss` 入场动画飞入（`bird-piece.bird-enter`，错峰延迟）；
  4. 该按钮从托盘移除（或 `disabled` + 视觉淡出），托盘计数更新；
  5. 新 piece 绑拖拽 + 双击预览（若含，见下）+ 可聚焦，与默认 piece 同权。
- **重置**：一个「重置」按钮（放在提示行内）→ 移除所有「后加的」piece、把托盘恢复满 39、默认 5 只复位到附录/§6 的初始 `x/y/rot`。纯客户端、不刷新。
- **双击原图预览（nice-to-have，复用 glass-bubble）**：双击 `bird-piece` → 复用 `/board` 的
  `dialog.board-preview` + `registerGlassBubble()`，把该 webp 原图搬进玻璃泡预览。cheap reuse、增趣；builder 可含（见 §13）。

### 8.3 输入、可访问性、动效

- Pointer Events 统一鼠标/触屏/笔；不做键盘调位（同 `/board`）。
- `bird-piece` 宽屏 `tabIndex=0`、`:focus-visible` 走全站 `accent` 焦点环、`aria-label=name`。托盘按钮是真 `<button>`，`aria-label` = 「加入 {name}」（en：`Add {name}`）。
- `prefers-reduced-motion: reduce`：去掉 `board-toss` 飞入与 hover-lift 过渡（拖拽本身不禁用，用户主动操作）。

### 8.4 窄屏 `<64rem` 回退

- `bird-grid` → `display:grid`（`auto-fill minmax(min(100%,12rem),1fr)`），`bird-piece` → `position:static; transform:none`；
  默认 5 只复位为静态卡片。
- `bird-tray` → 静态网格，39 只缩略图 **名字常显**（不再是按钮语义 / 不可加）。
- 拖拽 / 飞入 / 径向菜单 / 信息卡 / 提示行 全关（`display:none` 或不绑事件）。
- 效果：窄屏 = 只读的「44 目鸟类一览」（5 + 39 两块共 44 只全展示）；宽屏 = 可收集拼贴板。

## 9. i18n

- `/birds`（zh）取 zh 名，`/en/birds`（en）取 en 名；`getBirdViews(locale)` 负责；信息卡并列双语名。
- `src/lib/i18n.ts` 的 `ZH_STRINGS` 与 `en` **各补**（zh + en 两份都要，遵循 AGENTS.md 约定）：
  - `navBirds`（zh「鸟类」/ en「Birds」）
  - `birdsTitle`、`birdsDesc`
  - `birdsTrayLabel`（zh「还没上板的 · 点一只飞上去」/ en「Not on the board yet · click to add」）
  - `birdsAddAria`（zh「加入 {name}」/ en「Add {name}」——或用占位拼接）
  - `birdsReset`（zh「重置」/ en「Reset」）
  - `birdsHint`（拖拽 + 右键/长按/Tab 提示，仿 `boardHint`）
  - `birdsMenuLabel`、`birdsInfo`、`birdsInfoSource`、`birdsInfoClose`、（若含预览）`birdsPreview`、`birdsPreviewClose`、`birdsBubbleHint`
  - `birdsCredit`（署名，见 §10）
  - 径向菜单各 op 的 aria/title 可直接复用现有 `boardZoomIn` 等 key（同一套图标语义），或新增 `birds*` 前缀——builder 定，倾向复用以减冗余。
- 回归：改 i18n 后跑 `bash scripts/tests/i18n-check.sh`，确认不破坏既有断言（`/birds` 是否纳入 i18n-check 由 builder 定，至少不能弄红现有项）。

## 10. 授权署名（页脚，必须）

在 `/birds` 与 `/en/birds` 的 `BirdBoard` 下方（或 `ListingHead desc` 内）加一段 credit：

- **zh**：「鸟类贴纸来自花叔开源的《全球鸟类贴纸库》（观鸟 App「鸣迹」），按 PolyForm Shield 1.0.0 授权；分类与多语种鸟名来自 IOC 世界鸟类名录 v15.2（CC BY 3.0），形态生态数据来自 AVONET（CC BY 4.0）。图片经 raw.githubusercontent.com 外链。」
- **en**：对应英文。
- 链接：仓库 `https://github.com/alchaincyf/huashu-bird-sticker`、许可 `…/blob/main/LICENSE.md`。

## 11. 组件文档

按 AGENTS.md「组件用法文档」约定，新增 `docs/components/bird-board.md`（kebab-case，一篇），
记录 `bird-board` / `bird-piece` / `bird-tray` 的「SSR 静态 + 客户端激活」范式、托盘飞入、重置、
窄屏回退、hotlink 数据落 DOM 的方式、以及授权约束。参照 `docs/components/board.md` 与 `docs/components/README.md` 模板。

## 12. 回归测试

新增 `scripts/tests/birds-check.sh`（仿 `board-check.sh`，对 `dist/` grep 断言；**按选择器/属性定位而非钉 chunk 文件名**，遵循「Astro chunk 漂移」教训）：

- `dist/birds/index.html`：含 `<bird-board`、`<bird-piece`（≥5）、`--x:`、`class="bird-img"`、`raw.githubusercontent.com` hotlink、`<bird-tray`、默认 5 只的 `data-id`、署名字样（如「PolyForm」或「鸣迹」）、无 `.en` 泄漏。
- `dist/en/birds/index.html`：含 `<bird-board`、英文名（如 `Emperor Penguin`）、hotlink。
- 产物含 `customElements.define("bird-board"` 与 `setPointerCapture`（宽屏交互）。
- 提交前门槛：`npm run format:check` + `npm run build` + `bash scripts/tests/birds-check.sh`，
  并跑 `bash scripts/tests/board-check.sh` 确认没连带弄坏 `/board`。

## 13. 交给 builder 的部分（left to builder）

- 默认 5 只初始几何的微调（§6 给了建议值，按实际视觉调）。
- 托盘飞入随机落位算法的具体实现（避免重叠的策略可简单可讲究）。
- 径向菜单是否加「收回托盘」op（v1 先只做「重置」，移除单只列为可选）。
- 是否含双击 `glass-bubble` 原图预览（nice-to-have，复用 `/board` 机制，cheap）。
- `<img>` `onerror` 兜底的具体呈现（占位底 or 纯名字）。
- credit 文案的精确措辞与落点（独立页脚块 or `ListingHead desc`）。
- 信息卡里科名用拉丁（`familyLatin`）还是英文（`family`）——建议：`orderLabel · familyLabel`，括号附 `familyLatin`。
- 径向菜单 op 文案复用 `board*` key 还是新增 `birds*` key（倾向复用）。

## 14. Builder-check 决议（我以实现者视角通读后替你定的调用，均可 veto）

- **导航**：`/birds` **进主导航**——`consts.ts` 的 `NAVIGATION` 加 `{ key:"navBirds", href:"/birds", bilingual:true }` + i18n `navBirds`（zh「鸟类」/ en「Birds」）。若想当实验页藏起来，删这一行即可（同 `/figures` 被注释掉的做法）。
- **托盘布局**：宽屏 = 板下方一条水平可滚动缩略图带（`overflow-x:auto`，缩略图 + hover 显名）；窄屏 = 静态网格、名字常显。
- **信息卡源链**：指向该鸟的 hotlink webp（`data-url`，开新标签看全分辨率原图），与 `/board` 源链行为一致；页脚另有仓库总链接。
- **双击预览**：**含**——双击 `bird-piece` 复用 `/board` 的 `dialog.board-preview` + `registerGlassBubble()` 玻璃泡看原图（cheap reuse、增趣）。
- **收集计数**：提示行加一个轻量「已上板 N/44」计数，随加鸟 / 重置更新（游戏感、零成本）。
- **授权署名范围**：页脚总署名（花叔 / 鸣迹 + PolyForm Shield 1.0.0 + IOC CC BY 3.0 + AVONET CC BY 4.0 + 仓库 / 许可链接）即满足合规；**不**逐只列参考摄影师（我们展示的是重绘插画、非参考照片本身）。若你想更厚道地逐只在信息卡带 `sticker.reference`，需 recon 再抽该字段——标为可选追加。
- **外链图重量**：托盘 39 张缩略图用的是同一批 ~1000px 全尺寸 webp（CDN 无缩略图变体），靠 `loading="lazy"` + CSS 缩小显示；这是 hotlink 方案的既定取舍，可接受。
- **双语**：`/birds`（zh）+ `/en/birds`（en）都做，与 `/board` 对齐。

## 附录 A：44 只数据（可直接落进 `src/data/birds.ts`）

> 由 recon 从 `data/species.json` 抽出、按 IOC `seq` 排序、经用户批准。`url` = `BASE + sticker.file`，
> `BASE = https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/`。
> 默认 5 只标 `default:true`（其 `x/y/rotate` 见 §6，builder 在此数组上补几何字段）。

```ts
export const BIRD_ITEMS: BirdItem[] = [
  { id:"Struthio_camelus", order:"Struthioniformes", orderZh:"鸵鸟目", family:"Ostriches", familyLatin:"Struthionidae", familyZh:"鸵鸟科", sci:"Struthio camelus", en:"Common Ostrich", zh:"非洲鸵鸟", pinyin:"fēi zhōu tuó niǎo", iucn:"LC", meetsQualityBar:false, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Struthioniformes/Struthionidae/Struthio_camelus.webp" },
  { id:"Rhea_americana", order:"Rheiformes", orderZh:"美洲鸵鸟目", family:"Rheas", familyLatin:"Rheidae", familyZh:"美洲鸵科", sci:"Rhea americana", en:"Greater Rhea", zh:"大美洲鸵", pinyin:"dà měi zhōu tuó", iucn:"NT", meetsQualityBar:false, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Rheiformes/Rheidae/Rhea_americana.webp" },
  { id:"Apteryx_maxima", order:"Apterygiformes", orderZh:"无翼鸟目", family:"Kiwis", familyLatin:"Apterygidae", familyZh:"鹬鸵科", sci:"Apteryx maxima", en:"Great Spotted Kiwi", zh:"大斑几维", pinyin:"dà bān jǐ wéi", iucn:"", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Apterygiformes/Apterygidae/Apteryx_maxima.webp" },
  { id:"Casuarius_unappendiculatus", order:"Casuariiformes", orderZh:"鹤鸵目", family:"Cassowaries, Emu", familyLatin:"Casuariidae", familyZh:"鹤鸵科", sci:"Casuarius unappendiculatus", en:"Northern Cassowary", zh:"单垂鹤鸵", pinyin:"dān chuí hè tuó", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Casuariiformes/Casuariidae/Casuarius_unappendiculatus.webp" },
  { id:"Rhynchotus_rufescens", order:"Tinamiformes", orderZh:"䳍形目", family:"Tinamous", familyLatin:"Tinamidae", familyZh:"䳍科", sci:"Rhynchotus rufescens", en:"Red-winged Tinamou", zh:"红翅䳍", pinyin:"hóng chì gōng", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Tinamiformes/Tinamidae/Rhynchotus_rufescens.webp" },
  { id:"Aix_galericulata", order:"Anseriformes", orderZh:"雁形目", family:"Ducks, Geese, Swans", familyLatin:"Anatidae", familyZh:"鸭科", sci:"Aix galericulata", en:"Mandarin Duck", zh:"鸳鸯", pinyin:"yuān yāng", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Anseriformes/Anatidae/Aix_galericulata.webp", default:true },
  { id:"Chrysolophus_pictus", order:"Galliformes", orderZh:"鸡形目", family:"Pheasants & Allies", familyLatin:"Phasianidae", familyZh:"雉科", sci:"Chrysolophus pictus", en:"Golden Pheasant", zh:"红腹锦鸡", pinyin:"hóng fù jǐn jī", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Galliformes/Phasianidae/Chrysolophus_pictus.webp" },
  { id:"Caprimulgus_longipennis", order:"Caprimulgiformes", orderZh:"夜鹰目", family:"Nightjars", familyLatin:"Caprimulgidae", familyZh:"夜鹰科", sci:"Caprimulgus longipennis", en:"Standard-winged Nightjar", zh:"旗翅夜鹰", pinyin:"qí chì yè yīng", iucn:"LC", meetsQualityBar:false, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Caprimulgiformes/Caprimulgidae/Caprimulgus_longipennis.webp" },
  { id:"Steatornis_caripensis", order:"Steatornithiformes", orderZh:"油鸱目", family:"Oilbird", familyLatin:"Steatornithidae", familyZh:"油鸱科", sci:"Steatornis caripensis", en:"Oilbird", zh:"油夜鹰", pinyin:"yóu yè yīng", iucn:"LC", meetsQualityBar:false, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Steatornithiformes/Steatornithidae/Steatornis_caripensis.webp" },
  { id:"Nyctibius_grandis", order:"Nyctibiiformes", orderZh:"钩嘴夜鹰目", family:"Potoos", familyLatin:"Nyctibiidae", familyZh:"钩嘴夜鹰科", sci:"Nyctibius grandis", en:"Great Potoo", zh:"大钩嘴夜鹰", pinyin:"dà gōu zuǐ yè yīng", iucn:"LC", meetsQualityBar:false, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Nyctibiiformes/Nyctibiidae/Nyctibius_grandis.webp" },
  { id:"Podargus_strigoides", order:"Podargiformes", orderZh:"蟆口鸱目", family:"Frogmouths", familyLatin:"Podargidae", familyZh:"蟆口鸱科", sci:"Podargus strigoides", en:"Tawny Frogmouth", zh:"茶色蛙口夜鹰", pinyin:"chá sè wā kǒu yè yīng", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Podargiformes/Podargidae/Podargus_strigoides.webp" },
  { id:"Aegotheles_savesi", order:"Aegotheliformes", orderZh:"裸鼻鸱目", family:"Owlet-nightjars", familyLatin:"Aegothelidae", familyZh:"裸鼻鸱科", sci:"Aegotheles savesi", en:"New Caledonian Owlet-nightjar", zh:"新喀裸鼻夜鹰", pinyin:"xīn kā luǒ bí yè yīng", iucn:"CR", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Aegotheliformes/Aegothelidae/Aegotheles_savesi.webp" },
  { id:"Calypte_anna", order:"Apodiformes", orderZh:"雨燕目", family:"Hummingbirds", familyLatin:"Trochilidae", familyZh:"蜂鸟科", sci:"Calypte anna", en:"Anna's Hummingbird", zh:"安氏蜂鸟", pinyin:"ān shì fēng niǎo", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Apodiformes/Trochilidae/Calypte_anna.webp", default:true },
  { id:"Tauraco_livingstonii", order:"Musophagiformes", orderZh:"蕉鹃目", family:"Turacos", familyLatin:"Musophagidae", familyZh:"蕉鹃科", sci:"Tauraco livingstonii", en:"Livingstone's Turaco", zh:"利氏蕉鹃", pinyin:"lì shì jiāo juān", iucn:"LC", meetsQualityBar:false, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Musophagiformes/Musophagidae/Tauraco_livingstonii.webp" },
  { id:"Otis_tarda", order:"Otidiformes", orderZh:"鸨形目", family:"Bustards", familyLatin:"Otididae", familyZh:"鸨科", sci:"Otis tarda", en:"Great Bustard", zh:"大鸨", pinyin:"dà bǎo", iucn:"EN", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Otidiformes/Otididae/Otis_tarda.webp" },
  { id:"Geococcyx_californianus", order:"Cuculiformes", orderZh:"鹃形目", family:"Cuckoos", familyLatin:"Cuculidae", familyZh:"杜鹃科", sci:"Geococcyx californianus", en:"Greater Roadrunner", zh:"走鹃", pinyin:"zǒu juān", iucn:"LC", meetsQualityBar:false, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Cuculiformes/Cuculidae/Geococcyx_californianus.webp" },
  { id:"Monias_benschi", order:"Mesitornithiformes", orderZh:"拟鹑目", family:"Mesites", familyLatin:"Mesitornithidae", familyZh:"拟鹑科", sci:"Monias benschi", en:"Subdesert Mesite", zh:"本氏拟鹑", pinyin:"běn shì nǐ chún", iucn:"VU", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Mesitornithiformes/Mesitornithidae/Monias_benschi.webp" },
  { id:"Pterocles_bicinctus", order:"Pterocliformes", orderZh:"沙鸡目", family:"Sandgrouse", familyLatin:"Pteroclidae", familyZh:"沙鸡科", sci:"Pterocles bicinctus", en:"Double-banded Sandgrouse", zh:"二斑沙鸡", pinyin:"èr bān shā jī", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Pterocliformes/Pteroclidae/Pterocles_bicinctus.webp" },
  { id:"Goura_victoria", order:"Columbiformes", orderZh:"鸽形目", family:"Pigeons, Doves", familyLatin:"Columbidae", familyZh:"鸠鸽科", sci:"Goura victoria", en:"Victoria Crowned Pigeon", zh:"维多凤冠鸠", pinyin:"wéi duō fèng guān jiū", iucn:"NT", meetsQualityBar:false, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Columbiformes/Columbidae/Goura_victoria.webp" },
  { id:"Grus_japonensis", order:"Gruiformes", orderZh:"鹤形目", family:"Cranes", familyLatin:"Gruidae", familyZh:"鹤科", sci:"Grus japonensis", en:"Red-crowned Crane", zh:"丹顶鹤", pinyin:"dān dǐng hè", iucn:"VU", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Gruiformes/Gruidae/Grus_japonensis.webp" },
  { id:"Podiceps_cristatus", order:"Podicipediformes", orderZh:"䴙䴘目", family:"Grebes", familyLatin:"Podicipedidae", familyZh:"䴙䴘科", sci:"Podiceps cristatus", en:"Great Crested Grebe", zh:"凤头䴙䴘", pinyin:"fèng tóu pì tī", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Podicipediformes/Podicipedidae/Podiceps_cristatus.webp" },
  { id:"Phoeniconaias_minor", order:"Phoenicopteriformes", orderZh:"红鹳目", family:"Flamingos", familyLatin:"Phoenicopteridae", familyZh:"红鹳科", sci:"Phoeniconaias minor", en:"Lesser Flamingo", zh:"小红鹳", pinyin:"xiǎo hóng guàn", iucn:"NT", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Phoenicopteriformes/Phoenicopteridae/Phoeniconaias_minor.webp" },
  { id:"Fratercula_arctica", order:"Charadriiformes", orderZh:"鸻形目", family:"Auks", familyLatin:"Alcidae", familyZh:"海雀科", sci:"Fratercula arctica", en:"Atlantic Puffin", zh:"北极海鹦", pinyin:"běi jí hǎi yīng", iucn:"VU", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Charadriiformes/Alcidae/Fratercula_arctica.webp" },
  { id:"Eurypyga_helias", order:"Eurypygiformes", orderZh:"日鳽目", family:"Sunbittern", familyLatin:"Eurypygidae", familyZh:"日鳽科", sci:"Eurypyga helias", en:"Sunbittern", zh:"日鳽", pinyin:"rì jiān", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Eurypygiformes/Eurypygidae/Eurypyga_helias.webp" },
  { id:"Phaethon_rubricauda", order:"Phaethontiformes", orderZh:"鹲形目", family:"Tropicbirds", familyLatin:"Phaethontidae", familyZh:"鹲科", sci:"Phaethon rubricauda", en:"Red-tailed Tropicbird", zh:"红尾鹲", pinyin:"hóng wěi méi", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Phaethontiformes/Phaethontidae/Phaethon_rubricauda.webp" },
  { id:"Gavia_stellata", order:"Gaviiformes", orderZh:"潜鸟目", family:"Loons", familyLatin:"Gaviidae", familyZh:"潜鸟科", sci:"Gavia stellata", en:"Red-throated Loon", zh:"红喉潜鸟", pinyin:"hóng hóu qián niǎo", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Gaviiformes/Gaviidae/Gavia_stellata.webp" },
  { id:"Aptenodytes_forsteri", order:"Sphenisciformes", orderZh:"企鹅目", family:"Penguins", familyLatin:"Spheniscidae", familyZh:"企鹅科", sci:"Aptenodytes forsteri", en:"Emperor Penguin", zh:"帝企鹅", pinyin:"dì qǐ é", iucn:"NT", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Sphenisciformes/Spheniscidae/Aptenodytes_forsteri.webp", default:true },
  { id:"Diomedea_amsterdamensis", order:"Procellariiformes", orderZh:"鹱形目", family:"Albatrosses", familyLatin:"Diomedeidae", familyZh:"信天翁科", sci:"Diomedea amsterdamensis", en:"Amsterdam Albatross", zh:"阿岛信天翁", pinyin:"ā dǎo xìn tiān wēng", iucn:"EN", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Procellariiformes/Diomedeidae/Diomedea_amsterdamensis.webp" },
  { id:"Ciconia_ciconia", order:"Ciconiiformes", orderZh:"鹳形目", family:"Storks", familyLatin:"Ciconiidae", familyZh:"鹳科", sci:"Ciconia ciconia", en:"White Stork", zh:"白鹳", pinyin:"bái guàn", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Ciconiiformes/Ciconiidae/Ciconia_ciconia.webp" },
  { id:"Sula_nebouxii", order:"Suliformes", orderZh:"鲣鸟目", family:"Gannets, Boobies", familyLatin:"Sulidae", familyZh:"鲣鸟科", sci:"Sula nebouxii", en:"Blue-footed Booby", zh:"蓝脚鲣鸟", pinyin:"lán jiǎo jiān niǎo", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Suliformes/Sulidae/Sula_nebouxii.webp" },
  { id:"Balaeniceps_rex", order:"Pelecaniformes", orderZh:"鹈形目", family:"Shoebill", familyLatin:"Balaenicipitidae", familyZh:"鲸头鹳科", sci:"Balaeniceps rex", en:"Shoebill", zh:"鲸头鹳", pinyin:"jīng tóu guàn", iucn:"VU", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Pelecaniformes/Balaenicipitidae/Balaeniceps_rex.webp" },
  { id:"Opisthocomus_hoazin", order:"Opisthocomiformes", orderZh:"麝雉目", family:"Hoatzin", familyLatin:"Opisthocomidae", familyZh:"麝雉科", sci:"Opisthocomus hoazin", en:"Hoatzin", zh:"麝雉", pinyin:"shè zhì", iucn:"LC", meetsQualityBar:false, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Opisthocomiformes/Opisthocomidae/Opisthocomus_hoazin.webp" },
  { id:"Haliaeetus_leucocephalus", order:"Accipitriformes", orderZh:"鹰形目", family:"Kites, Hawks, Eagles", familyLatin:"Accipitridae", familyZh:"鹰科", sci:"Haliaeetus leucocephalus", en:"Bald Eagle", zh:"白头海雕", pinyin:"bái tóu hǎi diāo", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Accipitriformes/Accipitridae/Haliaeetus_leucocephalus.webp" },
  { id:"Bubo_scandiacus", order:"Strigiformes", orderZh:"鸮形目", family:"Owls", familyLatin:"Strigidae", familyZh:"鸱鸮科", sci:"Bubo scandiacus", en:"Snowy Owl", zh:"雪鸮", pinyin:"xuě xiāo", iucn:"VU", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Strigiformes/Strigidae/Bubo_scandiacus.webp" },
  { id:"Urocolius_indicus", order:"Coliiformes", orderZh:"鼠鸟目", family:"Mousebirds", familyLatin:"Coliidae", familyZh:"鼠鸟科", sci:"Urocolius indicus", en:"Red-faced Mousebird", zh:"红脸鼠鸟", pinyin:"hóng liǎn shǔ niǎo", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Coliiformes/Coliidae/Urocolius_indicus.webp" },
  { id:"Leptosomus_discolor", order:"Leptosomiformes", orderZh:"鹃鴗目", family:"Cuckoo-roller", familyLatin:"Leptosomidae", familyZh:"鹃鴗科", sci:"Leptosomus discolor", en:"Cuckoo-roller", zh:"鹃三宝鸟", pinyin:"juān sān bǎo niǎo", iucn:"LC", meetsQualityBar:false, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Leptosomiformes/Leptosomidae/Leptosomus_discolor.webp" },
  { id:"Pharomachrus_fulgidus", order:"Trogoniformes", orderZh:"咬鹃目", family:"Trogons", familyLatin:"Trogonidae", familyZh:"咬鹃科", sci:"Pharomachrus fulgidus", en:"White-tipped Quetzal", zh:"白尾梢绿咬鹃", pinyin:"bái wěi shāo lǜ yǎo juān", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Trogoniformes/Trogonidae/Pharomachrus_fulgidus.webp" },
  { id:"Buceros_rhinoceros", order:"Bucerotiformes", orderZh:"犀鸟目", family:"Hornbills", familyLatin:"Bucerotidae", familyZh:"犀鸟科", sci:"Buceros rhinoceros", en:"Rhinoceros Hornbill", zh:"马来犀鸟", pinyin:"mǎ lái xī niǎo", iucn:"VU", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Bucerotiformes/Bucerotidae/Buceros_rhinoceros.webp" },
  { id:"Alcedo_atthis", order:"Coraciiformes", orderZh:"佛法僧目", family:"Kingfishers", familyLatin:"Alcedinidae", familyZh:"翠鸟科", sci:"Alcedo atthis", en:"Common Kingfisher", zh:"普通翠鸟", pinyin:"pǔ tōng cuì niǎo", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Coraciiformes/Alcedinidae/Alcedo_atthis.webp", default:true },
  { id:"Ramphastos_toco", order:"Piciformes", orderZh:"䴕形目", family:"Toucans", familyLatin:"Ramphastidae", familyZh:"鵎鵼科", sci:"Ramphastos toco", en:"Toco Toucan", zh:"巨嘴鸟", pinyin:"jù zuǐ niǎo", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Piciformes/Ramphastidae/Ramphastos_toco.webp" },
  { id:"Cariama_cristata", order:"Cariamiformes", orderZh:"叫鹤目", family:"Seriemas", familyLatin:"Cariamidae", familyZh:"叫鹤科", sci:"Cariama cristata", en:"Red-legged Seriema", zh:"红腿叫鹤", pinyin:"hóng tuǐ jiào hè", iucn:"LC", meetsQualityBar:false, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Cariamiformes/Cariamidae/Cariama_cristata.webp" },
  { id:"Falco_peregrinus", order:"Falconiformes", orderZh:"隼形目", family:"Caracaras, Falcons", familyLatin:"Falconidae", familyZh:"隼科", sci:"Falco peregrinus", en:"Peregrine Falcon", zh:"游隼", pinyin:"yóu sǔn", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Falconiformes/Falconidae/Falco_peregrinus.webp" },
  { id:"Ara_macao", order:"Psittaciformes", orderZh:"鹦形目", family:"African & New World Parrots", familyLatin:"Psittacidae", familyZh:"金刚鹦鹉科", sci:"Ara macao", en:"Scarlet Macaw", zh:"绯红金刚鹦鹉", pinyin:"fēi hóng jīn gāng yīng wǔ", iucn:"LC", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Psittaciformes/Psittacidae/Ara_macao.webp", default:true },
  { id:"Paradisornis_rudolphi", order:"Passeriformes", orderZh:"雀形目", family:"Birds-of-paradise", familyLatin:"Paradisaeidae", familyZh:"极乐鸟科", sci:"Paradisornis rudolphi", en:"Blue Bird-of-paradise", zh:"蓝极乐鸟", pinyin:"lán jí lè niǎo", iucn:"NT", meetsQualityBar:true, url:"https://raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/stickers/Passeriformes/Paradisaeidae/Paradisornis_rudolphi.webp" },
]
```

**质量线备注**：11 只 `meetsQualityBar:false`（鸵鸟、大美洲鸵、旗翅夜鹰、油夜鹰、大钩嘴夜鹰、
利氏蕉鹃、走鹃、维多凤冠鸠、麝雉、鹃三宝鸟、红腿叫鹤）——绝大多数是「整个目仅 1–2 种」的活化石类群，
无替补；`false` 只表示花叔审校打分 <80，仍是完好插画，装饰板足够。
