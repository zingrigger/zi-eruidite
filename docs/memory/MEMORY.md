# Project Memory Index

注入层，开局读。保持 < 200 行 / 25KB。整理流程见 [DREAM.md](DREAM.md)。

## Notes
- [layout-switch](notes/2026-11-08-layout-switch.md) — `data-layout` 是布局唯一信号，两布局共用骨架，运行时切换存 localStorage。
- [i18n-twin-files](notes/2026-11-08-i18n-twin-files.md) — 英文 = 同目录 `.en.md` 孪生文件，loader 自定义 generateId 保留 `.en`。
- [deploy-force-push](notes/2026-11-08-deploy-force-push.md) — hexo 式 build + 强推 dist/；CNAME 必须放 public/ 源码。

## Wiki（结构化知识，复用 docs/）
- `docs/adr/` — 架构决策
- `docs/guides/` — how-to（i18n / deployment / content-authoring 等）
- `docs/components/` — 组件用法
- `docs/superpowers/specs/` — 设计文档

## Consolidation
整理 / 纠错 / 提升记忆见 [DREAM.md](DREAM.md)。

## Promoted key facts
- 布局由 `<html data-layout>` 单一信号驱动，切换状态在 `localStorage.layout`（[source](../superpowers/specs/2026-10-07-layout-switch-design.md)）。
- 中英配对键 = 同目录 `.en.md` 孪生文件；`src/lib/i18n.ts` 是语言工具唯一来源（[source](../guides/i18n.md)）。
- 部署全量覆盖，故 `CNAME` 必须源码化放 `public/`（[source](../guides/deployment.md)）。
- 邮票拼贴板在 `/board/stamps`（`/board` 本身是玩具柜列表页），以原生 `stamp-board` 自定义元素 + Pointer Events 实现，遵循 SSR 静态内容 + 客户端激活（无 JS 即作者预设拼贴画）；访客只能拖已有物件、不持久化，无 UI 框架（[route](../superpowers/specs/2026-11-08-board-index-split-design.md)、[component](../components/board.md)）。
- `lenticular-card` 的倾斜与画面切换由同一物理量驱动（进度由实际角度算出），零新增依赖（全手写），同样遵循 SSR 静态 + 客户端激活范式（[source](../superpowers/specs/2026-10-21-lenticular-card-design.md)）。

Last dream: 2026-11-08