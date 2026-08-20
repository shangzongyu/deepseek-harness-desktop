#!/bin/bash
# Downloads the Node.js runtime and installs @deepseek-ai/dsh into
# app/src-tauri/resources/runtime/ so the desktop app can be bundled.
#
# The bundled runtime is exactly what ships inside the .app:
#   resources/runtime/node                 standalone Node.js binary
#   resources/runtime/app/node_modules/    @deepseek-ai/dsh + all dependencies
#
# Env overrides: DSH_NODE_VERSION (default v24.15.0), DSH_PACKAGE (default @deepseek-ai/dsh = latest;
#   pin a version with e.g. DSH_PACKAGE=@deepseek-ai/dsh@0.1.0-rc.6)
#
# Requires: curl, tar, node/npm (build machine only — end users never need this).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$ROOT/app/src-tauri/resources/runtime"
NODE_VERSION="${DSH_NODE_VERSION:-v24.15.0}"
DSH_PACKAGE="${DSH_PACKAGE:-@deepseek-ai/dsh}"
ARCH="$(uname -m)"   # arm64 | x86_64

case "$ARCH" in
  arm64)  NODE_ARCH="arm64" ;;
  x86_64) NODE_ARCH="x64" ;;
  *) echo "unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

echo "==> preparing runtime: node $NODE_VERSION ($NODE_ARCH) + $DSH_PACKAGE (latest)"

# --- deepseek-harness GitHub 状态一览（每次运行都展示；网络失败仅警告，不阻塞构建） ---
GH_REPO="https://github.com/deepseek-ai/deepseek-harness.git"
echo "==> deepseek-harness GitHub 状态: $GH_REPO"
if TAGS="$(git ls-remote --tags --refs "$GH_REPO" 2>/dev/null)"; then
  echo "--- 全部 tags（版本从新到旧） ---"
  echo "$TAGS" | sed 's|.*refs/tags/||' | sort -Vr
else
  echo "==> 警告: 无法访问 GitHub，跳过 tags / 最新提交展示"
fi
if HEAD="$(git ls-remote "$GH_REPO" refs/heads/master 2>/dev/null)"; then
  echo "--- 最新提交 (master) ---"
  echo "$HEAD" | awk '{print "  " $1 "  master"}'
fi

mkdir -p "$RUNTIME"

# Node.js 运行时：已存在则跳过（大文件且版本固定；FORCE=1 强制重新下载）
if [[ "${FORCE:-0}" != "1" && -x "$RUNTIME/node" ]]; then
  echo "==> node 已存在：跳过下载（FORCE=1 可强制重下）"
else
  echo "==> downloading Node.js $NODE_VERSION ($NODE_ARCH) ..."
  TMP="$(mktemp -d)"
  curl -fsSL "https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-darwin-$NODE_ARCH.tar.gz" \
    | tar -xz -C "$TMP"
  cp "$TMP/node-$NODE_VERSION-darwin-$NODE_ARCH/bin/node" "$RUNTIME/node"
  chmod +x "$RUNTIME/node"
  rm -rf "$TMP"
fi
"$RUNTIME/node" --version

# @deepseek-ai/dsh：每次都重新安装，保证拿到最新版本
echo "==> installing latest $DSH_PACKAGE ..."
rm -rf "$RUNTIME/app"
mkdir -p "$RUNTIME/app"
cd "$RUNTIME/app"
export NPM_CONFIG_CACHE="$ROOT/.npm-cache"
npm init -y >/dev/null 2>&1
npm install --no-audit --no-fund "$DSH_PACKAGE"

echo "==> done: $(du -sh "$RUNTIME" | cut -f1) runtime at $RUNTIME"
