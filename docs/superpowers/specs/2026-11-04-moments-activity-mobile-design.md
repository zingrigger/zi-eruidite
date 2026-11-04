# 动态活动图手机横滑年历设计

日期：2026-11-04
状态：已批准（2026-11-04）
范围：`< 40rem` 的 ActivityGraph；`≥ 40rem` 桌面保持现状

## 1. 为什么

`< 40rem` 时，53 周的热力图被 `grid-template-columns: ... minmax(0, 1fr)` 强行压进约 315px：格子只剩约 3px，而月份标签仍有 21px 宽、相邻月份列距约 22px，于是逐月文字叠在一起；图例色块是 10px，与 3px 的格子也不协调。

这不是新设计问题：`docs/superpowers/plans/2026-08-01-moment-activity-graph.md` 明确写了「窄屏（<640px）：网格横向滚动而非溢出」。后来的 `2f322f9` 自适应改动用 `overflow-x: clip` 覆盖了它。本次恢复原计划的窄屏行为，并补齐滚动后的可用性。

## 2. 方案取舍

- **A · 横向滚动年历（选定）**：`< 40rem` 固定 10px 格子 + 3px 间距，网格按 53 周自然展开（约 709px），容器横向滚动；月份按周列排开、不再重叠；默认定位到最近一次活跃日（历史年份最后一个活跃周）；周几栏在滚动时保持可见；右侧渐隐提示还有内容。代价是要横向滑一下。
- **B · 12 个月迷你日历**：不滑动、月份各自成块；代价是卡片高约 +100px、全年连续感弱，且需要新增一套 12 月日历渲染分支。对本次回归来说改动过大。

`≥ 40rem` 继续使用现有自适应网格（格子约 7.8–9.8px，月份不重叠），桌面零变化。

## 3. 设计

### 3.1 断点与网格

`@media (width < 40rem)`：

- `.activity-scroll { overflow-x: auto; overscroll-behavior-inline: contain; }`
- `.activity-grid` 改为固定列：`grid-template-columns: 20px repeat(var(--weeks), var(--cell)); grid-template-rows: auto repeat(7, var(--cell)); inline-size: max-content; position: relative;`
- 保留 `--cell: 10px`、`--gap: 3px`；图例色块本来就是 10px，与格子重新一致。
- 月份标签仍按 `monthLabels.column` 落在对应周列，`white-space: nowrap`；10px 格子下相邻月份间距约 52–65px，21px 标签不再重叠。

### 3.2 滚动可用性

- **默认定位**：初始渲染与年份切换后，优先对准最后一个 `data-level > 0` 的格子（2026 年为 7 月 30 日）；整年没有活跃日时，当前年再退到 `[data-today]`，历史年份回到最左。定位公式：`scrollLeft = clamp(target.offsetLeft - clientWidth + 64, 0, maxScroll)`，让目标格子右侧留约 5 周上下文。只在初次与切年后执行；窗口 resize 不重定位，避免打断用户滚动。
- **周几栏**：`< 40rem` 时 `.activity-weekday` 改为 `position: sticky; left: 0;`，宽 100%、右对齐、背景 `var(--background)`、`z-index: 1`；横向滚动时一/三/五仍贴在卡片左侧。
- **右侧渐隐**：滚动容器外包一层定位壳，右侧 24px 渐变覆盖；滚到末端（`scrollLeft + clientWidth >= scrollWidth - 1`）时隐藏。`≥ 40rem` 或没有溢出时不显示。
- **滑动提示**：`< 40rem` 在网格下方显示一行 mono 小字「横向滑动」，`aria-hidden`；桌面不显示。

### 3.3 可访问性

- 滚动容器加 `tabindex="0"` 与 `aria-label="动态年历，可横向滚动"`；键盘可用方向键滚动，焦点环沿用全局 `:focus-visible`。
- 网格本身继续 `aria-hidden`；活跃日仍由 `activity-sr-list` 提供给屏幕阅读器。
- `overscroll-behavior-inline: contain` 避免滑到边缘时触发页面横向滚动/返回手势。
- 年份 `<select>`、悬浮 tooltip、明暗主题逻辑不变。

## 4. 非目标

- 不改桌面 `≥ 40rem` 的网格、卡片、配色与数据模型。
- 不改 moments 时间轴、页头、发布器。
- 不新增 12 月迷你日历或新组件。
- 不处理 200% 文字缩放下的横向溢出（与站点其他固定导航一致，另议）。

## 5. 验收

- 320 / 360 / 390 / 639：格子 10×10，网格滚动宽度约 709px；任意相邻月份标签矩形不重叠；初始 `scrollLeft > 0` 且最后一个活跃格（2026-07-30）在可视区内（today 描边可以不在视口）；滚到末端渐隐消失；滚动后周几栏的 x 不变。
- 640 / 1024 / 1440：无横向滚动，月份不重叠，卡片与改动前一致；渐隐与提示不显示。
- 明/暗主题：格子、图例、渐隐、sticky 周几栏背景正确。
- 年份切换（有历史数据时）：定位到最后一个活跃周；无数据年份回到最左；caption、sr 列表同步。
- `npm run build`、`bash scripts/tests/i18n-check.sh` 通过；改动文件 format 检查通过。`home-guide-topbar-check.sh` 的 hero 断言是既有陈旧失败，与本改动无关。
- 不自动提交 Git。
