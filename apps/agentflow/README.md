# AgentFlow for iStoreOS

AgentFlow 是项目与开发流程编排应用。它负责项目、任务、Git 工作区、日志、
it-runner 和远端节点控制，不负责下载或升级 Codex、Claude Code、OpenCode、
Kimi 等编码工具。

## 产品边界

- `agentflow` 安装预编译 Web 后端，并通过 `/apps/agentflow/` 的同源入口访问。
- Codex、Claude Code、OpenCode、Kimi 由各自独立插件安装、升级和管理运行时。
- 独立插件把提供方描述发布到 `/usr/share/coding-agents.d/*.json`，AgentFlow
  管理页只读取状态并跳转到对应插件，不执行安装。
- AgentFlow 从系统 `PATH` 调用已经安装的 CLI。启动环境不包含旧的
  `<data_dir>/.runtime/bin`，因此旧私有版本不会遮蔽独立插件。
- AgentFlow 不直接依赖 `mise-runtime`；需要 Node 或原生运行环境的 CLI 插件
  自己声明该依赖。

## 存储与访问

Web 后端固定监听 `127.0.0.1`。配置中的端口仅用于内部同源代理，不应直接暴露
到局域网。AgentFlow 保留自己的登录体系，因此应用清单使用 passthrough 认证模式。

默认目录：

```text
<AgentFlow 数据目录>/
  data/       AgentFlow 数据库、项目和任务数据
  home/       AgentFlow 的 HOME、Git/SSH 与编码工具登录状态
  .runtime/   旧版本遗留目录；新版本不读取，也不自动删除
```

新安装默认使用 `<data_dir>/home`。升级时，如果检测到旧 `.runtime`，安装脚本会把
原来的 mise runtime HOME 写入 `agentflow.@agentflow[0].home_dir`，避免静默移动凭据。
用户确认不再需要旧 CLI release 后，可以自行备份并清理 `.runtime`；升级不会自动删除。

AgentFlow 服务设置 `AGENTFLOW_PROVIDER_MODE=1`。独立 CLI 包装器仅在 AgentFlow
以 root 编排任务时继承当前工作目录和 AgentFlow HOME；浏览器终端和普通调用仍使用
各插件的低权限专用账号。这避免修改任意 Git 仓库的所有权或权限。

## 提供方接口

提供方描述至少包含：

```json
{
  "schemaVersion": 1,
  "id": "codex",
  "kind": "cli",
  "command": "/usr/bin/codex",
  "statusCommand": ["/usr/libexec/codex-runtime", "provider-status"],
  "manageUrl": "/cgi-bin/luci/admin/services/codex"
}
```

AgentFlow LuCI 只接受受限的绝对命令路径，并只调用轻量的 `provider-status`；该查询
不探测登录状态或访问模型服务。提供方安装、认证、
版本固定、回滚和终端均属于独立插件实现。

## 发布与测试

AgentFlow 二进制固定到官方发布目录中的 `0.3.5-20261123-bbd3dcf5` 构建，x86_64
和 ARM64 摘要按该目录 2026-11-25 发布的 `SHA256SUMS` 校验。上游曾在同版本目录
更新文件，因此旧摘要必须失败关闭，不能跳过校验。源码测试不需要编译 IPK；测试机可直接复制脚本、LuCI
文件和官方二进制进行验收。
