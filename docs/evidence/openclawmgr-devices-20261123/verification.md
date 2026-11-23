> 此为 glibc 改造前的真实设备记录。用户后续撤销 vec 缺失容忍标准，新的隔离 glibc/vec 硬门禁结果见 [后续验收](../openclawmgr-glibc-20261123/verification.md)。

# OpenClawMgr 真实设备验收（2026-11-23）

## 结论

本轮不能标记为两种架构全部通过。x86_64 新装、同版本完整事务升级、认证 Gateway health、非 root procd 和升级准备阶段取消已通过。
ARM 安装切换阶段遭遇设备重启；磁盘上配置、native.json、CLI 输出和 data.tar 为零长度，最终 Gateway 验收未通过。
恢复候选已在 ARM 真机验证：拒绝无效备份，返回非零，保留 current、data 和 journal。
用户同意 Gateway 优先；缺少 sqlite-vec 向量扩展加速是明确记录的功能缺失，不等于完整向量能力通过。

## 范围与三轮边界

沿用最初三轮本地实施记录；后续用户另行授权两种架构真机验收。
真机完整安装候选按三轮核验：第一轮严格 native 门禁发现 vec ABI 不兼容；第二轮核对上游回退并发现
health CLI 参数和 ARM PTY 问题；第三轮修正后 x86 新装提交成功，ARM 重启留下损坏现场。
第三轮内补齐空配置入口及损坏快照保护与本地回归，未开启第四轮 ARM 完整安装。

两台测试采用独立数据目录、19189 loopback 端口、无模型 API 密钥。部署后端候选文件，
通过候选 LuCI controller 的 HTTP 上下文夹具提交到真实 taskd；procd、UCI、ks-cli、npm、Node、OpenClaw 均为真实程序。
HTTP 夹具只替换请求/响应上下文，不替换系统后端；不是浏览器登录、ACL、CSRF 传输或完整 LuCI UI 验收。
未构建/安装 SDK ipk，也未验证包首次安装时创建账号的路径（测试账号单独创建）。

## 设备和能力

| 项目 | x86_64 .7 | arm64 .93 |
| --- | --- | --- |
| 固件 | iStoreOS 24.10.8 / musl / Linux 6.6.144 | 同左 |
| Node / npm | 24.22.1 / 11.19.1，实际执行通过 | 同左（重启前） |
| Node SQLite | 3.53.4，TEXT/BLOB/JSON round trip 通过 | 同左（重启前） |
| OpenClaw | 精确 2026.3.28 + metadata/SHA512 | 同版本，安装依赖已多次完成，最终未提交 |
| sharp | 实际 1px PNG 处理通过 | 重启前通过 |
| sqlite-vec 0.1.7 | 不可用；FTS5 探测通过 | 不可用；FTS5 探测通过（重启前） |
| PTY 模块加载 | 通过（未做交互会话验收） | 不可用；该精确版本支持普通子进程重试，最后一次探测文件未完整落盘 |
| Gateway | 新装、升级及独立认证 health 均 OK；UID 998 | 未通过最终验收 |
| 完整升级 | current 切换、previous 指向旧 release、数据/快照哨兵通过 | 未完成 |
| 升级准备阶段取消 | controller 显示 upgrade；current/PID 保持，锁清理 | 安装准备阶段取消通过，运行中升级取消未覆盖 |
| 切换后恢复 | 新装 health 参数失败时真实回退；已有运行时完整回退以 fixture 覆盖 | 实际拒绝损坏归档，保留现场；不是成功恢复证明 |

sqlite-vec 实际存在但 musl 加载失败；额外 dlopen 诊断发现 `__memcpy_chk` 未定义。
SQLite 原始报错中的 `.so.so` 路径不能直接解释为没安装文件。
仅对已审核的 2026.3.28 使用源码既有降级路径，其他版本仍严格失败。
源码片段、SHA256 与能力范围见 [upstream-fallback-policy.json](upstream-fallback-policy.json)。
FTS5/子进程小探测证明本机基础能力，不等同于真实记忆检索、PTY 会话或模型推理的端到端验证。
Matrix postinstall 下载存在失败/ARM musl 不支持记录；Matrix 频道未验收。

## 下载与加速的实际边界

- 两台都实际使用已发布 ks-cli 0.9.1。x86 临时 KSpeeder 0.9.1 使用非默认 TLS 55443/admin 55003；
  ARM 保持已有 KSpeeder 0.9.0 服务，临时 CLI 0.9.1 可用。
- 真实 npm 查询、精确版本 pack、依赖安装通过对应 ks-cli npm 路由；GitHub ls-remote 获得同一 tag hash。
- Node 的 ks-cli 自动下载遇到低速源站/加速 502；该任务用于真实取消验证。最终 Node 归档是在开发机
  下载相同锁定产物后预置缓存，设备安装器再次验证 SHA256。因此不宣称完整 Node 加速下载通过。
- Matrix postinstall 自行从 GitHub 下载，不在 npm/Git 适配覆盖范围内。不能宣称全部生命周期下载都已加速。
- 安装优先复用 npm 缓存不改变精确顶层包 SHA512 校验；依赖树仍未做完整锁定。

## 重启事件

详见 [environment-events.md](environment-events.md)。.244 仅执行只读检查，未部署候选。
10:35 左右观察到 .93 刚启动、.244 已运行 43 分钟；10:41 两者 boot ID 均未变化。
ARM 有 SQUASHFS xz/metadata 读取错误和零长度事务文件，pstore 没有明确 panic/OOM 终止记录。
未执行 reboot；不能从这些信息确定重启原因，也不能认定两台同时重启或都由 OpenClaw 引发。
文件系统/掉电完整性不在进程 SIGKILL 恢复测试的保证范围内。

## 本地最终验证

46 项测试 × 默认 shell / BusyBox ash，两组均通过（92 次）；26 项静态检查全部通过。
涵盖：真实 Node/helper、SRI/归档错误、空间/inode、npm/CLI/native 失败、连续升级、旧布局、取消/子进程回收、
硬中断与恢复重试、空配置恢复入口、无效快照保护、精确版本降级限制、终端 shim。
见 [final-default.log](final-default.log)、[final-busybox.log](final-busybox.log)、[final-static-checks.json](final-static-checks.json)。
此前对 ks-cli 卡死的猜测已被真实子进程/Go stack 证据否定，不作为 ks-cli 缺陷；没有修改 ks-cli/KSpeeder 源码。

## 环境恢复与待办

ARM 原 KSpeeder 三项保护文件 SHA256 已恢复一致，CLI 回到 0.9.0，已有服务正常。
测试服务/账号/启动链接移除；中断运行时保留在
`/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/interrupted-runtime`，私有目录 0700。
软件依赖变化保留并逐设备记录在 `package-changes.json`：两台新增 timeout，x86 新增 Git/Git HTTP，
ARM Git/Git HTTP 从 2.50.1 升至 2.50.2；没有盲目卸载共享依赖。

x86 完整升级 exit=0，独立 health OK；current/previous 及 data/快照哨兵实际断言通过。
真实故障代理实验在热缓存与空缓存下均未阻断 ks-cli 查询/下载，故不计为网络失败测试；已取消，
断言原 Gateway PID/current 不变并恢复原缓存。未再启动完整安装轮次。
x86 原本不存在的测试文件、OpenClaw/KSpeeder 临时服务及账号均已移除，无测试启动链接。
运行时证据保留在 `/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/completed-runtime`，位于 0700 私有目录。
两台恢复后的独立断言见各自 `90-final-restoration-check.log`；ARM 的包查询遇到其他操作占用 opkg 锁，
改为只读包数据库完成，见 `91-final-readonly-package-check.log`。锁未被改动。已有运行时切换后的健康失败/SIGKILL 恢复、
latest/origin 路径和卸载在本地 fixture 覆盖；没有把这些列为两种架构均已真机通过。
发布前仍需：在稳定 ARM 存储/固件环境重新完成 Gateway、新装/升级/健康失败/恢复验收；
SDK ipk 安装和真实浏览器 UI 验收；按需补测 Matrix、PTY 会话、向量检索与模型调用。
未提交、推送或发布。
