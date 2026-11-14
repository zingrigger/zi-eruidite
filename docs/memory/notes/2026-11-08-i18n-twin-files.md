# i18n：同目录 .en.md 孪生文件
Date: 2026-11-08
Source: [i18n guide](../../guides/i18n.md)
Type: verified-rule

英文内容以同目录孪生文件提供：中文文件加 `.en.md` 后缀即英文版（`welcome/index.md` ↔ `welcome/index.en.md`）。blog loader 用自定义 `generateId` 保留 `.en` 标记（默认 glob loader 会吞掉点）。未翻译内容在 `/en/` 下有 badge / noindex / 占位锚点等呈现规则。