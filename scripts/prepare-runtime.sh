#!/bin/bash
# Downloads the Node.js runtime and installs @deepseek-ai/dsh into
# app/src-tauri/resources/runtime/ so the desktop app can be bundled.
#
# The bundled runtime is exactly what ships inside the .app:
#   resources/runtime/node                 standalone Node.js binary
#   resources/runtime/app/node_modules/    @deepseek-ai/dsh + all dependencies
#
# Env overrides: DSH_NODE_VERSION (default v24.15.0), DSH_PACKAGE (default @deepseek-ai/dsh@0.1.0-rc.6)
#
# Requires: curl, tar, node/npm (build machine only — end users never need this).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$ROOT/app/src-tauri/resources/runtime"
NODE_VERSION="${DSH_NODE_VERSION:-v24.15.0}"
DSH_PACKAGE="${DSH_PACKAGE:-@deepseek-ai/dsh@0.1.0-rc.6}"
ARCH="$(uname -m)"   # arm64 | x86_64

case "$ARCH" in
  arm64)  NODE_ARCH="arm64" ;;
  x86_64) NODE_ARCH="x64" ;;
  *) echo "unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

echo "==> preparing runtime: node $NODE_VERSION ($NODE_ARCH) + $DSH_PACKAGE"

# 已准备好则跳过，避免每次构建都重新下载（FORCE=1 强制重建）
if [[ "${FORCE:-0}" != "1" && -x "$RUNTIME/node" && -d "$RUNTIME/app/node_modules/@deepseek-ai/dsh" ]]; then
  echo "==> runtime 已存在：${RUNTIME}（FORCE=1 可强制重建）"
  "$RUNTIME/node" --version
  exit 0
fi

rm -rf "$RUNTIME"
mkdir -p "$RUNTIME"

echo "==> downloading Node.js $NODE_VERSION ($NODE_ARCH) ..."
TMP="$(mktemp -d)"
curl -fsSL "https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-darwin-$NODE_ARCH.tar.gz" \
  | tar -xz -C "$TMP"
cp "$TMP/node-$NODE_VERSION-darwin-$NODE_ARCH/bin/node" "$RUNTIME/node"
chmod +x "$RUNTIME/node"
rm -rf "$TMP"
"$RUNTIME/node" --version

echo "==> installing $DSH_PACKAGE ..."
mkdir -p "$RUNTIME/app"
cd "$RUNTIME/app"
export NPM_CONFIG_CACHE="$ROOT/.npm-cache"
npm init -y >/dev/null 2>&1
npm install --no-audit --no-fund "$DSH_PACKAGE"

echo "==> done: $(du -sh "$RUNTIME" | cut -f1) runtime at $RUNTIME"
