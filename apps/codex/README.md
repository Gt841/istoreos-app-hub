# Codex for iStoreOS

应用只通过 `linkease_apps/open?id=codex` 打开。ttyd 的回环端口是内部参数，
由共享网关代理页面和 WebSocket；网关不可用时不再生成私有端口直连地址。
LuCI 不提供端口设置，管理员仍可通过现有配置处理内部端口冲突。
本次保留专用用户、固定版本、登录凭据、工作区和代理安装流程。

Codex 是第一个独立编码代理试点。`codex` 运行包拥有固定的 Codex npm 发布、专用用户、持久数据、浏览器终端服务、应用注册和代理发现清单；`mise-runtime` 只拥有固定 Node/npm SDK。

## 软件包

- `codex`：固定安装 `@openai/codex@0.172.0`，通过 mise-runtime 的 musl Node 24.22.1/npm 11.19.1 安装和启动；安装版本不会跟随 npm `latest` 漂移。
- `luci-app-codex`：单页设置、状态、taskd 安装日志，以及经过认证的终端和 AgentFlow 可选入口。
- `app-meta-codex`：iStore 元数据、图标和产品依赖。

## 安全边界

- Codex 与浏览器终端以专用 `codex` UID 运行，普通 root 入口会通过 mise-runtime 的结构化 `exec-user` 降权。只有 AgentFlow 服务设置受控的 `AGENTFLOW_PROVIDER_MODE=1` 时，命令才继承 AgentFlow 身份、HOME 和工作目录。
- `CODEX_HOME` 为 `<data_dir>/home/.codex`，认证文件不会由 LuCI 读取或返回。
- ttyd 只监听 `127.0.0.1`，`/apps/codex/` 由 `linkease-app-entry` 强制验证 iStoreOS 会话后代理；清单不得使用 `passthrough`。
- 默认工作区为 `<data_dir>/workspace`。外部工作区必须位于 `/mnt` 且归专用 `codex` 用户所有。
- npm 安装固定确切版本并禁用 lifecycle scripts；发布切换使用不可变 release 和原子 `current` 链接。

无头设备按 OpenAI 官方文档在终端运行 `codex login --device-auth`。也可以使用 API key 登录，但密钥应通过终端 stdin 交给 Codex，不保存到 UCI 或 LuCI 表单。

AgentFlow 从系统 PATH 发现 `/usr/bin/codex`，并通过 `/usr/share/coding-agents.d/codex.json` 的轻量状态命令和管理入口识别该提供方。
