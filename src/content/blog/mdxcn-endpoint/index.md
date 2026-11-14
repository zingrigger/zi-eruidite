---
title: "给文档加一点结构：试用 mdxcn 的 endpoint 与 chat"
description: "试用 mdxcn 的 endpoint 与 chat，并看看它们如何适配一个纯 Markdown 的 Astro 博客。"
date: 2026-11-14
authors:
  - openai
tags:
  - tools
  - markdown
  - api
---

API 文档经常卡在两个极端：只给一张参数表，读者不知道请求长什么样；或者贴一大段 OpenAPI，机器很开心，人类要先翻半天。这次试试 [mdxcn 的 endpoint](https://www.mdxcn.dev/docs/endpoint)：它把一条路由、参数、请求和响应收进一个有边界的文本块里。

## 它解决的是什么问题

endpoint 组件的约定很直接：第一行写 HTTP 方法和路径，接着写一句说明，再放参数表，最后放 request 和 response 代码块。必填参数用粗体标记。

在支持 MDX 的项目里，官方的写法是安装并注册 `@mdxcn/endpoint`，然后把 Markdown 写进组件标签中：

````mdx
<Endpoint title="one component">

GET /api/v1/components/:slug

One component from the catalog, with its props.

| name | type | description |
| --- | --- | --- |
| **slug** | string | Registry slug, like `graph-table` |

```bash
curl https://mdxcn.dev/api/v1/components/graph-meter
```

```json
{ "slug": "graph-meter", "name": "GraphMeter", "props": [ … ] }
```

</Endpoint>
````

这里的重点不是 JSX 本身，而是内容结构：一条 endpoint 应该让读者一眼看到“怎么调用”和“会得到什么”。

## 在这个项目里怎么用

本站的文章是 `.md`，Markdown 由 Sätteri 处理；项目也没有引入 React 或 MDX。因此直接粘贴 `<Endpoint>` 不会得到 mdxcn 的交互组件。我把同一套内容改成本站的无运行时 `<api-endpoint>`，先让读者看到最终效果：

<api-endpoint aria-label="API endpoint">
  <header><strong>ENDPOINT</strong></header>
  <api-route><code>GET</code><code>/api/v1/components/:slug</code></api-route>
  <p>One component from the catalog, with its props.</p>
  <api-params>
    <dl>
      <div>
        <dt><strong>slug</strong></dt>
        <dd>string</dd>
        <dd>Registry slug, like graph-table</dd>
      </div>
    </dl>
  </api-params>
  <api-blocks>
    <api-block>
      <h3>request</h3>
      <pre><code>curl https://mdxcn.dev/api/v1/components/graph-meter</code></pre>
    </api-block>
    <api-block>
      <h3>json</h3>
      <pre><code>{ "slug": "graph-meter", "name": "GraphMeter", "props": [ … ] }</code></pre>
    </api-block>
  </api-blocks>
</api-endpoint>

这不是另起炉灶画一张 SVG，而是把 mdxcn 的核心约定映射到本站已有的自主定制元素：边框只是视觉提示，真正重要的是固定的阅读顺序——method/path → 说明 → 参数 → request → response。它不需要客户端脚本，也不会把整个站点改成 MDX。

## 再试试 chat

[Chat](https://www.mdxcn.dev/docs/chat) 的输入更简单：用 `speaker: message` 写对话。`you` 轮次带提示符，连续的 `agent` 轮次可以自然地接在一起；斜体则表示旁注。

```mdx
<Chat title="session">

- you: which graph shows a rollback?
- agent: Timeline. Bold the row where you rolled back.
- agent: *reads graph-timeline.tsx*
- agent: Then Diff for what the rollback changed.
- you: and on GitHub?
- agent: Paste the fenced ASCII. GitHub does not run MDX.

</Chat>
```

本站仍然不能直接运行 `<Chat>`，所以把同一段内容映射为静态的 `<api-chat>`：

<api-chat aria-label="Chat session">
  <chat-frame>
    <header><strong>SESSION</strong></header>
    <chat-turn data-speaker="you">
      <chat-speaker>you</chat-speaker>
      <chat-messages>
        <chat-message><p>which graph shows a rollback?</p></chat-message>
      </chat-messages>
    </chat-turn>
    <chat-turn data-speaker="agent">
      <chat-speaker>agent</chat-speaker>
      <chat-messages>
        <chat-message><p>Timeline. Bold the row where you rolled back.</p></chat-message>
        <chat-message><p><em>reads graph-timeline.tsx</em></p></chat-message>
        <chat-message><p>Then Diff for what the rollback changed.</p></chat-message>
      </chat-messages>
    </chat-turn>
    <chat-turn data-speaker="you">
      <chat-speaker>you</chat-speaker>
      <chat-messages>
        <chat-message><p>and on GitHub?</p></chat-message>
      </chat-messages>
    </chat-turn>
    <chat-turn data-speaker="agent">
      <chat-speaker>agent</chat-speaker>
      <chat-messages>
        <chat-message><p>Paste the fenced ASCII. GitHub does not run MDX.</p></chat-message>
      </chat-messages>
    </chat-turn>
  </chat-frame>
</api-chat>

这个例子说明 Chat 和 Endpoint 的关系：两者都不是“把 Markdown 放进代码块”就自动生效，而是有各自的内容模型。Endpoint 组织一条请求的契约，Chat 组织一段协作上下文；在本站，它们都可以用 SSR 静态 HTML 保留这种结构。

## 我会怎么取舍

如果这只是博客里偶尔出现的一条 API 或一段对话，本站的静态适配已经够用：零依赖、零客户端脚本，也不会改变本站的静态输出。如果以后本站要维护一整套 API 文档，并且希望参数表与对话能复用数据，那么再考虑引入 MDX 或把这些约定抽象成更通用的自主定制元素。

眼下不值得为了一个漂亮的框把全站 Markdown 管线改成 React。mdxcn 的价值可以先以“内容格式”落地，而不是以“运行时依赖”落地。

## 结论

这次试用的结果是：mdxcn endpoint 适合作为 API 说明的版式约定，chat 适合作为协作过程的版式约定；它们的 React/MDX 组件不适合直接装进本站，但内容模型可以通过本站的静态自定义元素保留下来。对于静态博客，这个边界反而很清楚：能用 SSR HTML 表达的，就不要为它增加客户端运行时。
