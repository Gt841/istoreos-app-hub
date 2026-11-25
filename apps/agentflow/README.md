# AgentFlow 与共享运行时

AgentFlow 使用 `mise-runtime` 提供的固定 GNU Node/npm 和私有 glibc。AgentFlow 自身是预编译程序；代理包、运行时绑定和安装记录由本插件管理，不在共享 SDK 内安装 npm 包，也不执行 `mise use --global` 或 `mise reshim`。

## 配置

1. 在“运行时环境”选择持久目录，默认 `/mnt/<硬盘>/Configs/Runtime`。不要选择系统 `/root`。
2. 在 AgentFlow 选择数据目录，例如 `/mnt/<硬盘>/Configs/AgentFlow`。应用数据和共享 Runtime 不得互相包含。
3. 在 AgentFlow 页面安装所需代理。尚未安装对应 SDK 时，任务通过公共 runtime 的 plan/submit 流程准备固定环境；已有环境直接复用。

AgentFlow 的启动环境显式设置 HOME：优先保留旧 `mise.main.runtime_dir`，否则使用 `<storage_root>/home`。XDG 目录随 HOME 设置。服务 PATH 优先使用应用自己的 `.runtime/bin`，代理未安装时对应命令链接不可执行，不会误报为可用。

状态查询不会下载 SDK。只要持久 HOME 可用，AgentFlow 的 Go 后端独立启动；procd 另起一次性准备进程，为已安装代理确保固定 SDK，并更新各 active release 的绑定。准备失败不会隐藏 Web UI，重启服务可重试。

## 固定版本与目录

当前应用策略为 Node **24.22.1**、npm **11.19.1**、GNU/glibc **2.39 r1**，与 OpenClaw 使用相同的共享实例。不是跟随 `node@lts` 或全局默认。

| 代理 | npm 包 | 固定版本 |
| --- | --- | --- |
| Codex | `@openai/codex` | 0.153.4 |
| Claude Code | `@anthropic-ai/claude-code` | 2.1.331 |
| OpenCode | `opencode-ai` | 1.19.6 |
| Kimi | `@moonshot-ai/kimi-code` | 2.7.3 |
| Reasonix | `reasonix` | 2.61.0 |

这些是经过本轮命令启动验证的版本，不宣称为最新版本。后续升级需要更新策略、重新验证并发布插件。

```text
<AgentFlow 数据目录>/
  data/                              AgentFlow 自身的数据
  .runtime/
    runtime.json                     固定 SDK、库与收据摘要
    bin/                             node/npm/npx/git 和已安装代理的入口
    npm/                             应用内其他 npm 操作的默认 prefix
    agents/<id>/releases/<事务>/      各代理独立的包、启动器及验证记录
    agents/<id>/current              原子切换到已验证版本
    work/                            小型任务脚本和查询输出
```

代理 npm 安装经固定 SDK wrap 调用 ks-cli，遵循运行时的加速设置。安装器不硬编码 `--registry` 覆盖 ks-cli 的网关，不关闭 npm 完整性校验。本地程序运行和版本探测不要求加速服务可用。

GNU 原生程序使用当前绑定私有 glibc 的 loader，不向系统导出全局 `LD_LIBRARY_PATH`。应用安装目录内的 GNU ELF 保存为 `.agentflow-real` 并生成私有 loader 入口；静态/musl 程序和 `.node` 库不改写。OpenCode 的上游 postinstall 会根据宿主 `ldd` 错选 musl，因此本插件明确选择已经安装的 GNU optional package；x86_64 优先使用 baseline CPU 构建。

安装在新的独立 release 中进行。只有真实 `--version` 成功并匹配包版本才发布；失败不会覆盖当前可用版本。中断安装可通过页面“恢复中断安装”处理，或者：

```sh
/usr/libexec/agentflow-runtime recover /mnt/data/Configs/AgentFlow
```

恢复会核对 PID/start/boot 身份，拒绝操作仍在运行的任务，只恢复本应用创建的共享安装任务，保留现有版本和失败现场。未知锁需要人工检查。

旧的全局 npm/mise 代理目录、配置和凭据不会自动搬迁或删除。升级后请通过此页面重新安装需要的代理到应用目录；旧全局 shim 不作为固定 runtime 的回退入口。

## 本轮人工编译版本

| 包 | 版本 |
| --- | --- |
| mise | 2026.8.14-r28 |
| mise-runtime / luci-app-mise / app-meta-mise | 0.1.1-r1 |
| luci-app-openclawmgr / app-meta-openclawmgr | 0.1.13-r1 |
| agentflow | 0.3.5-r4 |
| luci-app-agentflow | 1.0.1-r6 |
| app-meta-agentflow | 0.3.5-r5 |

先编译并安装 mise/runtime，再安装 AgentFlow 相关包。运行包声明最低 runtime 依赖，兼顾 IPK/APK 的 release 格式；元包不增加最低版本约束。

AgentFlow 二进制固定到官方 `build/version.json` 中的 `0.3.5-20261019-101caed9` 构建，x86_64 和 ARM64 摘要已同步。固定下载名包含摘要；若上游再次覆盖 build URL，校验会失败，需要重新核对正式构建，不能禁用校验。

本轮没有编译 IPK/APK。x86_64 直接文件测试、五个代理命令、回滚/恢复和 AgentFlow 健康检查见 [验证记录](../../docs/evidence/agentflow-shared-runtime-20261125/verification.md)。代理模型调用、ARM64 实机及最终软件包安装仍需后续验收。

## 切换运行时仓库

运行时页面切换 storage_root 只保留旧仓库，不复制环境或 HOME。重启 AgentFlow 后，后台准备进程在当前仓库按原准确版本安装或校验 SDK/glibc，再更新顶层和各代理 release 的绑定。旧绑定不能静默执行旧仓库；准备失败保留原绑定并显示原因。代理 npm 包和 AgentFlow 数据库保留在应用目录。默认 HOME 跟随仓库；旧 HOME 的登录信息不复制，可能需要重新登录。明确设置的兼容 runtime_dir 保持不变。

运行库损坏可在运行时页面“检查 / 修复”，无需删除 SDK。相关验收见 `docs/evidence/runtime-switch-20261125`。
