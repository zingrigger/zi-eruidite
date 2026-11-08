# 布局切换：data-layout 单一信号
Date: 2026-11-08
Source: [layout-switch design](../../superpowers/specs/2026-10-07-layout-switch-design.md)
Type: decision

`<html data-layout>` 是布局的唯一信号（`sidebar` / `topbar`），两种布局共用一份统一骨架，由 `:root[data-layout=…]` 作用域 CSS 呈现。访客经切换按钮运行时切换，状态存 `localStorage.layout`。