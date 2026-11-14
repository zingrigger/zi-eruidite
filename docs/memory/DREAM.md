# Dreaming Runbook

离线整理记忆的流程（文章里的 "dreaming"）。任何 harness 的 agent 按需读取本文件并
执行 Part 1；Part 2 说明如何把它注册成各 harness 的定时任务。逻辑始终在本 repo 文件里，
随版本控制走。

## Part 1 — dreaming 过程

每次 run 按顺序执行（步骤 2 与 5 不可省）：

1. **定位增量**：读 `docs/memory/MEMORY.md` 底部的 `Last dream:` 行；用
   `git log --since=<last dream>`（全 repo，不限路径）找出此后变更——尤其留意
   `src/`、`docs/components/`、`docs/guides/`、`AGENTS.md` 及新增或 superseding 的
   specs，不止 notes。
2. **对照当前实现校验**：逐条核验 note **以及 `MEMORY.md` 已提升的 Promoted key facts**
   ——对照当前代码/文档（不只靠 dated spec），查找更新或 superseding 的设计；当前实现
   与旧 spec 冲突时以当前实现为准，修正错误、标记 `存疑` 或 `superseded`。绝不盲信
   旧笔记/旧事实（文章：未校验的错误会被下游会话信任）。
3. **更新 wiki**：把验证过的知识更新/链接进现有 wiki（`docs/adr`·`docs/guides`·
   `docs/components`·`docs/superpowers/specs`）。某主题笔记积累多了，才蒸成
   `docs/memory/wiki/<topic>.md`（按需，不预建）。
4. **提升关键事实**：把关键、耐久的事实提升进 `MEMORY.md` 的 `## Promoted key facts`，
   每条带 source 链接。
5. **尺寸守卫**：`MEMORY.md` 保持 < 200 行 / 25KB。超了就把次要条目下沉回 notes/wiki，
   只留最关键的在注入层。
6. **记录时间戳**：更新 `MEMORY.md` 底部 `Last dream: <今天 YYYY-MM-DD>`。

约束（定时任务已上线，policy 即刻生效）：run 前 `git status --short` 必须干净，否则
停下报告（避免与人工编辑并发）；只写 `docs/memory/`（必要时 wiki 链接），不动站点代码、
不改 AGENTS.md；**不 git commit、不 git push**——整理完把 diff 留给人审，由人显式批准后
再提交（遵守 repo 显式提交规则）。

## Part 2 — 调度安装指南（跨 harness）

把 Part 1 注册成定时任务，空闲时自动整理（如每周日）。

- **定时任务 prompt 必须是此固定字符串**（逻辑留在 repo，勿抄进 prompt）：

  ```
  Read docs/memory/DREAM.md and execute the dreaming procedure (Part 1).
  ```

- **Qoder**：用 `qoder_cron` 建每周任务（如周日），prompt 同上。
- **其他 harness**：用各自的定时任务功能，prompt 同上。
- 任务只是薄触发器；逻辑随 repo 版本控制。换 harness 时按本节重建任务即可，无需改逻辑。