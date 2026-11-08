# 部署：hexo 式强推 + CNAME 必须在源码
Date: 2026-11-08
Source: [deployment guide](../../guides/deployment.md)
Type: gotcha

`npm run deploy` = `astro build` + 把 `dist/` 全量强推到 `.env` 的 `DEPLOY_REPO` / `DEPLOY_BRANCH` 指定的 Pages 仓库（`git push --force`）。`CNAME` 必须放在 `public/` 源码里：部署是全量覆盖，GitHub 设置生成的 `CNAME` 会被下次部署清掉。