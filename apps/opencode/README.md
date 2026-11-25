# OpenCode for iStoreOS

OpenCode 是独立编码代理插件。`opencode` 运行包拥有固定发布、专用用户、持久数据、浏览器终端服务、应用注册和代理发现清单；`mise-runtime` 只负责安装阶段所需的固定 Node/npm SDK。

## 软件包

- `opencode`：固定安装 `@opencode/cli@2.4.1` 及对应 musl 原生包；x86_64 使用兼容性更高的 baseline 构建。
- `luci-app-opencode`：单页设置、状态、taskd 安装日志，以及经过认证的终端和 AgentFlow 可选入口。
- `app-meta-opencode`：iStore 元数据、图标和产品依赖。

## 安全边界

- OpenCode 与浏览器终端以专用 `opencode` UID 运行，root 入口会通过 `su` 清除附加组后降权。
- OpenCode 使用专用 HOME 及 XDG 目录，认证文件不会由 LuCI 读取或返回。
- ttyd 只监听 `127.0.0.1`，`/apps/opencode/` 由 `linkease-app-entry` 强制验证 iStoreOS 会话后代理；清单不得使用 `passthrough`。
- 默认工作区为 `<data_dir>/workspace`。外部工作区必须位于 `/mnt` 且归专用 `opencode` 用户所有。
- npm 安装固定确切版本并禁用 lifecycle scripts；发布切换使用不可变 release 和原子 `current` 链接。

无头设备按 OpenCode 官方文档在终端运行 `opencode auth login`。也可以使用 API key 登录，但密钥应通过终端 stdin 交给 OpenCode，不保存到 UCI 或 LuCI 表单。

AgentFlow 可从系统 PATH 发现 `/usr/bin/opencode`；独立插件同时发布 `/usr/share/coding-agents.d/opencode.json`，供后续统一代理适配器使用。
