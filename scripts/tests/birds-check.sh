#!/usr/bin/env bash
# 鸟类收藏板分区（/board 票券区下方）回归校验：临时写入受控 .env（仅 SITE_URL）后构建，
# 再对 dist 输出断言。仿 board-check.sh：按内容 grep 定位 chunk，不钉文件名（应对 Astro
# chunk 漂移）。历史：曾为独立 /birds 路由，后迁入 /board，本脚本随迁并钉住路由已撤。
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1" >&2; exit 1; }

assert_file() { # $1=路径 [$2=说明]
  [ -f "${1}" ] || fail "${2:-断言文件存在}（缺少 ${1}）"
  pass "${2:-${1}}"
}

assert_has() { # $1=文件 $2=片段 [$3=说明]
  [ -f "${1}" ] || fail "${3:-断言包含}（缺少 ${1}）"
  grep -qF -- "${2}" "${1}" || fail "${3:-断言包含}（${1} 未找到 ${2}）"
  pass "${3:-${1} 包含 ${2}}"
}

assert_lacks() { # $1=文件 $2=片段 [$3=说明]
  [ -f "${1}" ] || fail "${3:-断言不包含}（缺少 ${1}）"
  if grep -qF -- "${2}" "${1}"; then
    fail "${3:-断言不包含}（${1} 出现 ${2}）"
  fi
  pass "${3:-${1} 不含 ${2}}"
}

assert_match() { # $1=文件 $2=正则 [$3=说明]
  [ -f "${1}" ] || fail "${3:-断言匹配}（缺少 ${1}）"
  grep -qE -- "${2}" "${1}" || fail "${3:-断言匹配}（${1} 未匹配 ${2}）"
  pass "${3:-${1} 匹配 ${2}}"
}

# 受控 .env：备份 → 仅写 SITE_URL → 退出时恢复原文件
ENV_KEEP=/tmp/birds-check.env.keep
if [ -f .env ]; then cp .env "$ENV_KEEP"; else rm -f "$ENV_KEEP"; fi
cleanup_restore() {
  if [ -f "$ENV_KEEP" ]; then
    mv -f "$ENV_KEEP" .env
  else
    rm -f .env
  fi
}
trap cleanup_restore EXIT

printf 'SITE_URL=https://example.com\n' > .env
npm run build

# ---------- 独立 /birds 路由已撤（入口只剩 /board 分区） ----------
assert_lacks dist/index.html 'href="/birds"' "中文导航不含 /birds 入口"
assert_lacks dist/en/index.html 'href="/en/birds"' "英文导航不含 /en/birds 入口"
assert_lacks dist/sitemap-0.xml '/birds' "sitemap 不含 /birds"

# ---------- zh /board 内的鸟类 SSR 骨架 ----------
assert_file dist/board/index.html "中文 /board 路由存在"
assert_has dist/board/index.html "<bird-board" "bird-board 容器渲染"
assert_has dist/board/index.html "<bird-tray" "托盘渲染"
assert_match dist/board/index.html 'bird-piece[^>]*--x:' "默认 piece 带 SSR --x"
assert_has dist/board/index.html 'class="bird-img"' "鸟图按徽章范式渲染"
assert_has dist/board/index.html 'raw.githubusercontent.com' "hotlink 外链入产物"

# ---------- 默认 5 只在板上 ----------
for id in Aix_galericulata Calypte_anna Aptenodytes_forsteri Alcedo_atthis Ara_macao; do
  assert_match dist/board/index.html "bird-piece[^>]*data-id=\"$id\"" "默认 5 只之一 $id 在板上"
done

# ---------- 授权署名（随分区迁入 /board，硬要求） ----------
assert_has dist/board/index.html 'PolyForm' "鸟类区含许可署名"
assert_has dist/board/index.html 'huashu-bird-sticker' "鸟类区含仓库链接"

# ---------- en /board 内的英文名 + 无 .en 泄漏 ----------
assert_file dist/en/board/index.html "英文 /en/board 路由存在"
assert_has dist/en/board/index.html 'Emperor Penguin' "英文分区取 en 名"
assert_has dist/board/index.html '帝企鹅' "中文分区取 zh 名"
assert_lacks dist/board/index.html 'astro.en' "中文页不泄漏 .en id"

# ---------- Task 2：客户端激活脚本入产物 ----------
# 按内容 grep 定位 chunk（不钉文件名，应对 Astro chunk 漂移）；
# esbuild 会把字符串字面量改写成反引号，故引号形态用字符类兜住
bird_js="$(grep -rlE 'customElements\.define\(.bird-board' dist/_astro 2>/dev/null | head -1)"
[ -n "${bird_js}" ] || fail "找不到 bird-board 激活脚本（组件脚本未入产物？）"
assert_has "${bird_js}" "setPointerCapture" "拖拽用 Pointer Capture"
assert_has "${bird_js}" "matchMedia" "宽屏门槛判定"

# ---------- Task 3：托盘飞入 + 重置 + 收集计数 ----------
assert_has dist/board/index.html 'class="bird-reset"' "重置按钮渲染"
assert_has dist/board/index.html 'data-count' "收集计数占位渲染"
# @keyframes 在 scoped <style> 里，Astro 可能提为 CSS chunk：HTML 与产物 CSS 两处任一命中即可
if grep -qE '@keyframes bird-toss|bird-toss' dist/board/index.html || grep -qsE '@keyframes bird-toss' dist/_astro/*.css; then
  pass "飞入关键帧入产物"
else
  fail "飞入关键帧未入产物（bird-toss 在 HTML 与 CSS chunk 都找不到）"
fi
assert_has "${bird_js}" "bird-enter" "飞入类名入脚本"
# 动态建件必须克隆 SSR 件的 data-astro-cid-*（scoped 样式靠属性选择器命中；
# 丢了这条约定，新 piece 的 .bird-img 尺寸与 bird-toss 关键帧会静默失效）
assert_has "${bird_js}" "data-astro-cid" "cid 克隆约定入脚本"

# ---------- Task 4：双击原图预览（复用 glass-bubble） ----------
assert_match dist/board/index.html 'class="[^"]*bird-preview' "预览 dialog 骨架渲染"
assert_has src/styles/glass-bubble.css 'bird-preview' "全局样式覆盖 bird-preview"
