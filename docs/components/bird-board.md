# BirdBoard 鸟类收藏板组件

## 1. 一句话说明

`<bird-board>` 是一面可拖拽的鸟类贴纸拼贴板：把花叔《全球鸟类贴纸库》里「IOC 44
目各一只」共 44 张贴纸做成 SSR 默认摆 5 只、其余 39 只驻留托盘的收集玩具——访客
点托盘按钮一只鸟就飞上板（随机落位 + `bird-toss` 入场），拖拽摆放，右键 / 长按 /
Tab+Enter 拿起一只弹出径向浮层（缩放、旋转、镜像、置顶、置底、信息），信息卡从
鸟自带的 `data-*` 建档（双语名 + 目·科（拉丁）+ IUCN + 学名·拼音 + 源链），双击
任一鸟弹出 [GlassBubble](./glass-bubble.md) 玻璃泡原图预览，「重置」精确回到默认
5 只 + 满 39 托盘。纯前端、不持久化。作为「鸟类收藏板」子页呈现：
`/board/birds` 与 `/en/board/birds`（曾是独立 `/birds` 路由，先迁入 `/board` 单页的
分区，再拆成子页；入口只有列表页 `/board` 上的一条，手机导航无入口）。

## 2. 文件位置

- 组件：`src/components/BirdBoard.astro`（SSR 骨架 + scoped 样式 + 客户端激活脚本）。
- 取数：`src/lib/content.ts` 的 `getBirdViews(locale)` 与 `BirdView` 类型。
- 数据：`src/data/birds.ts` 的 `BIRD_ITEMS: BirdItem[]`（44 条静态数组，逐字拷自
  `docs/superpowers/specs/2026-10-31-birds-board-design.md` 附录 A；名字自带
  zh/en，无需 `L10n` / `.en.md` 孪生）。
- 样式：主体内联在 `BirdBoard.astro` 的 `<style>`；预览 dialog
  （`<dialog class="bird-preview">`）的呈现住在 `src/styles/glass-bubble.css`
  （全局，与 `dialog.board-preview` 同族并列规则）。
- 宿主：`src/components/exhibits/BirdsExhibit.astro`（`ListingHead` + `<BirdBoard>` +
  授权署名段，文案取 `t(locale, "birdsCredit")`），经 `src/components/BoardExhibit.astro`
  套上页面外壳。
- 路由：`src/pages/board/[slug].astro`、`src/pages/en/board/[slug].astro`（slug=`birds`），
  由 `src/data/board-sections.ts` 的登记派生；不再有独立的 `/birds` 页面文件。
- 回归：`scripts/tests/birds-check.sh`。

## 3. 快速上手

```astro
---
import BirdBoard from "@/components/BirdBoard.astro"
---

<BirdBoard locale="zh" />
```

`BirdBoard` 自行 `getBirdViews(locale)` 取全部 44 条并按 `isDefault` 分成板面
（5 只 `bird-piece`）与托盘（39 枚 `.tray-item` 按钮），无需外部传数据。下架/上架
一只鸟 = 改 `src/data/birds.ts` 对应条目的 `default` 与 `x/y/rotate/z` 几何字段。

## 4. Props

| 名称     | 类型           | 默认 | 含义                             |
| -------- | -------------- | ---- | -------------------------------- |
| `locale` | `"zh" \| "en"` | 必填 | 取哪一语言的名字与目/科标签      |

其余 HTML 属性透传给 `<bird-board>` 根元素。

## 5. 数据字段（`BirdItem`，`src/data/birds.ts`）

| 字段              | 类型    | 必填 | 说明                                             |
| ----------------- | ------- | ---- | ------------------------------------------------ |
| `id`              | string  | 是   | 稳定键 = 学名下划线形式，与 hotlink 文件同名      |
| `order`/`orderZh` | string  | 是   | 目·英 / 目·中                                    |
| `family`/`familyZh` | string | 是   | 科·英 / 科·中                                    |
| `familyLatin`     | string  | 是   | 科·拉丁（信息卡始终附带）                        |
| `sci`             | string  | 是   | 学名                                             |
| `en` / `zh`       | string  | 是   | 英文名 / 中文名（另一语言作 `nameAlt` 并列展示）  |
| `pinyin`          | string  | 否   | 拼音（信息卡与学名同排；缺省只显学名）           |
| `iucn`            | string  | 否   | 保护等级 LC/NT/VU/EN/CR；**空串 = 未评估**，信息卡隐藏该行 |
| `url`             | string  | 是   | hotlink webp 绝对 URL（`raw.githubusercontent.com/alchaincyf/huashu-bird-sticker/main/` + `sticker.file`） |
| `meetsQualityBar` | boolean | 是   | 花叔审校打分是否 ≥80（false 仍是完好插画，仅备查） |
| `default`         | boolean | 否   | 是否默认上板（共 5 只，其余进托盘）              |
| `x`/`y`/`rotate`/`z` | number | 否 | 仅默认 5 只的初始几何（板占比 0–1、deg、叠放序 1..5） |

## 6. 无障碍与降级

- **无 JS**：SSR 即成图——默认 5 只散在板上、托盘 39 只是静态一览；提示行
  （含重置与计数）只在 `bird-board[data-interactive]` 后出现，不承诺不存在的交互。
- **窄屏 `<64rem`**：板与托盘都回退为只读网格，铺全部 44 只、名字常显；
  拖拽 / 飞入 / 径向菜单 / 信息卡 / 提示行全部关闭（CSS `display:none` +
  `matchMedia("(width >= 64rem)")` 不绑事件）。
- **键盘（宽屏）**：Tab 到鸟 → Enter / 空格 / 菜单键 / Shift+F10 唤起径向菜单；
  菜单是 `role="toolbar"` + roving tabindex，方向键走位、Enter 执行、Esc 先关
  信息卡再放下鸟；托盘按钮是真 `<button>`（`aria-label` =「加入 {name}」），
  Enter 即可加鸟；关闭预览后焦点回唤起的那只鸟。
- **触屏**：右键等价操作 = 长按 500ms；Pointer Events 统一鼠标/触屏/笔。
- **`prefers-reduced-motion: reduce`**：无飞入 / 菜单弹出 / hover 动画，但拖拽、
  加鸟、重置均照常可用（脚本直接落位，不加 `bird-enter` 类）。
- **外链图失效**：`onerror` 隐藏 `<img>` 并让名字常显（`.bird-img[hidden] +
  .bird-name`），不留破图空白，板照常可用。
- **字段缺失**：信息卡逐行优雅降级——`iucn` 空隐藏该行、`pinyin` 缺只显学名，
  空 `<p>` 由 `:empty { display: none }` 收起，绝不渲染 `undefined`。

## 7. 注意事项

- **不持久化**：无 localStorage、无后端；一切几何只写内存 CSS 变量，刷新回默认
  5 只（与邮票板 `/board/stamps` 同哲学）。
- **hotlink 与授权**：贴纸不 vendor、不进构建产物；页脚署名为合规硬要求（花叔 /
  鸣迹 + PolyForm Shield 1.0.0 + IOC v15.2 CC BY 3.0 + AVONET CC BY 4.0 +
  仓库/许可链接），住在 `src/components/exhibits/BirdsExhibit.astro` 尾部（即
  `/board/birds` 页板下方），改动鸟板展品时不得移除；两种语言都渲染。
- **数据住 DOM**：每只鸟的完整信息以 `data-id data-name data-name-alt data-order
  data-family data-family-latin data-sci data-pinyin data-iucn data-url` 挂在
  `bird-piece` 与托盘按钮上；信息卡与飞入新建的 piece 全部从这些 `data-*` 取，
  脚本里不另养一份数据。
- **动态建元素必须克隆 scoped 属性**：Astro scoped 样式带 `[data-astro-cid-*]`
  属性选择器，`addBird()` 用 `createElement` 建的 piece 及其 `<img>`/`<span>`
  子元素须复制默认件的同名 cid 属性（见脚本 `applyScope`），否则 `.bird-img`
  尺寸与 `bird-toss` 关键帧全部选不中。这是与邮票板（无 JS 建件）最大的实现差异。
- **预览取图须 CORS**：玻璃泡把原图上传 WebGL 纹理，hotlink 跨域位图必须以
  `crossOrigin="anonymous"` 获取（raw 域发 `Access-Control-Allow-Origin: *`），
  否则 canvas 被污染、`texImage2D` 抛 SecurityError；共享模块
  `src/lib/glass-bubble.ts` 已统一补上，同板的邮票板忽略该属性不受影响。
- **径向菜单文案**：op 按钮（放大/缩小/旋转/镜像/置顶/置底）复用 `board*` i18n
  键（同一套图标语义），仅 `birdsInfo` / `birdsMenuLabel` 等为鸟类板独有。
- **与邮票板的关系**：本组件是 `Board.astro` 的 fork（拖拽 / 径向菜单 / 信息卡 /
  `bird-toss` 入场 / 双击预览机制照其裁剪），**不共享引擎**——按 spec 决议，等出现
  第三个 board 类页面再按 rule of three 抽 `board-engine`。邮票板（`/board/stamps`）
  与鸟板（`/board/birds`）是两条独立路由，互不影响。
- **托盘缩略图 = 全尺寸 webp**：CDN 无缩略图变体，靠 `loading="lazy"` + CSS 缩小
  显示；这是 hotlink 方案的既定取舍。

## 8. 完整示例

```astro
---
import ListingHead from "@/components/ListingHead.astro"
import BirdBoard from "@/components/BirdBoard.astro"
import { getBirdViews } from "@/lib/content"
import { t } from "@/lib/i18n"

const birds = await getBirdViews("zh")
---

<!-- /board/birds 子页（BirdsExhibit.astro 内，Layout 由 BoardExhibit 套） -->
<ListingHead
  kicker="~/board/birds"
  title={t(locale, "birdsTitle")}
  desc={t(locale, "birdsDesc")}
/>
<BirdBoard locale="zh" />
<p class="birds-credit">{t("zh", "birdsCredit")} …（仓库 / 许可链接）</p>
```
