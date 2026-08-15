#!/bin/bash
# 把 dist/ 产物发布为 GitHub Release，自动附带 RELEASE_NOTES.md。
#
# 用法：scripts/publish.sh <tag>   （或 make release TAG=vX.Y.Z）
# 前置：git 工作区干净、dist/ 下已有 .dmg/.zip/SHA256SUMS、已生成 RELEASE_NOTES.md。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "usage: $0 <tag>   (e.g. make release TAG=v0.2.0)" >&2
  exit 1
fi
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]] || {
  echo "error: tag 格式应为 vX.Y.Z，当前：$TAG" >&2
  exit 1
}

APP_NAME="DeepSeek Harness"
DMG="dist/$APP_NAME.dmg"
ZIP="dist/DeepSeek-Harness-macos-arm64.zip"
SUMS="dist/SHA256SUMS"
NOTES="RELEASE_NOTES.md"

for f in "$DMG" "$ZIP" "$SUMS" "$NOTES"; do
  [[ -f "$f" ]] || { echo "error: 缺少 $f（先运行 make zip / make notes）" >&2; exit 1; }
done

# 发布纪律：源码必须先提交，否则 tag 不会包含未提交的改动
if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: 工作区有未提交的改动，请先 git commit" >&2
  exit 1
fi

REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

# 确保 tag 存在并已推送
if ! git rev-parse --verify "$TAG" >/dev/null 2>&1; then
  echo "==> 创建并推送 tag $TAG"
  git tag -a "$TAG" -m "release $TAG"
  git push origin "$TAG"
fi

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "==> Release $TAG 已存在：更新 Notes 与产物"
  gh release edit "$TAG" --title "$TAG" --notes-file "$NOTES"
  gh release upload "$TAG" "$DMG" "$ZIP" "$SUMS" --clobber
else
  echo "==> 创建 Release $TAG"
  gh release create "$TAG" "$DMG" "$ZIP" "$SUMS" --title "$TAG" --notes-file "$NOTES"
fi

echo "==> 已发布：https://github.com/$REPO/releases/tag/$TAG"
