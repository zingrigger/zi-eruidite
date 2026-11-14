#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
article="$root/src/content/blog/mdxcn-endpoint/index.md"

grep -q '<api-endpoint' "$article"
grep -q '<api-chat' "$article"
grep -q '<chat-frame' "$article"
grep -q '<chat-messages' "$article"
grep -q 'styles/endpoint.css' "$root/src/layouts/Layout.astro"
grep -q 'styles/chat.css' "$root/src/layouts/Layout.astro"
test -f "$root/src/styles/endpoint.css"
test -f "$root/src/styles/chat.css"
grep -q -- '--chat-stage' "$root/src/styles/chat.css"

echo "endpoint component wiring: ok"
