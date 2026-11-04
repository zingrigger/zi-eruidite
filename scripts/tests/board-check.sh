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
assert_has dist/index.html '收藏板' "中文导航收藏板标签"
assert_has dist/en/index.html 'href="/en/board"' "英文导航含 /en/board 入口"

# ---------- 移动端不展示收藏板（<64rem）：整块隐藏 + 导航入口收起 ----------
assert_has dist/index.html 'data-mobile-hidden' "首页导航项带移动端隐藏标记"
assert_has dist/board/index.html 'data-mobile-hidden' "板页导航项带移动端隐藏标记"
assert_match dist/board/index.html 'board-section\[[^]]*\]\{display:none\}' "移动端隐藏收藏板整块（含页头）"
assert_match dist/en/board/index.html 'board-section\[[^]]*\]\{display:none\}' "英文页同样隐藏收藏板整块"
layout_css="$(grep -l 'data-mobile-hidden' dist/_astro/*.css 2>/dev/null | head -1)"
[ -n "${layout_css}" ] || fail "找不到含导航移动端隐藏规则的产物 CSS"
assert_match "${layout_css}" '\[data-mobile-hidden\]\{display:none\}' "移动端隐藏收藏板导航入口"

# ---------- 板 SSR 静态渲染 ----------
assert_file dist/board/index.html "中文收藏板路由存在"
assert_has dist/board/index.html "<stamp-board" "板容器渲染"
assert_match dist/board/index.html 'board-piece[^>]*--x:' "piece 带 SSR 默认 --x"
assert_has dist/board/index.html 'data-kind="stamp"' "stamp 类渲染"
assert_has dist/board/index.html 'data-kind="badge"' "badge 类渲染"
assert_has dist/board/index.html 'aria-label="DeepSeek"' "DeepSeek 徽章入板"
assert_has dist/board/index.html 'aria-label="人写的代码"' "humancoded 字标徽章入板"
assert_has dist/board/index.html "--badge-h:40px" "横版字标按 size 压小高度"
assert_has dist/en/board/index.html 'aria-label="Human Coded"' "英文页字标徽章取 en 标题"
assert_lacks dist/board/index.html 'astro.en' "中文板不泄漏 .en id"

# ---------- dev 编辑器：几何双向一致的渲染前置 ----------
assert_match dist/board/index.html 'board-piece[^>]*data-id="astro"' "piece 带 data-id（保存配对键）"
assert_match dist/board/index.html 'board-piece[^>]*--sx:' "piece SSR 即写 --sx（镜像可往返）"

# ---------- dev 编辑器生产零痕迹 ----------
assert_lacks dist/board/index.html "<board-editor" "生产产物无编辑条"

# ---------- 拖拽客户端激活脚本入产物 ----------
# Astro 7 把组件 <script> 提成独立 chunk（不再内联回 HTML），断言得指向产物 JS
board_js="$(find dist/_astro -name 'Board.astro_astro_type_script_index_*.js' 2>/dev/null | head -1)"
[ -n "${board_js}" ] || fail "找不到 Board 客户端脚本 chunk（组件脚本未入产物？）"
assert_has "${board_js}" "customElements.define" "板激活脚本入产物"
assert_has "${board_js}" "setPointerCapture" "拖拽用 Pointer Capture"

# ---------- 英文路由与未翻译回退 ----------
assert_file dist/en/board/index.html "英文收藏板路由存在"
assert_has dist/en/board/index.html "Astro (EN)" "已翻译物件显示英文标题"
assert_has dist/en/board/index.html "登月邮票" "未翻译物件回落中文标题（非空）"
assert_lacks dist/en/board/index.html 'aria-label="undefined"' "英文板无 undefined 泄漏"
assert_has dist/en/board/index.html 'hreflang="zh-CN"' "英文板输出 zh alternate"

# ---------- 终审修复：无障碍 role + Firefox 原生拖拽 ----------
assert_match dist/board/index.html 'board-piece[^>]*role="group"' "piece 带 role=group（aria-label 生效）"
assert_has dist/board/index.html 'draggable="false"' "徽章链接禁原生拖拽（Firefox）"
assert_has "${board_js}" "dragstart" "板上拦截原生拖拽（图片默认可拖会抢走 pointer）"

# ---------- 右侧分类标签（全部/邮票/徽章） ----------
assert_has dist/board/index.html "<board-tabs" "标签栏渲染"
assert_match dist/board/index.html 'stamp-board[^>]*data-view="all"' "默认视图=全部"
assert_has dist/board/index.html 'data-view="stamp"' "邮票标签存在"
assert_has dist/board/index.html 'data-view="badge"' "徽章标签存在"

# ---------- 板下方无工具条：拿起物件全靠板内交互 ----------
assert_lacks dist/board/index.html "<board-tools" "底部工具条已撤"
assert_match dist/board/index.html 'stamp-board[^>]*data-tool="drag"' "SSR 默认工具态=拖拽"
assert_has dist/board/index.html 'data-op="zoom-in"' "放大按钮存在"
assert_has dist/board/index.html 'data-op="zoom-out"' "缩小按钮存在"
assert_has dist/board/index.html 'data-op="rotate-cw"' "顺时针旋转按钮存在"
assert_has dist/board/index.html 'data-op="rotate-ccw"' "逆时针旋转按钮存在"
assert_has dist/board/index.html 'data-op="mirror"' "镜像按钮存在"
assert_has dist/board/index.html 'data-op="front"' "置顶按钮存在"
assert_has dist/board/index.html 'data-op="back"' "置底按钮存在"
assert_has dist/board/index.html 'data-op="info"' "信息按钮存在"

# ---------- info 信息小卡片：骨架 SSR、默认隐藏，数据住在 DOM 里 ----------
assert_has dist/board/index.html "<board-card" "信息卡片容器渲染"
assert_match dist/board/index.html 'board-card[^>]*hidden' "信息卡片 SSR 默认隐藏（无 JS 不出现）"
assert_has dist/board/index.html 'data-source-label="来源"' "中文来源标签入骨架"
assert_has dist/en/board/index.html 'data-source-label="Source"' "英文来源标签入骨架"
assert_has dist/en/board/index.html 'aria-label="Info"' "英文信息按钮界面词"
assert_has dist/board/index.html 'data-href="https://' "邮票纸面带来源 data-href（卡片可查）"
assert_has "${board_js}" "card-title" "卡片建档逻辑入产物 JS"
assert_has "${board_js}" "card-close" "卡片关闭钮入产物 JS"

# ---------- 物件外上角的径向操作浮层 + 板下提示行 ----------
assert_has dist/board/index.html "<board-menu" "浮层容器渲染"
assert_match dist/board/index.html 'board-menu[^>]*hidden' "浮层 SSR 默认隐藏（无 JS 不出现）"
assert_has dist/board/index.html "物件操作" "中文浮层 aria-label"
assert_has dist/board/index.html "<board-hint" "板下提示行渲染"
assert_has dist/board/index.html "右键、长按或 Tab" "中文提示行界面词"
assert_has dist/en/board/index.html "Piece actions" "英文浮层 aria-label"
assert_has dist/en/board/index.html "Send to back" "英文操作按钮界面词"
assert_has dist/en/board/index.html "Right-click, long-press" "英文提示行界面词"

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
assert_has dist/board/index.html "<ticket-collage" "票券拼贴容器渲染"
assert_has dist/board/index.html "<ticket-card" "票券卡 SSR 静态渲染"
assert_has dist/board/index.html "tk-voucher" "礼品券版式（齿孔边）"
assert_has dist/board/index.html "tk-coupon" "折扣券版式"
assert_has dist/board/index.html "tk-eticket" "电子门票版式"
assert_has dist/board/index.html "tk-bar" "条形码入产物"
assert_has dist/board/index.html "tk-qr" "电子门票点阵码入产物"
assert_has dist/board/index.html "--tk-mask:url(" "票券撕口/齿孔 mask 入产物"
assert_has dist/board/index.html "票券" "中文票券区标题"
assert_has dist/en/board/index.html "<ticket-collage" "英文页票券区渲染"
assert_has dist/en/board/index.html "Tickets" "英文票券区标题"

# ---------- 票券图片主题 + 切换控件 ----------
assert_has dist/board/index.html "<ticket-showcase" "票券 showcase 容器"
assert_match dist/board/index.html 'ticket-showcase[^>]*data-theme="solid"' "默认主题=solid（纯蓝白）"
assert_has dist/board/index.html "<ticket-theme" "主题切换控件渲染"
assert_has dist/board/index.html 'data-theme-btn="image"' "图片主题按钮存在"
assert_has dist/board/index.html "tk-fill" "图片填充图层入 SSR"
assert_has dist/board/index.html "tk-fill-img" "填充图层走 Astro <Image> 优化"
assert_has dist/board/index.html "票券主题" "中文切换控件 aria-label"
assert_has dist/en/board/index.html "Ticket theme" "英文切换控件 aria-label"

# ---------- 票券悬停倾斜：默认就在、没有开关 + 脚本 chunk ----------
assert_lacks dist/board/index.html "data-tilt-btn" "倾斜开关按钮已移除"
assert_lacks dist/board/index.html 'tk-tilt-btn' "倾斜开关样式已移除"
assert_lacks dist/board/index.html 'data-tilt="on"' "倾斜不再有运行态属性"
# 票券脚本含 import（复用 lenticular-spring）→ 提成 chunk，不再内联进 HTML
tk_js="$(grep -rl 'ticket-showcase' dist/_astro/*.js 2>/dev/null | head -1)"
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
tk_css="$(grep -l 'ticket-slot' dist/_astro/*.css 2>/dev/null | head -1)"
[ -n "${tk_css}" ] || fail "找不到含 ticket-slot 规则的产物 CSS"
assert_match "${tk_css}" 'rotateX\(var\(--tk-rx' "票券倾斜的 transform 读 --tk-rx/--tk-ry"

# ---------- 层叠上下文回归：置底负 z 不得沉到板面背景之下 ----------
# 新增 scoped 组件（如票券）会让 Astro 合并 CSS chunk、文件名漂移，故按「含
# board-grid 规则的那份 CSS」定位，不钉死 Board.*.css 文件名
board_css="$(grep -lE "board-grid" dist/_astro/*.css 2>/dev/null | head -1)"
[ -n "${board_css}" ] || fail "找不到含 board-grid 规则的产物 CSS"
if grep -qE "isolation:[[:space:]]*isolate" "${board_css}"; then
  pass "board-grid 独立层叠上下文（isolation: isolate）"
else
  fail "board-grid 缺 isolation: isolate（置底负 z 物件会消失在板面下）"
fi
