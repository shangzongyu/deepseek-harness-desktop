#!/bin/bash
# 依据 git 提交历史自动生成 RELEASE_NOTES.md（发布说明）。
#
# 用法：scripts/release-notes.sh [TAG]
#   TAG 缺省时取 HEAD 可达的最新 tag；首次发布请显式传入，如 v0.1.0。
#
# 变更范围 = 自上一个发布 tag 以来到 HEAD 的全部提交（无 tag 时为全部提交）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TAG="${1:-$(git describe --tags --abbrev=0 HEAD 2>/dev/null || echo v0.1.0)}"
DATE="$(date +%Y-%m-%d)"
APP_NAME="DeepSeek Harness"
OUT="RELEASE_NOTES.md"

# 前一个发布 tag：HEAD 可达的最新 tag；若与本次相同（重复发布）则再往前找
PREV="$(git describe --tags --abbrev=0 HEAD 2>/dev/null || true)"
if [[ "$PREV" == "$TAG" ]]; then
  PREV="$(git describe --tags --abbrev=0 "${TAG}^" 2>/dev/null || true)"
fi

if [[ -n "$PREV" ]]; then
  RANGE="$PREV..HEAD"
  HEADER="## 自 $PREV 以来的变更"
else
  RANGE="HEAD"
  HEADER="## 首次发布"
fi

COMMITS="$(git log --oneline --no-merges --format='- %s' "$RANGE" 2>/dev/null || true)"
[[ -n "$COMMITS" ]] || COMMITS="- （无提交记录）"

DMG="dist/$APP_NAME.dmg"
ZIP="dist/DeepSeek-Harness-macos-arm64.zip"
SUMS="dist/SHA256SUMS"

fmt_size() {
  if [[ -f "$1" ]]; then du -h "$1" | cut -f1; else echo "未生成"; fi
}

{
  echo "# $TAG"
  echo
  echo "> 构建日期：$DATE · 平台：macOS 14+（Apple Silicon）· 无需安装 Node"
  echo
  echo "$HEADER"
  echo
  echo "$COMMITS"
  echo
  echo "## 下载"
  echo
  echo "| 文件 | 大小 | 说明 |"
  echo "|---|---|---|"
  echo "| \`$APP_NAME.dmg\` | $(fmt_size "$DMG") | 安装镜像（挂载后拖入 Applications） |"
  echo "| \`DeepSeek-Harness-macos-arm64.zip\` | $(fmt_size "$ZIP") | 免安装压缩包（解压即用） |"
  echo
  echo "## 校验和"
  echo
  echo '```'
  if [[ -f "$SUMS" ]]; then cat "$SUMS"; else echo "（运行 make zip 生成 SHA256SUMS）"; fi
  echo '```'
  echo
  echo "> 未做 Apple 公证；若被 Gatekeeper 拦截请右键 → 打开。"
} > "$OUT"

echo "==> 已生成 $OUT"
head -12 "$OUT"
