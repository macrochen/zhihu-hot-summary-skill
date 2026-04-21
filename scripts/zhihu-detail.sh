#!/usr/bin/env bash
# 获取知乎热榜详细内容（给定 URL）
# 用法: zhihu-detail.sh <url>
set -euo pipefail

URL="${1:?需要提供知乎链接}"

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCLI_SCRIPT="$SKILL_DIR/../opencli-skill/scripts/run-opencli.sh"

bash "$OPENCLI_SCRIPT" zhihu detail "$URL" -f json
