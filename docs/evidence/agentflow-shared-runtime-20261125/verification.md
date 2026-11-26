# AgentFlow 共享运行时接入（2026-11-25）

目标：增加人工编译所需版本号，将 AgentFlow 的代理安装、启动和检测切换至当前 `mise-runtime`，保留持久 HOME 与 ks-cli 加速，不切换全局 Node。

## 实施范围

1. **版本及依赖**：Runtime 0.1.1-r1、mise 2026.8.14-r28、OpenClaw 管理插件 0.1.13-r1；AgentFlow 0.3.5-r4、LuCI 1.0.1-r6、meta 0.3.5-r5。运行包增加必要的最低 runtime 依赖，meta 不增加版本约束。[版本检查](checks.json)。
2. **固定应用环境**：复用 GNU Node 24.22.1/npm 11.19.1 和私有 glibc 2.39 r1；应用持有 SDK/库/收据摘要绑定。HOME 显式采用已有 `runtime_dir`，否则 `<storage_root>/home`，支持 mode-700 私有 HOME。应用包安装在 AgentFlow 自身 `.runtime/agents`，不写共享 SDK 或全局 mise 配置。
3. **本地安装事务**：移除远程 `installapp-mise.sh`、`node@lts` 及全局 shim 查找；白名单代理走本地 taskd 脚本和共享 wrap。每个代理独立 release，版本命令验证通过后原子发布。命令链接跟随已验证 current，未安装时不可执行。失败保留原版本，中断恢复检查 PID/start/boot 并仅处理应用拥有的任务。
4. **GNU 原生程序**：应用包内的 GNU ELF 使用固定私有 loader，静态/musl 程序及 `.node` 库保持原样。OpenCode 的 host-ldd 检测会错选 musl，适配器改为明确采用已安装 GNU optional package；x86_64 优先 baseline CPU 构建。
5. **管理交互**：页面显示实际 Node/npm/glibc/HOME 及共享运行时入口，提供中断恢复。安装及恢复要求 POST、CSRF 和写权限；保留既有桌面/open 入口。删除 AgentFlow 设置页对共享 mise UCI 的隐式写入。

## 发现与修正

- `/mnt` 为 root-owned sticky 目录（1777），校验允许安全的 sticky 父目录，应用目录自身仍要求受保护。
- 显式 `--registry` 会覆盖 ks-cli 注入的网关地址，安装器不再硬编码该参数。首个旧参数测试下载被按 PID/start/session 身份停止，失败现场保留，随后使用修正代码成功安装。
- taskd/交互启动的 Lua 进程不一定是 session leader，安装锁使用 PID/start/boot 判断存活，不能套用只适合独立命令 session 的判断。
- HOME 是私有用户目录，不应使用要求全部父目录允许其他用户遍历的共享 SDK 校验；已验证 mode-700 HOME。
- 原 AgentFlow 下载摘要与公开 build URL 的当前文件不符。按 [官方构建记录](official-build.json) 固定至 `0.3.5-20261019-101caed9`，同步两个 Linux 架构摘要。x86_64 实际下载摘要与官方清单一致；没有忽略完整性检查，也没有修改上游业务版本号。

## 验收

- [本地 runtime/controller 测试](runtime-unit.log)：13/13；[LuCI 兼容契约](luci-contract.log)：7/7。包含 CSRF、只读权限、白名单、忙任务、任务脚本碰撞、恢复入口、GNU/musl/static ELF、非 session-leader 锁及 OpenCode baseline 适配。
- Lua、shell、页面 JS 语法与 gettext 检查通过。gettext 仅报告原有 PO 头字段缺失警告。[检查汇总](checks.json)。
- [真实代理状态](agent-status.json)：Codex 0.153.4、Claude Code 2.1.331、OpenCode 1.19.6、Kimi 2.7.3、Reasonix 2.61.0 全部真实安装并通过各自 `--version`，不是只检测 package.json 或文件存在。
- [实机运行及回滚](runtime-device.json)：11/11。包括实际 Node/npm HOME/prefix、五个代理命令、故意阻断 ks-cli 后保持 current、不恢复活跃锁/恢复陈旧锁、拒绝 SDK 内应用目录、UCI 及共享 SDK 收据不变。无代理的命令链接不可执行；mode-700 HOME 可用。
- [加速验证](acceleration.json)：五个代理包的实际新鲜元数据请求均经本机 `dl-npm.linkease.net:5443`；ks-cli 策略为 accelerated_network。保留已安装包缓存，没有为了测试清空缓存，未关闭 npm 完整性检查。
- [AgentFlow 健康检查](service-device.json)：从真实 init 脚本捕获 HOME/PATH/XDG 环境，以固定摘要的真实二进制和隔离数据库启动；`/healthz` 通过。测试服务已停止。该项不宣称软件包安装或全局 procd 自启已验收。
- [最终直接文件部署](deployment-audit.json) 与 [设备文件审计](source-audit.json)：57 个非配置文件字节/权限一致，1 个已有配置保留。没有修改包数据库、启用正式 AgentFlow 服务或构建 IPK/APK。

仅操作 x86_64 `192.168.30.7`。测试代理、日志及临时数据库位于任务专用 `/mnt/mise-runtime/acceptance/agentflow-runtime-20261125`；系统 `/etc/config/agentflow` 保持 disabled/空数据目录的原始默认值。没有迁移或删除旧代理、修改 OpenClaw 数据/绑定，也未操作 ARM 服务。

## 人工编译后的项目

先安装新 mise/runtime，再安装 AgentFlow 相关包。旧全局代理需要通过新入口安装到应用目录，旧数据不会自动搬迁。正式 IPK/APK 的依赖/归属/升级钩子、ARM64 实机、模型推理及既有账号配置使用仍待后续验收；本轮没有模型或 API key，不据版本探测宣称推理完成。

完整用法及版本表见 [AgentFlow README](../../../apps/agentflow/README.md)。敏感会话、完整环境、服务私有日志及二进制不进入证据。
