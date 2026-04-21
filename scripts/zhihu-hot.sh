#!/usr/bin/env bash
# 获取知乎热榜并以 JSON 格式输出
# 用法: zhihu-hot.sh [--limit N]
set -euo pipefail

LIMIT="${1:-50}"
# 去掉可能的 --limit 前缀
if [[ "$LIMIT" == --limit* ]]; then
  LIMIT="${LIMIT#--limit}"
  LIMIT="${LIMIT## }"
fi

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCLI_SCRIPT="$SKILL_DIR/../opencli-skill/scripts/run-opencli.sh"

bash "$OPENCLI_SCRIPT" zhihu hot --limit "$LIMIT" -f json
