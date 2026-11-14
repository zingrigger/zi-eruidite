# mdxcn endpoint 与 chat 试用设计

状态：已实现（2026-11-14）

## 意图

在本站文章中试用 [mdxcn endpoint](https://www.mdxcn.dev/docs/endpoint) 和 [chat](https://www.mdxcn.dev/docs/chat) 两种 Markdown 友好组件，并验证它们能否适配当前 Astro + Sätteri + 纯 Markdown 的静态内容管线。

本次修改同时新增 `openai` 作者条目，使试用文章可以由 OpenAI 署名。

## 背景与约束

- mdxcn 官方组件面向 React/MDX，安装方式是通过 shadcn CLI 将组件源码复制到项目。
- 本站文章使用 `.md`，由 Sätteri 处理，不引入 React、MDX 或文章级 island。
- 本站的交互内容遵循“SSR 静态内容 + 客户端激活”；本次展示不需要客户端状态，因此保持纯静态 HTML。
- 样式必须使用本站原生 CSS 和自主定制元素，不引入 Tailwind、motion 或 mdxcn 运行时依赖。

## 目标

1. 在文章中保留 mdxcn 官方的 MDX 写法示例，方便读者理解原组件的内容模型。
2. 在同一文章中展示可见的 endpoint 和 chat 效果，而不是把 ASCII 画放进普通代码块后当作组件效果。
3. endpoint 展示路由、说明、参数、request 和 response。
4. chat 展示 `you` / `agent` 对话、旁注，以及连续 agent 轮次的合并。
5. 不改变全站 Markdown 处理器，不增加生产运行时依赖。

## 非目标

- 不安装或复制 mdxcn 的 React 组件源码。
- 不把本站 Markdown 管线改造成 MDX。
- 不实现真正的聊天交互、API 请求、复制按钮或 tabs；这里只展示文档内容。
- 不承诺像素级复制官网的全部外围功能（例如官网的 MDX/React/纯文本 tabs）。

## 方案取舍

### 方案 A：直接安装 `@mdxcn/endpoint` / `@mdxcn/chat`

与本站 `.md` + Sätteri 管线不兼容，需要 React/MDX 注册和额外运行时。放弃。

### 方案 B：改造本站 Markdown 管线支持 MDX

可以得到官方组件，但会扩大构建链和客户端依赖，改变全站文章约束。与本次小范围试用不匹配。放弃。

### 方案 C：用自主定制元素复现内容模型和视觉结构

采用。文章仍是普通 `.md`，渲染结果是静态 HTML；通过 `<api-endpoint>` 和 `<api-chat>` 保留 mdxcn 的结构语义，再用职责独立的 CSS 复现 frame、stage、speaker 和代码区块。

## 设计

### 内容与作者

- 文章：`src/content/blog/mdxcn-endpoint/index.md`
- slug：`mdxcn-endpoint`
- 作者：`openai`
- 作者资料：`src/content/authors/openai.md`
- 文章同时包含 endpoint 和 chat 的官方 MDX 源码示例，以及本站静态适配的可见结果。

### endpoint 结构

文章使用以下静态结构表达一条 API：

```html
<api-endpoint>
  <header>ENDPOINT</header>
  <api-route>GET /api/v1/components/:slug</api-route>
  <p>说明</p>
  <api-params>参数定义</api-params>
  <api-blocks>
    <api-block>request</api-block>
    <api-block>response</api-block>
  </api-blocks>
</api-endpoint>
```

`src/styles/endpoint.css` 负责边框、参数表、请求/响应区块和窄屏布局。

### chat 结构

Chat 使用外层 stage 和内层 frame，标题压在 frame 的上边框中间：

```html
<api-chat>
  <chat-frame>
    <header>SESSION</header>
    <chat-turn data-speaker="you">...</chat-turn>
    <chat-turn data-speaker="agent">
      <chat-speaker>agent</chat-speaker>
      <chat-messages>
        <chat-message>...</chat-message>
        <chat-message>...</chat-message>
      </chat-messages>
    </chat-turn>
  </chat-frame>
</api-chat>
```

连续的 agent 内容放在同一个 `chat-turn` 中，避免重复显示 speaker；`you` 轮次由 CSS 生成 `>` 提示符并使用强调色。`src/styles/chat.css` 负责 stage、frame、标题、三列对齐和移动端布局。

### 全局接入

`src/layouts/Layout.astro` 全局导入 `endpoint.css` 和 `chat.css`。元素本身没有 JavaScript 注册逻辑，因为自定义元素标签在 HTML 中可以直接承载静态样式；这样既能 SSR，也不会为一次文档展示增加脚本。

## 验证

离线检查脚本 `scripts/tests/endpoint-check.sh` 检查：

- 文章包含 `<api-endpoint>`、`<api-chat>`、`<chat-frame>` 和 `<chat-messages>`；
- Layout 导入 endpoint/chat 样式；
- 两份样式文件存在；
- endpoint/chat wiring 检查通过。

提交前运行：

```bash
bash scripts/tests/endpoint-check.sh
git diff --check
npm run format:check
npm run build
```

已验证生产构建生成 62 个页面，并在 `dist/blog/mdxcn-endpoint/index.html` 中保留 endpoint/chat 静态结构及对应样式。

## 结果与后续边界

本次试用确认：mdxcn 的内容模型可以在本站静态文章中复用，但官方 React/MDX 组件不能直接安装。当前适配优先保留结构与视觉阅读顺序；若未来需要真正的 tabs、复制交互或数据驱动 API 文档，应另立设计，不在本次试用范围内。
