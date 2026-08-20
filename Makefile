# DeepSeek Harness Desktop — 打包 / 发布工作流
#
# 常用命令：
#   make                     构建并打包 .app 与 .dmg
#   make zip                 追加生成 .zip 与 SHA256SUMS
#   make notes TAG=v0.2.0    依据 git 历史自动生成 RELEASE_NOTES.md
#   make release TAG=v0.2.0  全流程：构建 → 打包 → Notes → 发布 GitHub Release
#   make clean               清理构建产物
#   make help                查看全部目标
SHELL := /bin/bash

ROOT    := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
APP     := DeepSeek Harness
DIST    := $(ROOT)/dist
TAG     ?=

.PHONY: all prepare build bundle zip checksums notes release publish clean help

all: bundle

prepare: ## 准备捆绑运行时（Node + @deepseek-ai/dsh；dsh 每次取最新，FORCE=1 连 Node 一起重下）
	@$(ROOT)/scripts/prepare-runtime.sh

build: prepare ## 编译 release 二进制
	@cd $(ROOT)/app/src-tauri && cargo build --release

bundle: build ## 打包 .app 与 .dmg（ad-hoc 签名）
	@$(ROOT)/scripts/bundle-app.sh --dmg

zip: bundle ## 生成 .app 压缩包与 SHA256SUMS
	@cd "$(DIST)" && ditto -c -k --sequesterRsrc --keepParent "$(APP).app" "DeepSeek-Harness-macos-arm64.zip"
	@cd "$(DIST)" && shasum -a 256 "$(APP).dmg" "DeepSeek-Harness-macos-arm64.zip" > SHA256SUMS
	@ls -lh "$(DIST)"

checksums: zip ## zip 的别名（生成全部产物）

notes: ## 依据 git 历史生成 Release Notes（TAG=vX.Y.Z，缺省取最近 tag）
	@$(ROOT)/scripts/release-notes.sh "$(TAG)"

release: zip notes ## 全流程：构建 → 打包 → Notes → 发布 GitHub Release（TAG=vX.Y.Z，必填）
	@$(ROOT)/scripts/publish.sh "$(TAG)"

publish: ## 仅发布现有 dist/ 产物（不重新构建；TAG=vX.Y.Z，必填）
	@$(ROOT)/scripts/publish.sh "$(TAG)"

clean: ## 清理构建产物
	rm -rf "$(DIST)" "$(ROOT)/RELEASE_NOTES.md" "$(ROOT)/app/src-tauri/target" "$(ROOT)/app/src-tauri/resources/runtime"

help: ## 显示所有目标
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
