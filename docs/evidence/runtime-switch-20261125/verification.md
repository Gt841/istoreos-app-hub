# 仓库切换、依赖恢复与应用启动验收

日期：2026-11-25。目标与任务树：[runtime-repository-switch.md](../../plans/runtime-repository-switch.md)。

## 交付

- settings 不再按已安装环境数量锁定目录；验证目标磁盘/仓库后切换，旧文件保留；保护活动事务、支持旧盘离线和已有仓库复用。
- 界面提供切换确认、重启/HOME/旧绝对路径提示、公共库检查/修复及后台进度；设计预览同步仓库切换语义。
- 公共 ensure 接口复用活动任务，按准确目录项与库修订安装/验证；保留 SDK 安装的空间预算。库修复在候选中进行，提交失败或取消恢复原目录。
- OpenClaw root 准备入口在 procd 子进程执行；绑定验证后原子更新，随后经 exec-user 清空附加组并降为专用 UID。Gateway 启动继续要求真实 sqlite-vec 查询。相同启动 generation 的失败不重复提交下载；显式重启可重试。
- AgentFlow Go 后端与一次性代理准备进程分开；更新顶层和各 active agent release 的固定绑定，保留数据库与代理包。
- 配置保持 600，公开路由文件只有仓库路径；非 root 入口不会读取私有 UCI。

## 三轮主场景

| 轮次 | 结果 | 处理 |
| --- | --- | --- |
| 初次检查 | 9 项通过，库丢失场景测试脚本跨文件系统 rename 返回 EXDEV | 测试备份改为保留同盘；非产品故障。设备配置与应用绑定恢复。 |
| 修正后复验 | 12 项通过，Gateway 健康失败 | 发现非 root 无法读取 600 的 UCI，新增只包含当前仓库路径的 root-owned 公开元数据。 |
| 再次复验 | 14/14 通过 | 空仓库按需安装、并发任务复用、跨盘切换/切回、旧 SDK 保留、glibc 缺失/损坏恢复、失败/取消回滚、五代理绑定、非 root Gateway/sqlite-vec 均通过。 |

主场景详细结果：[round-1.json](round-1.json)、[round-2.json](round-2.json)、[round-3.json](round-3.json)。测试结束逐字恢复 `/etc/config/mise`，还原 AgentFlow 各绑定。旧仓库是 `/mnt/mise-runtime/Runtime-live`；未强制迁移到新默认目录。

## 最终源文件复验

- [final-smoke.json](final-smoke.json)：5/5；私有 UCI、公开元数据、失败 generation 防重复、五代理、fresh npm 元数据实际经 `dl-npm.linkease.net:5443`、Gateway 与 sqlite-vec。测试 Gateway 使用独立应用数据和端口，进程已停止。
- [agentflow-runtime.json](agentflow-runtime.json)：11/11；实际五代理命令、HOME/prefix、失败安装保留 current、活跃与过期锁的恢复、目录边界及系统配置/SDK 收据不变。
- [adapter-matrix.json](adapter-matrix.json)：5/5；公共 ensure 实际执行已安装的 GNU Node、GNU/musl Python、Go 和 Zig，收据保持不变。设备仓库没有 musl Node 实例，此项明确跳过，没有算作设备执行通过。
- [agentflow-service.json](agentflow-service.json)：真实 init 环境捕获，SHA256 固定的官方 Go 二进制使用隔离 DB 通过健康检查，进程已停止。没有安装正式 `/usr/sbin/agentflow`、启用全局服务或声称已验收正式包的自启动。
- [browser/browser.json](browser/browser.json)：7/7；真实 LuCI/Argon 资源，覆盖确认/取消、空仓库、修复进度、维护锁、离线旧盘、手机布局与只读拒绝。写入在浏览器拦截；真实目录切换由主设备场景测试，真实只读修复请求返回 403。
- [source-audit.json](source-audit.json)：92 个程序/前端文件内容与模式通过，2 个设备配置文件保留。最终部署清单为 [deployment-ui-final.json](deployment-ui-final.json)。没有编译或安装 IPK/APK，未修改包数据库。

本地：公共契约 52 项、前端模型/命令/venv 60 项、AgentFlow 单元及 LuCI 20 项均通过；OpenClaw 59 项中通过 58 项，1 项本地 sqlite-vec fixture 检查跳过（已在设备执行真实查询）。前端类型/构建、Lua 解析、shell/JS 语法、diff 空白检查通过。

本地 OpenClaw 测试需明确设置已缓存的 24.22.1 Node；直接使用开发容器默认 24.15.0 会产生版本/配套 npm fixture 失败，不能视为设备实现故障。测试固定 meta 版本的过时断言已随本次未发布候选更新。临时 rpcd 会话需先预热 LuCI 的延迟 ACL，再撤销继承权限；最终浏览器验收使用修正后的真实只读会话。

## 边界

- SDK/glibc 主场景复用校验过的原始归档缓存，仍在设备真实解包、安装和探测；不将其计为本轮设备冷下载加速。另有真实 fresh npm 元数据加速证据。
- 只部署和执行 x86_64 `.7`，没有操作 ARM64 `.93`。没有配置模型密钥或验收代理模型调用。
- 测试目录和旧仓库保留。共享 HOME 的登录信息不复制；已有进程、手写旧 wrap 和第三方未接入插件需要用户重启或自行适配。
- 沿用已有尚未发布候选的版本提升，不重复递增；本次未提交、推送或发布代码。
