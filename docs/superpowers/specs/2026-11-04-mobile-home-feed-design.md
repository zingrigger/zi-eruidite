# 手机首页：文章优先（紧凑 masthead + 缩略图列表）

日期：2026-11-04
状态：已批准（2026-11-04）
范围：`<64rem` 首页 hero（zh/en）；`<40rem` BlogCard；桌面与 ≥40rem 列表保持现状

## 1. 为什么

390px 下顶栏 96、hero 卡片 385，最新文章要到 545 才开始；320px 下 hero 484，最新文章到 643。hero 的两段仍是模板占位文案，第二段讲模板仓库和 v2 文章，不是“你”；320px 卡片 32px 内边距把文字列压到约 209px，标题在“你好，我”处断行。topbar 布局在手机上更紧凑（284），但手机端的布局切换已收掉，默认 sidebar 用户看不到。

用户已明确选择“先看到文章”；列表选择 B（左侧缩略图行），并接受 BlogCard 是共享组件——`/blog`、标签页、作者页的手机列表会一起变。

## 2. 方案取舍

**Hero**

- 保留卡片但压缩：仍有卡片边界，帖子最多提前约 100px；被放弃。
- 沿用 topbar 当前开放 hero（两段）：284px，仍不够“文章优先”。
- **开放 masthead（选定）**：去掉卡片，标题 step-2、斜体 accent、居中；只保留第一段，第二段手机隐藏；帖子从约 230px 开始。手机不再区分 sidebar/topbar 的 hero 样式；桌面两套布局完全不变。

**列表**

- A 整宽 16:9 封面：第一屏约 2 条，图仍是主角；被放弃。
- **B 左侧 88px 缩略图行（选定）**：标题/日期/摘要右置，摘要两行截断；单条约 120–150px，第一屏 3 条；适用于首页、`/blog`、标签页、作者页。

## 3. 设计

### 3.1 Hero（`<64rem`，两种布局共用）

在 `home.css` 的 `hero-card` 基础规则之后新增：

- 去卡片：`background: none; border: 0; border-radius: 0; padding: 0;`
- 排版：`text-align: center; margin-block-end: var(--space-m);`
- 标题：`font-size: var(--step-2); font-style: italic; color: var(--accent); letter-spacing: -0.02em; line-height: 1.25;`（沿用 topbar 的斜体 accent 语言）
- 段落：`font-size: var(--step--1); line-height: 1.6; color: var(--muted-foreground); max-width: var(--measure); margin-inline: auto;`
- 隐藏第二段起的段落：`hero-text p:nth-of-type(n+2) { display: none; }`
- `hero-avatar` 若配置：`margin-inline: auto;`
- `hero-figure` 继续隐藏（现有 `<64rem` 规则）
- `≥64rem` 的 sidebar 卡片 hero 与 topbar 左文右图 hero 原样保留。

顶部间距仍由布局决定（sidebar page-nav 下方 16px / topbar main 的 space-xl）；本次不统一其他页面的顶部间距。

### 3.2 列表（`<40rem`）

`BlogCard.astro` 现有的 `<40rem` 堆叠规则改为行：

- `li { flex-direction: row; gap: var(--space-xs); }`（保持 `align-items: flex-start`）
- 缩略图链接：`inline-size: 5.5rem; max-inline-size: none;`（16:9 源图约 88×46）
- 标题：沿用 `--step-1`；不缩小字号，靠缩略图与两行摘要控制密度。
- 摘要：`font-size: var(--step--1); line-height: 1.5;`，`-webkit-line-clamp: 2`。
- 无图条目（当前最新一条）保持整行文字，标题从左边开始；有图条目文字从缩略图右侧开始。列表自身仍是纵向 `gap: var(--space-m)`。

`≥40rem` 的 14rem 左图行、桌面卡片完全不动。

### 3.3 可访问性与内容

- 缩略图链接继续 `tabindex="-1" aria-hidden="true"`，标题链接是唯一可聚焦入口；图片 `alt=""` 不变。
- 手机隐藏第二段使用 `display:none`，因此它同时从内容流、页内查找与无障碍树移除；桌面仍可读到完整 hero。没有其他内容删除。
- 摘要两行截断只影响视觉，完整描述仍在 DOM 与桌面/详情页中。
- hero 第一段仍是模板占位；按“短介绍”设计，作者换成自己的话时不会撑高。桌面文案不变。

## 4. 非目标

- 不改 `≥64rem` 的 sidebar 卡片 hero、topbar 首屏、BlogCard 桌面行。
- 不改博客详情页、博客列表页头、moments、发布器。
- 不改图片资源、文章内容或新增 `tagline` 字段。
- 不统一 sidebar/topbar 在手机端的顶部间距差异。
- 不处理 200% 文字缩放下的换行。

## 5. 验收

- 320 / 390 / 430，zh/en，sidebar/topbar：hero 无卡片、标题 step-2 斜体 accent、只显示第一段；首屏能看到 3 条（390 全部；320 第三条可能贴底）；有图条目缩略图约 88px、摘要两行；无图首条为整行文字。
- `≥40rem`：BlogCard 恢复 14rem 左图行；640 下 hero 仍是紧凑 masthead、列表是桌面行。
- 1024 / 1440，两种布局：sidebar 卡片 hero、topbar 左文右图、列表桌面行与改动前一致。
- `/blog`、`/tags/<tag>`、`/authors/<id>` 的 `<40rem` 列表同步为缩略图行；页头与详情页不变。
- `npm run build`、`bash scripts/tests/i18n-check.sh` 通过；改动文件 format 检查通过。`home-guide-topbar-check.sh` 的 hero 陈旧断言仍是既有失败，与本改动无关。
- 不自动提交 Git。
