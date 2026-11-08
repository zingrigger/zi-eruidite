#!/usr/bin/env bash
# 收藏板 /board 回归校验：临时写入受控 .env（仅 SITE_URL）后构建，再对 dist 输出断言。
# 本脚本先建导航基线，后续 Task 追加板渲染、拖拽脚本、英文路由等断言。
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
ENV_KEEP=/tmp/board-check.env.keep
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

# ---------- 导航入口双语就位 ----------
assert_has dist/index.html 'href="/board"' "中文导航含 /board 入口"
assert_has dist/index.html '玩具柜' "中文导航玩具柜标签"
assert_has dist/en/index.html 'Toy Cabinet' "英文导航 Toy Cabinet 标签"
assert_has dist/en/index.html 'href="/en/board"' "英文导航含 /en/board 入口"

# ---------- 移动端不展示收藏板（<64rem）：整块隐藏 + 导航入口收起 ----------
assert_has dist/index.html 'data-mobile-hidden' "首页导航项带移动端隐藏标记"
assert_has dist/board/index.html 'data-mobile-hidden' "板页导航项带移动端隐藏标记"
for wide_page in dist/board/index.html dist/en/board/index.html; do
  assert_has "$wide_page" 'data-wide-only' "列表里 stamps 条目带窄屏隐藏标记（${wide_page}）"
  # `|| true` 是必需的：pipefail 下 grep 无命中会让整条赋值退出，脚本静悄悄死掉，
  # 下面那句带消息的 fail 永远走不到
  wide_css="$(grep -lE 'data-wide-only' "$wide_page" dist/_astro/*.css 2>/dev/null | head -1 || true)"
  [ -n "${wide_css}" ] || fail "找不到 data-wide-only 规则（${wide_page} 与 CSS chunk 都没有）"
  # 规则住在 BoardIndex 的 scoped style 里，选择器带 [data-astro-cid-*]，故跨过属性匹配；
  # 但必须钉住 li 前缀——BoardExhibit 的子页规则同样写作 [data-wide-only]{display:none}，
  # 不钉住就会拿子页规则冒充「列表条目被隐藏」这条
  assert_match "$wide_css" 'li[^{]*data-wide-only\]\{display:none\}' "窄屏隐藏 stamps 列表条目（${wide_page}）"
done
layout_css="$(grep -l 'data-mobile-hidden' dist/_astro/*.css 2>/dev/null | head -1 || true)"
[ -n "${layout_css}" ] || fail "找不到含导航移动端隐藏规则的产物 CSS"
assert_match "${layout_css}" '\[data-mobile-hidden\]\{display:none\}' "移动端隐藏收藏板导航入口"

# ---------- 板 SSR 静态渲染 ----------
assert_file dist/board/stamps/index.html "中文邮票板子页路由存在"
assert_has dist/board/stamps/index.html "<stamp-board" "板容器渲染"
assert_match dist/board/stamps/index.html 'board-piece[^>]*--x:' "piece 带 SSR 默认 --x"
assert_has dist/board/stamps/index.html 'data-kind="stamp"' "stamp 类渲染"
assert_has dist/board/stamps/index.html 'data-kind="badge"' "badge 类渲染"
assert_has dist/board/stamps/index.html 'aria-label="DeepSeek"' "DeepSeek 徽章入板"
assert_has dist/board/stamps/index.html 'aria-label="人写的代码"' "humancoded 字标徽章入板"
assert_has dist/board/stamps/index.html "--badge-h:40px" "横版字标按 size 压小高度"
assert_has dist/en/board/stamps/index.html 'aria-label="Human Coded"' "英文页字标徽章取 en 标题"
assert_lacks dist/board/stamps/index.html 'astro.en' "中文板不泄漏 .en id"

# ---------- dev 编辑器：几何双向一致的渲染前置 ----------
assert_match dist/board/stamps/index.html 'board-piece[^>]*data-id="astro"' "piece 带 data-id（保存配对键）"
assert_match dist/board/stamps/index.html 'board-piece[^>]*--sx:' "piece SSR 即写 --sx（镜像可往返）"

# ---------- dev 编辑器生产零痕迹 ----------
assert_lacks dist/board/stamps/index.html "<board-editor" "生产产物无编辑条"

# ---------- 拖拽客户端激活脚本入产物 ----------
# Astro 7 把组件 <script> 提成独立 chunk（不再内联回 HTML），断言得指向产物 JS
board_js="$(find dist/_astro -name 'Board.astro_astro_type_script_index_*.js' 2>/dev/null | head -1 || true)"
[ -n "${board_js}" ] || fail "找不到 Board 客户端脚本 chunk（组件脚本未入产物？）"
assert_has "${board_js}" "customElements.define" "板激活脚本入产物"
assert_has "${board_js}" "setPointerCapture" "拖拽用 Pointer Capture"

# ---------- 英文路由与未翻译回退 ----------
assert_file dist/en/board/stamps/index.html "英文邮票板子页路由存在"
assert_has dist/en/board/stamps/index.html "Astro (EN)" "已翻译物件显示英文标题"
assert_has dist/en/board/stamps/index.html "登月邮票" "未翻译物件回落中文标题（非空）"
assert_lacks dist/en/board/stamps/index.html 'aria-label="undefined"' "英文板无 undefined 泄漏"
assert_has dist/en/board/stamps/index.html 'hreflang="zh-CN"' "英文板输出 zh alternate"

# ---------- 终审修复：无障碍 role + Firefox 原生拖拽 ----------
assert_match dist/board/stamps/index.html 'board-piece[^>]*role="group"' "piece 带 role=group（aria-label 生效）"
assert_has dist/board/stamps/index.html 'draggable="false"' "徽章链接禁原生拖拽（Firefox）"
assert_has "${board_js}" "dragstart" "板上拦截原生拖拽（图片默认可拖会抢走 pointer）"

# ---------- 右侧分类标签（全部/邮票/徽章） ----------
assert_has dist/board/stamps/index.html "<board-tabs" "标签栏渲染"
assert_match dist/board/stamps/index.html 'stamp-board[^>]*data-view="all"' "默认视图=全部"
assert_has dist/board/stamps/index.html 'data-view="stamp"' "邮票标签存在"
assert_has dist/board/stamps/index.html 'data-view="badge"' "徽章标签存在"

# ---------- 板下方无工具条：拿起物件全靠板内交互 ----------
assert_lacks dist/board/stamps/index.html "<board-tools" "底部工具条已撤"
assert_match dist/board/stamps/index.html 'stamp-board[^>]*data-tool="drag"' "SSR 默认工具态=拖拽"
assert_has dist/board/stamps/index.html 'data-op="zoom-in"' "放大按钮存在"
assert_has dist/board/stamps/index.html 'data-op="zoom-out"' "缩小按钮存在"
assert_has dist/board/stamps/index.html 'data-op="rotate-cw"' "顺时针旋转按钮存在"
assert_has dist/board/stamps/index.html 'data-op="rotate-ccw"' "逆时针旋转按钮存在"
assert_has dist/board/stamps/index.html 'data-op="mirror"' "镜像按钮存在"
assert_has dist/board/stamps/index.html 'data-op="front"' "置顶按钮存在"
assert_has dist/board/stamps/index.html 'data-op="back"' "置底按钮存在"
assert_has dist/board/stamps/index.html 'data-op="info"' "信息按钮存在"

# ---------- info 信息小卡片：骨架 SSR、默认隐藏，数据住在 DOM 里 ----------
assert_has dist/board/stamps/index.html "<board-card" "信息卡片容器渲染"
assert_match dist/board/stamps/index.html 'board-card[^>]*hidden' "信息卡片 SSR 默认隐藏（无 JS 不出现）"
assert_has dist/board/stamps/index.html 'data-source-label="来源"' "中文来源标签入骨架"
assert_has dist/en/board/stamps/index.html 'data-source-label="Source"' "英文来源标签入骨架"
assert_has dist/en/board/stamps/index.html 'aria-label="Info"' "英文信息按钮界面词"
assert_has dist/board/stamps/index.html 'data-href="https://' "邮票纸面带来源 data-href（卡片可查）"
assert_has "${board_js}" "card-title" "卡片建档逻辑入产物 JS"
assert_has "${board_js}" "card-close" "卡片关闭钮入产物 JS"

# ---------- 物件外上角的径向操作浮层 + 板下提示行 ----------
assert_has dist/board/stamps/index.html "<board-menu" "浮层容器渲染"
assert_match dist/board/stamps/index.html 'board-menu[^>]*hidden' "浮层 SSR 默认隐藏（无 JS 不出现）"
assert_has dist/board/stamps/index.html "物件操作" "中文浮层 aria-label"
assert_has dist/board/stamps/index.html "<board-hint" "板下提示行渲染"
assert_has dist/board/stamps/index.html "右键、长按或 Tab" "中文提示行界面词"
assert_has dist/en/board/stamps/index.html "Piece actions" "英文浮层 aria-label"
assert_has dist/en/board/stamps/index.html "Send to back" "英文操作按钮界面词"
assert_has dist/en/board/stamps/index.html "Right-click, long-press" "英文提示行界面词"

# ---------- 拿起物件的三条入口与浮层几何（均入产物 JS） ----------
assert_has "${board_js}" "contextmenu" "鼠标右键拿起"
assert_has "${board_js}" "pointerType" "按 pointer 类型分流鼠标/触屏长按"
assert_has "${board_js}" "setTimeout" "触屏长按计时器"
assert_has "${board_js}" "ContextMenu" "键盘菜单键入口"
assert_has "${board_js}" "ArrowRight" "浮层内方向键走位"
assert_has "${board_js}" "Escape" "Esc 放下物件"
assert_has "${board_js}" "menu-btn" "浮层按钮选择器"
assert_has "${board_js}" "--menu-r" "浮层半径参与 JS 翻转判定"
assert_has "${board_js}" "interactive" "客户端激活标记点亮提示行"

# ---------- 板下票券组静态展示区（仿光栅卡，独立于 board-grid、不参与拖拽） ----------
assert_has dist/board/tickets/index.html "<ticket-collage" "票券拼贴容器渲染"
assert_has dist/board/tickets/index.html "<ticket-card" "票券卡 SSR 静态渲染"
assert_has dist/board/tickets/index.html "tk-voucher" "礼品券版式（齿孔边）"
assert_has dist/board/tickets/index.html "tk-coupon" "折扣券版式"
assert_has dist/board/tickets/index.html "tk-eticket" "电子门票版式"
assert_has dist/board/tickets/index.html "tk-bar" "条形码入产物"
assert_has dist/board/tickets/index.html "tk-qr" "电子门票点阵码入产物"
assert_has dist/board/tickets/index.html "--tk-mask:url(" "票券撕口/齿孔 mask 入产物"
assert_has dist/board/tickets/index.html "票券" "中文票券区标题"
assert_has dist/en/board/tickets/index.html "<ticket-collage" "英文页票券区渲染"
assert_has dist/en/board/tickets/index.html "Tickets" "英文票券区标题"

# ---------- 票券图片主题 + 切换控件 ----------
assert_has dist/board/tickets/index.html "<ticket-showcase" "票券 showcase 容器"
assert_match dist/board/tickets/index.html 'ticket-showcase[^>]*data-theme="solid"' "默认主题=solid（纯蓝白）"
assert_has dist/board/tickets/index.html "<ticket-theme" "主题切换控件渲染"
assert_has dist/board/tickets/index.html 'data-theme-btn="image"' "图片主题按钮存在"
assert_has dist/board/tickets/index.html "tk-fill" "图片填充图层入 SSR"
assert_has dist/board/tickets/index.html "tk-fill-img" "填充图层走 Astro <Image> 优化"
assert_has dist/board/tickets/index.html "票券主题" "中文切换控件 aria-label"
assert_has dist/en/board/tickets/index.html "Ticket theme" "英文切换控件 aria-label"

# ---------- 票券悬停倾斜：默认就在、没有开关 + 脚本 chunk ----------
assert_lacks dist/board/tickets/index.html "data-tilt-btn" "倾斜开关按钮已移除"
assert_lacks dist/board/tickets/index.html 'tk-tilt-btn' "倾斜开关样式已移除"
assert_lacks dist/board/tickets/index.html 'data-tilt="on"' "倾斜不再有运行态属性"
# 票券脚本含 import（复用 lenticular-spring）→ 提成 chunk，不再内联进 HTML
tk_js="$(grep -rl 'ticket-showcase' dist/_astro/*.js 2>/dev/null | head -1 || true)"
[ -n "${tk_js}" ] || fail "找不到票券脚本 chunk（TicketSection script 未入产物？）"
assert_has "${tk_js}" "themeBtn" "主题切换逻辑入产物 chunk"
assert_has "${tk_js}" "ticket-slot" "倾斜默认挂载：脚本遍历每个 ticket-slot"
assert_has "${tk_js}" "pointerenter" "悬停监听在 chunk 里（无需先点按钮）"
assert_has "${tk_js}" "prefers-reduced-motion" "倾斜模块的 reduced-motion 守卫"

# ---------- 倾斜变量名不得撞 lenticular.css 全局注册的 @property ----------
# @property 无作用域：--rx/--ry 被注册成文档级 <number>，往它写 8deg 会
# invalid at computed-value time 落回 0（倾角永远为 0），写裸数字又让整条
# transform 作废成 none。票券曾因此静悄悄坏了一版，故在产物里钉住名字。
assert_has "${tk_js}" "--tk-rx" "倾斜脚本写 --tk-rx（不是被注册的 --rx）"
# 注意用裸 token：esbuild 会把字符串字面量改写成反引号，带引号的断言会空过
assert_lacks "${tk_js}" "--rx" "倾斜脚本不再碰全局注册的 --rx"
tk_css="$(grep -l 'ticket-slot' dist/_astro/*.css 2>/dev/null | head -1 || true)"
[ -n "${tk_css}" ] || fail "找不到含 ticket-slot 规则的产物 CSS"
assert_match "${tk_css}" 'rotateX\(var\(--tk-rx' "票券倾斜的 transform 读 --tk-rx/--tk-ry"

# ---------- 层叠上下文回归：置底负 z 不得沉到板面背景之下 ----------
# 新增 scoped 组件（如票券）会让 Astro 合并 CSS chunk、文件名漂移，故按「含
# board-grid 规则的那份 CSS」定位，不钉死 Board.*.css 文件名
board_css="$(grep -lE "board-grid" dist/_astro/*.css 2>/dev/null | head -1 || true)"
[ -n "${board_css}" ] || fail "找不到含 board-grid 规则的产物 CSS"
if grep -qE "isolation:[[:space:]]*isolate" "${board_css}"; then
  pass "board-grid 独立层叠上下文（isolation: isolate）"
else
  fail "board-grid 缺 isolation: isolate（置底负 z 物件会消失在板面下）"
fi

# ---------- 四个展品子页：路由就位 ----------
for slug in stamps lenticular-card tickets birds; do
  assert_file "dist/board/${slug}/index.html" "中文展品子页 /board/${slug}"
  assert_file "dist/en/board/${slug}/index.html" "英文展品子页 /en/board/${slug}"
  assert_has "dist/board/${slug}/index.html" 'hreflang="en"' "子页输出 en alternate"
  assert_has "dist/en/board/${slug}/index.html" 'hreflang="zh-CN"' "英文子页输出 zh alternate"
  # 不能用 '玩具柜'：那个标签在每页导航里都有，crumbs 整段删掉也照样过。
  # SiteBar 给面包屑的 li 打了 data-crumb（列表页 0 个、子页各 1 个），顺着它钉 href
  assert_match "dist/board/${slug}/index.html" \
    'data-crumb[^>]*>[[:space:]]*<a href="/board"' "子页 crumbs 指回列表页"
done

# ---------- 子页只背自己的脚本（Review Focus 2） ----------
# 正反两个方向都要钉：先确认「本页确实带上自己那件的脚本」，再确认「不带其余三件」。
# 只留反向断言时，展品接线整体坏掉（每页都不带任何展品脚本）也会全绿。
#
# 断言单位取组件脚本里的字面量，不取 chunk 文件名：Astro 是否把组件脚本提成 chunk
# 取决于模块图——实测把 LenticularSection 从光栅卡展品里摘掉，票券脚本就从
# TicketSection.astro_astro_type_script_*.js 变回内联进页面 HTML，按文件名断言会假失败。
# 搜索域因此是「页面 HTML 本身 + 该页引用的每个 chunk」。
#
# 四个 token 逐条验过：各自只出现在本展品的脚本里，且四个页面的 markup 里都不出现
# （否则静态标签就能替脚本说话，正向对照会空过）。aria-valuemax 是挂载后由 JS 补的
# slider 语义，静态态故意不带（lenticular-check 另有反向断言），所以它是脚本在场的好证据。
own_token() {
  case "$1" in
    stamps) echo "dialog.board-preview" ;;
    lenticular-card) echo "aria-valuemax" ;;
    tickets) echo "themeBtn" ;;
    birds) echo "dialog.bird-preview" ;;
  esac
}

has_token() { # $1=页面 $2=token
  for src in "$1" $(grep -o '/_astro/[^"]*\.js' "$1" | sed 's|^|dist|'); do
    [ -f "${src}" ] || continue
    if grep -qF -- "$2" "${src}"; then return 0; fi
  done
  return 1
}

for slug in stamps lenticular-card tickets birds; do
  page="dist/board/${slug}/index.html"
  if has_token "${page}" "$(own_token "${slug}")"; then
    pass "${slug} 子页带上自己的脚本（正向对照）"
  else
    fail "${slug} 子页没带上自己的脚本（展品接线断了，反向断言也会空过）"
  fi
  for other in stamps lenticular-card tickets birds; do
    [ "${other}" = "${slug}" ] && continue
    if has_token "${page}" "$(own_token "${other}")"; then
      fail "${slug} 子页串进了 ${other} 的脚本"
    fi
    pass "${slug} 子页不含 ${other} 脚本"
  done
done

# ---------- 不存在的 slug 不产出页面（Review Focus 4） ----------
[ ! -f dist/board/nope/index.html ] || fail "未知 slug 竟产出了页面"
pass "未知 slug 不产出页面"

# ---------- 窄屏直接访问 stamps 不白屏（Review Focus 3） ----------
assert_has dist/board/stamps/index.html 'data-wide-only' "邮票板宿主带窄屏隐藏标记"
assert_has dist/board/stamps/index.html '这件展品需要宽屏' "窄屏宽屏提示入 SSR"
assert_has dist/en/board/stamps/index.html 'needs a wide screen' "英文窄屏提示"

# ---------- 附注跟着展品走 ----------
assert_has dist/board/stamps/index.html 'df.fenx.work/llm-things' "邮票板参考与 SVG 署名"
assert_has dist/en/board/stamps/index.html 'df.fenx.work/llm-things' "英文页同样保留 SVG 署名"
assert_has dist/board/birds/index.html 'PolyForm' "鸟板授权署名随展品搬迁"
assert_has dist/board/birds/index.html 'huashu-bird-sticker' "鸟板仓库链接随展品搬迁"

# ---------- 玩具柜列表页 ----------
assert_file dist/board/index.html "中文列表页产出"
assert_file dist/en/board/index.html "英文列表页产出"
# ListingHead 有 scoped style，h1 会带 data-astro-cid-*，故用正则跨过属性
assert_match dist/board/index.html 'listing-title[^>]*>玩具柜' "列表页标题"
# 'Toy Cabinet' 单独 grep 会空过：标题/og/twitter/导航里都有它，h1 没了也照样绿
assert_match dist/en/board/index.html 'listing-title[^>]*>Toy Cabinet' "英文列表页标题（h1）"
for slug in stamps lenticular-card tickets birds; do
  assert_has dist/board/index.html "href=\"/board/${slug}\"" "列表含 ${slug} 入口"
  assert_has dist/en/board/index.html "href=\"/en/board/${slug}\"" "英文列表含 ${slug} 入口"
done
assert_has dist/board/index.html '邮票和拼贴' "条目一改名生效"

# ---------- 列表页不背任何展品（Review Focus 1） ----------
assert_lacks dist/board/index.html '<stamp-board' "列表页不含邮票板"
assert_lacks dist/board/index.html '<bird-board' "列表页不含鸟板"
assert_lacks dist/board/index.html '<lenticular-card' "列表页不含光栅卡"
assert_lacks dist/board/index.html '<ticket-collage' "列表页不含票券"
# 脚本这一维统一用 own_token/has_token 判（同「子页只背自己的脚本」段的理由）：
# 按 chunk 文件名 grep，一旦 Astro 把脚本内联进 HTML 就会假通过，而列表页背着四件 JS
# 正是本次要消灭的原始毛病，不能只靠文件名兜住。
for ex in stamps lenticular-card tickets birds; do
  if has_token dist/board/index.html "$(own_token "${ex}")"; then
    fail "列表页串进了 ${ex} 展品的脚本"
  fi
  pass "列表页不含 ${ex} 展品脚本"
done
assert_lacks dist/board/index.html 'DONGLONGDONG' "列表页不加载展品图片"
