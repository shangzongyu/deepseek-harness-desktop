# DeepSeek Harness Desktop (macOS)

把 [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)
用 [tw93/pake](https://github.com/tw93/pake)（Tauri v2 壳）打包成 macOS 桌面应用：
应用启动时自动拉起**内置**的 Node.js 运行时 + `@deepseek-ai/dsh` 服务端，并把窗口指到
服务端动态分配的本地端口。**用户机器上无需安装 Node / Python / Rust**，下载即用。

## 下载

到 [Releases](../../releases) 页面下载：

| 文件 | 说明 |
|---|---|
| `DeepSeek Harness.dmg` | 安装镜像：挂载后把 App 拖进 Applications |
| `DeepSeek-Harness-macos-arm64.zip` | App 压缩包：解压即用 |

> 未做 Apple 公证（无需开发者账号）。本机构建的版本可直接双击打开；
> 从网上下载的副本若被 Gatekeeper 拦截，右键 → 打开即可（或
> `xattr -dr com.apple.quarantine "DeepSeek Harness.app"`）。

## 使用

双击打开后即出现 DSH 界面。用户数据沿用 CLI 的 `~/.dsh`（`DSH_HOME`）：
已配置的模型凭据、设置、会话记录自动生效；全新环境首次打开在界面设置里填写
模型 API Key 即可。服务端使用随机空闲端口（`--port 0`），不会和浏览器里
已运行的 `dsh web`（默认 3080）冲突。退出 App（关窗或 Cmd+Q）会自动回收服务端进程。

## 工作原理

```
DeepSeek Harness.app/
└── Contents/
    ├── MacOS/pake                  # Tauri 壳（WKWebView）
    ├── Info.plist
    └── Resources/
        ├── icon.icns
        └── runtime/                # 自包含运行时
            ├── node                # Node.js v24.15.0 (darwin-arm64)
            └── app/node_modules/   # @deepseek-ai/dsh 及其全部依赖
```

1. 启动 → Rust 侧 `app/src-tauri/src/app/sidecar.rs` 用绝对路径执行
   `runtime/node .../dsh/lib/bin.js web --port 0`。
2. 从子进程 stdout 解析 `dsh web: http://127.0.0.1:<port>`，等待端口就绪后创建窗口。
3. 退出（关窗 / Cmd+Q / SIGTERM）→ 杀掉服务端子进程，不留孤儿进程。

## 从源码构建

前置（仅构建机需要）：Rust（≥1.85）、Xcode Command Line Tools、Node.js（≥20）。

```sh
# 1. 准备捆绑运行时（下载 Node + 安装 @deepseek-ai/dsh，约 350MB）
./scripts/prepare-runtime.sh

# 2. 编译 release 二进制（首次拉取全部 crates，约 15 分钟）
cd app/src-tauri && cargo build --release && cd ..

# 3. 打包 .app（ad-hoc 签名）与 .dmg
./scripts/bundle-app.sh --dmg

# 产物在 dist/
```

## 发布（GitHub Releases）

打 tag 即触发 CI（`.github/workflows/release.yml`）在 macOS arm64 运行器上
构建并自动上传 `.dmg` 与 `.zip` 到 Release：

```sh
git tag v0.1.0
git push origin v0.1.0
```

也可以本地构建后手动发布：

```sh
gh release create v0.1.0 "dist/DeepSeek Harness.dmg" dist/DeepSeek-Harness-macos-arm64.zip --title "v0.1.0" --notes "…"
```

## 仓库结构

```
├── app/                        # Tauri 桌面工程（pake 模板 + 定制）
│   ├── dist/                   # frontendDist 占位
│   └── src-tauri/
│       ├── src/app/sidecar.rs  # ★ 新增：启动内置服务端并等待 URL
│       ├── src/lib.rs          # ★ 修改：setup 注入 sidecar、退出清理
│       ├── pake.json           # 窗口配置（URL 运行时动态注入）
│       ├── tauri.conf.json     # 应用/bundle 配置
│       └── resources/runtime/  # 构建时由 prepare-runtime.sh 生成（不入库）
├── scripts/
│   ├── prepare-runtime.sh      # 组装捆绑运行时
│   ├── bundle-app.sh           # 打包 .app/.dmg（ad-hoc 签名）
│   ├── test-app.sh             # 端到端冒烟测试
│   └── make-icon.js            # 由 favicon.svg 生成应用图标
├── app-icon/                   # 图标源文件（favicon.svg）
├── .github/workflows/release.yml
└── THIRD_PARTY_NOTICES.md      # 三方组件与许可证
```

## License

本项目修改了 pake 的 GPL 模板源码，故仓库以 [GPL-3.0](LICENSE) 发布；
**打包产物**受 pake 的 [Pake Output Exception](https://github.com/tw93/pake/blob/main/LICENSE-EXCEPTION)
约束，可按自选条款分发。deepseek-harness 与 Node.js 均为 MIT，详见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
