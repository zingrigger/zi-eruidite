# TicketCard 票券组件

一组「被收藏的票券」：礼品券、折扣券、电子门票三种版式，横竖两向、蓝白两色对调，
拼贴成板下的展示区。票券本身是**纯 SSR 表现层**（不是可拖拽的 `board-piece`），造型
（齿孔 / 撕口 / 条形码 / 点阵码）全部构建期生成。`TicketSection` 额外提供一个「默认 /
图片」主题切换（渐进增强，无 JS 时默认纯蓝白照常呈现）：图片主题把每张票券的实心蓝侧
换成插画。倾斜**默认就在、没有开关**：鼠标移到票券上即像光栅卡那样朝指针 3D 倾斜、
移开靠弹簧回正（复用 `lenticular-spring` 物理）。它是纯装饰，故
`prefers-reduced-motion: reduce` 下由 `mountTicketTilt` 直接夺走。

## 文件位置

- 组件：`src/components/TicketCard.astro`（单枚票券，自主定制元素 `<ticket-card>`；含图片填充层与主题显隐 CSS）
- 拼贴容器：`src/components/TicketSection.astro`（内联 `TICKETS` 数组 + `<ticket-showcase>`/`<ticket-collage>` 布局 + 「默认/图片」主题切换 + 一个注册 `<ticket-showcase>` 的 `<script>`：先查 `customElements.get`、`connectedCallback` 里挂主题监听与 `mountTicketTilt`、`disconnectedCallback` 里逐个 destroy）
- 倾斜接线：`src/lib/ticket-tilt.ts`（`mountTicketTilt()`：给每个 `<ticket-slot>` 挂悬停倾斜，物理复用 `src/lib/lenticular-spring.ts` 的纯函数；只往 slot 写 `--tk-rx`/`--tk-ry`，带 `deg`）
- 样式：各组件内的 scoped `<style>`；票券的图片显隐用 `:global([data-theme="image"]) .tk-fill` 跨到祖先 showcase（祖先在别的组件，故 `:global`）
- 在用它的地方：`/board/tickets` 与 `/en/board/tickets`「票券 / Tickets」子页
  （`src/components/exhibits/TicketsExhibit.astro` 包住 `TicketSection`）
- 回归：`scripts/tests/board-check.sh`（对 `dist/board/tickets/index.html` 断言票券容器、
  三版式、条形码/点阵码、mask、双语标题）

## 快速上手

```astro
---
import TicketCard from "@/components/TicketCard.astro"
---

<TicketCard
  variant="voucher"
  orient="h"
  label="Gift Voucher"
  amount="75%"
  sub="Valid until 12 Dec 2024"
  code="GV-2024-8842"
  seed={11}
  width="16rem"
  rot={-3}
/>
```

实际页面用封装 `TicketSection`（只吃一个 `locale`；票面文案恒为英文设计图案），一次铺一组：

```astro
<ListingHead kicker="~/board/tickets" title={t(locale, "ticketsTitle")} desc={t(locale, "ticketsDesc")} />
<TicketSection locale={locale} />
```

## Props

| 名称 | 类型 / 取值 | 默认 | 含义与范围 |
| --- | --- | --- | --- |
| `variant` | `"voucher" \| "coupon" \| "eticket"` | `"voucher"` | 版式：礼品券（齿孔边）/ 折扣券 / 电子门票（QR + 信息行，副券在左） |
| `orient` | `"h" \| "v"` | `"h"` | 横版副券在侧、竖版副券在底 |
| `invert` | boolean | `false` | 蓝白对调：`false` 白主蓝副，`true` 蓝主白副 |
| `label` | string | `"GIFT VOUCHER"` | 顶部小标签（大写） |
| `amount` | string | `"75%"` | 主数字 / 票种（如 `"$100"`、`"Day Pass"`） |
| `title` | string | — | 名称行（活动名 / 商品名；缺省时副券标签回落 `label`） |
| `sub` | string | `"VALID UNTIL 12 DEC 2024"` | 副说明（有效期 / 日期） |
| `code` | string | `"GIFT-2024-8842"` | 券码 / 序列号（副券下方小字，等宽） |
| `meta` | `{ k, v }[]` | — | 电子门票信息行（Name / Date / Seat …） |
| `seed` | number | `7` | 条形码 / 点阵码的确定性种子（同种子 → 同图案） |
| `w` / `h` | number | 按 orient/variant | viewBox 名义宽高，决定缺口/齿孔几何与宽高比 |
| `rot` | number（度） | `0` | 拼贴里的旋转 |
| `width` | CSS 长度 | `"16rem"` | 卡面宽度；内部文字以 `font-size = width × 0.05` 等比缩放 |
| `image` | `ImageMetadata` | — | 图片主题下填「实心蓝那一侧」的插画（非反转=副券、反转=主区）；缺省则该卡在图片主题下仍为纯蓝。走 Astro `<Image>`，固定请求 400px webp |

## 模式 / 取值详解

- **三版式的差异**：`voucher` 打开 `perforate` → 四边排布齿孔圆（沿用收藏板邮票的
  构建期 SVG mask 手法）；`coupon` 只留撕口半圆缺口；`eticket` 副券固定在**左**
  （`flex-direction: row-reverse`），主区容纳 `title + amount + sub + meta` 信息行。
- **副券位置与撕裂线**：`--tk-stub` 管副券占比（横版右副 32%、左副/竖版底副 30%），
  `--tk-seam` 管虚线定位；两者由 `stubFrac` 一处派生，mask 缺口圆心与 CSS 虚线严格对齐。
- **条形码 / 点阵码**：构建期用固定种子的 xorshift32 生成——条形码是变宽竖条
  （`preserveAspectRatio="none"` 随容器拉伸），点阵码是 21×21 带三角定位图案的模块。
  都内联成 `currentColor` 的 SVG，**纯装饰、不可扫**、零依赖、零二进制资产。
- **图片主题**：`<ticket-showcase data-theme="image">` 时，每张票券的实心蓝侧
  （`accentIsMain = invert`）显出一个绝对定位、`object-fit:cover` 的 `<Image>` 填充层，
  上覆一层中性深蓝蒙版（`rgba(15,28,68,.34→.5)`）并给落在图上的白字加 `text-shadow`，
  兼顾「看得见画」与「读得清字」。撕口/齿孔 mask 照常裁切，图被切成票券外形。
  默认 `data-theme="solid"` 即纯蓝白。
- **倾斜交互（默认挂，无开关）**：脚本 `connectedCallback` 里直接 `mountTicketTilt(this)` 挂监听；鼠标在某枚
  票券上移动 → `targetFromPointer` 把指针位置映射成目标角，`advanceAxes` 弹簧推进，往 `<ticket-slot>`
  写 `--tk-rx`/`--tk-ry`；离开归零、静止即停 rAF（无常驻循环）。3D 变换落在 slot（`transform: ... perspective(800px)
  rotateX(var(--tk-rx)) rotateY(var(--tk-ry))`），而票券的 `filter:drop-shadow` 留在子 `<ticket-card>` 上。

## 无障碍与降级

- 无 JS：票券是 SSR 出的静态 HTML + CSS，禁用 JS 也完整呈现，无降级问题。
- 倾斜：无开关、无按钮，也就没有需要键盘可达的控件；鼠标不移上去就不动，触屏上没有悬停
  语义。倾斜是纯装饰（不携带任何信息），所以 `prefers-reduced-motion: reduce` 下**直接夺走**：
  `onEnter`/`onMove`/`onLeave` 三个入口都不进（不读矩形、不起循环），循环跑着时被改成 reduce 则由
  `tick()` 走 `settle()` 当场抹平，不会卡在倾斜态。
- 主题切换：`<ticket-theme>` 是 `role=group` + 两个 `aria-pressed` 按钮，键盘可达；切换只改
  showcase 的 `data-theme`。**无 JS 时**按钮不响应，但默认 `data-theme="solid"` 已在 SSR 里，
  票券照常以纯蓝白完整呈现（图片层 `display:none`），无降级问题。
- 条形码 / 点阵码 SVG 均 `aria-hidden="true"`（装饰），票面文字（`label/amount/title/
  sub/code`）是真实文本，读屏可读。
- `prefers-reduced-motion: reduce` 时撤掉 `:hover` 的轻微上浮（该动效只在
  `@media (prefers-reduced-motion: no-preference)` 内声明）。

## 注意事项

- **配色固定蓝白、不随明暗主题反转**：票券是「被收藏的实物」（同邮票图不反色），
  暗色下靠宿主 `filter: drop-shadow` 把白卡从板面托起。改配色只动 `ticket-card` 上那组
  `--tk-*` 令牌。
- **票面文字恒为英文、不翻译**：它是设计图案的一部分；区块标题的双语由各页面的
  `ListingHead` 承担（zh「票券」/ en「Tickets」），故本组件**不新增 i18n 键**。
- **缺口必须用真 `mask` 镂空**（`--tk-mask` 打在 `ticket-body` 上），不要用「页面色圆」
  伪造——浅色下会因对比不足消失并盖住投影（收藏板邮票踩过的坑）。投影走宿主
  `filter: drop-shadow`：body 被 mask 打了缺口，宿主 alpha 即含缺口，阴影自然跟随轮廓。
- **定高靠 `aspect-ratio`**：`--tk-ar = w / h`（viewBox 名义比），`mask-size:100%` 等比
  映射 → 圆不变椭圆。电子门票内容多，默认给了更高 viewBox（`320×182`）并收紧内部字号；
  往 `meta` 里塞更多行时注意别被定高裁掉。
- **图片请求固定宽度**：填充 `<Image>` 传 `width={400}`（而非源图自然尺寸）。传自然尺寸会让
  dev 的 `/_image` 现算大图（stargirl 2000×2829 等）易触发 500；400px 足够小票券显示且更轻。
  另注：若某个 dev 进程整体 `/_image` 返 500（连邮票图也会坏），多半是该 dev server 状态坏了，
  重启 `astro dev` 即好，与本组件无关；`astro build` 产物不受影响。
- **变量名不得用 `--rx`/`--ry`**（曾经就撞在这）：`lenticular.css` 用 `@property` 把 `--rx`/`--ry`
  注册成文档级的 `<number>`，而 **`@property` 没有作用域**——票券往同名变量写 `8.057deg` 会因
  syntax 不匹配而 *invalid at computed-value time*，落回 `initial-value: 0`，于是 `rotateX(0)` →
  倾角永远为 0；改写成裸数字又会让 `rotateX(8.057)` 不是合法 `<angle>` → **整条 `transform`
  作废成 `none`**（连奇偶错位的 `translateY(--stagger)` 一起没）。两种都坏得静悄悄：JS 在算、
  DevTools 里内联值在变，只是画面不动。所以票券用 `--tk-rx`/`--tk-ry`，`board-check.sh` 钉了这条。
- **3D 落父、filter 落子**：倾斜的 `perspective/rotateX/rotateY` 必须在 `<ticket-slot>`，不能放到
  带 `filter:drop-shadow` 的 `<ticket-card>` 上（filter 会压平 3D）。指针映射用进入时冻结的 card
  rect，避免倾斜改变 getBoundingClientRect 造成自反馈抖动。
- **脚本含 import → 提成 chunk**：`TicketSection` 的 `<script>` import 了 `ticket-tilt`，Astro 会把它
  打成 JS chunk 而非内联进 HTML；`board-check.sh` 相应按 `grep -rl ticket-showcase dist/_astro/*.js`
  定位 chunk 再断言，别在 HTML 里找脚本串。
- **独立于 `board-grid`**：不是 `board-piece`，因此不参与拖拽、右键径向菜单、双击
  GlassBubble 预览，也不被 dev「保存布局」写回。
- **测试别钉 CSS 文件名**：新增 scoped 组件会让 Astro 合并 CSS chunk、`Board.*.css`
  文件名漂移；`board-check.sh` 的 `isolation` 断言已改为「按含 `board-grid` 规则的那份
  CSS 定位」。

## 完整示例

`TicketSection.astro` 内联一组 `TICKETS`（覆盖三版式 + 横竖 + 蓝白对调），映射为多枚
`<TicketCard>`，`<ticket-collage>` 用 `flex-wrap` 铺成错落拼贴，奇偶 `translateY` 强化
「随手摊在桌上」的质感（旋转留在卡上，两者互不覆盖）：

```ts
const TICKETS: Ticket[] = [
  { variant: "voucher", orient: "h", label: "Gift Voucher", amount: "75%",
    sub: "Valid until 12 Dec 2024", code: "GV-2024-8842", seed: 11, width: "16rem", rot: -3 },
  { variant: "coupon", orient: "h", invert: true, label: "Special Discount",
    amount: "$100", title: "Coupon", sub: "Members only", code: "CP-100-2077", seed: 23,
    width: "15rem", rot: 2 },
  { variant: "eticket", orient: "h", label: "E-Ticket", amount: "Day Pass",
    title: "Investment Insight 2023", sub: "17–19 Dec 2023", code: "ETK-0234-A",
    meta: [{ k: "Name", v: "J. Smith" }, { k: "Date", v: "17 Dec" }, { k: "Seat", v: "A-12" }],
    seed: 5, width: "17.5rem", rot: 1 },
  // …竖版折扣券、反向门票等，凑成一组
]
```

要增减票券，只改 `TICKETS` 数组即可，无需动 `TicketCard`。
