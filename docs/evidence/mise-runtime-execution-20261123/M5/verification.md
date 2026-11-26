# M5：OpenClaw 固定公共运行时验收

结果：x86_64 `192.168.30.7`、aarch64 `192.168.30.93` 均通过源码直部署的实际业务验收。两次优化记录在 [优化 1](optimization-1.md)、[优化 2](optimization-2.md)。包编译、包依赖/文件归属/安装升级钩子验收按用户要求待人工确认后人工进行；本阶段没有新增 IPK/APK 构建或公开发布。

每个 release 的 runtime.json 固定公共存储、Node24.22.1/npm11.19.1、GNU 库 r1 和清单摘要。安装/CLI/npm/Git/procd/状态入口共用解析；应用目录只有小型 Node 入口，不复制 SDK/库，也不修改全局默认或建立应用登记。

| 必选检查 | x86_64 | aarch64 | 证据 |
| --- | --- | --- | --- |
| 新安装、认证 Gateway、专用 UID32771、无 root 附加组 | 通过 | 通过 | `*-gateway-r1.json`、最终 Gateway 记录 |
| OpenClaw 自身 memory-host loader 加载 sqlite-vec0.1.7、vec0 插入和最近邻 | 通过 | 通过 | `*-gateway-post-reboot.json`、`*-gateway-final-modes.json` |
| 缺 vec/精确 SDK 拒启，恢复后公开 restart 健康；不回退其他版本 | 通过 | 通过 | `x64-runtime-boundaries-r1.json`、`arm64-runtime-boundaries-r2.json` |
| 真实私有 GNU 旧目录升级，保留旧 Node/数据/认证 | 通过 | 通过 | `*-legacy-migration-*.json`；fixture 来源明确记录，未冒充原用户安装 |
| managed release 升级、切换后新 vec 故障自动恢复旧指针/数据/认证 | 通过 | 通过 | `*-cutover-vector-r1.json`；x64 另有完整缓存升级日志 |
| npm 安装中取消、协调器 SIGKILL 后正式恢复并回收实际子进程 | 通过 | 通过 | `*-cancel-final.json`、`*-interruption-final.json` |
| 应用取消自己提交的实际公共 SDK worker，保留已有 SDK/Gateway | 通过 | 通过 | `x64-shared-cancel-r2.json`、`arm64-shared-cancel-final.json` |
| 另装 Node24.21/npm11.12.1 和 r2 库，原 PID/绑定/向量查询不变 | 通过 | 通过 | `*-independence-*.json` |
| 应用卸载保留数据、公共 SDK 和第二调用方 | 通过 | 通过 | 旧目录迁移验收记录 |
| 正常重启、持久挂载、固定绑定/配置/二进制/旧默认不变；ARM AgentFlow健康 | 通过 | 通过 | [重启对照](reboot-comparison.json) |
| 实际 LuCI 状态、OpenClaw 页面、mise 实际环境列表、未登录凭证保护 | 通过 | 通过 | `ui-*/luci-live.json`；临时会话已销毁 |
| 最终部署 67 个代码/资源文件字节与权限复验，保留现有配置 | 通过 | 通过 | `*-direct-deploy-r10.json`、`*-final-source-audit.json` |

本机最终 59 项测试：58 通过，1 项仅因未提供本机 vec 扩展条件跳过；实际目标上的向量查询全部执行并通过。初期 16 组真实绑定检查、8 组 UID helper/字面凭证解析检查也分别通过两架构。普通命令、参数/stdin/退出码与非 root 入口沿用公共契约。

优化 1 修复强杀协调器后的实际 npm 遗留进程；进程记录在 exec 前落盘，恢复先关闭登记目录并回收所属会话，再清理候选。ARM 原 900 秒依赖下载超时被完整记录，随后只对依赖安装增加有界时限，并为固定 Matrix 下载脚本增加官方 SHA256 原始文件缓存。缓存、脚本变更和损坏拒用实际测试通过两架构；任意生命周期 HTTP 并非全部加速。一次 ks-cli accelerated 探测返回502，没有记为成功。x64 一份 Matrix 原始文件在开发机下载、按官方摘要校验再传输，单独记录，未伪称设备下载加速。

ARM 一次场景重叠与一次 SDK 测试声明 build 不匹配属于测试调度/输入问题，失败事实保留，未计为通过。后续场景以设备测试租约串行运行，修正的 SDK build 声明通过所属取消验证。

最终正常重启 boot ID：x64 `7c32b9b6-0a31-4cf4-9142-276a9e89a8b8`，ARM `6dda18fd-f437-4407-8630-b5427cd41570`。随后仅将直部署权限归一化为0755/0644/0600，代码字节不变，再次审计和实际 Gateway/向量检查通过。原 ARM AgentFlow、iStoreEnhance 配置/二进制和旧 mise 默认保持原摘要。

边界：Gateway/向量能力不代表付费模型、embedding 语义检索或所有频道端到端验收。应用 top-level SHA512 不代表整个浮动依赖树已锁定。公共 glibc 为已记录的兼容候选，不宣称最新安全修订。各批次回滚命令在部署清单中，备份及配置留在设备私有目录；新的用户数据/公共运行时不随代码回滚删除。
