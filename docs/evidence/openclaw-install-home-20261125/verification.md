# OpenClaw 安装失败修复与正式服务验收

2026-11-25，x86_64 `192.168.30.7`，当前业务目录 `/mnt/vio4-0/Configs/OpenClawMgr`，共享仓库 `/mnt/vio4-0/Configs/Runtime`。

## 两个独立原因

1. 用户的三次安装均已通过 npm 安装、原生模块和 sqlite-vec 检查，激活后 Gateway 健康检查失败并正常回滚。procd 的 root 准备进程继承应用 HOME，该目录属于 UID 32771；管理任务复用已有 SDK 时，执行器正确拒绝 root 使用另一 UID 的 HOME，日志为 `HOME parent belongs to another UID`。设备三个相关源码的 SHA256 与本地一致，排除了旧文件差异。
2. 修复上述上下文后再完整安装，得到明确的 `unauthorized: gateway token mismatch`。端口 18793 实际由旧 M5 测试 Gateway（PID 31443，UID 32771，HOME 与 cwd 均为 `/mnt/mise-runtime/acceptance/M5/OpenClawMgr/data`）监听；该进程不受当前 procd 实例管理。健康检查连到了旧实例，安装再次回滚。

## 修正

- `tasks.lua` 只在后台管理子进程中明确设置 `HOME`、`ISTORE_RUNTIME_HOME` 为 `<当前仓库>/home`，覆盖安装与已有 SDK 探测。调用方环境、应用 HOME 和执行器权限检查均保留。
- 安装下载前检查 IPv4/IPv6 监听端口；停服后、激活前再次检查。只接受属于当前数据目录对应 procd 进程树的监听 socket，识别官方 CLI 派生的 Gateway 子进程。旧目录实例、孤儿进程和其他服务返回 `PORT_IN_USE`；不自动杀监听者，不修改 token。无 IPv6 的内核可正常检查 IPv4。
- 人工核对旧进程 UID、cwd、PID/start/boot 身份后，发送 SIGTERM 停止这个已知的旧 M5 测试进程，保留原目录及数据。随后按当前配置重新完整安装，退出码 0，事务已提交。
- mise-runtime 与 app-meta-mise 提升至 `0.1.1-2`，OpenClaw 界面包及元包提升至 `0.1.13-2`；OpenClaw 最低依赖公共运行时 `0.1.1-2`。包数据库未被直接部署伪造更新，仍需人工编译安装正式包。

## 回归与验收

- 首个可复现命令：`ssh root@192.168.30.7 lua /tmp/dependency-home-device.lua /mnt/vio4-0/Configs/Runtime /mnt/mise-runtime/acceptance/openclaw-home-20261125/red /mnt/vio4-0/Configs/OpenClawMgr/data`。修复前 `ensure_success=false`；修复后用新的 evidence 子目录执行，已有 SDK 与空仓库两项均通过。每次测试目录必须尚不存在。
- [dependency-red.json](dependency-red.json)、[dependency-green.json](dependency-green.json)、[dependency-cold.json](dependency-cold.json)：真实公共 ensure；调用者 HOME、应用目录属主、UCI、已有 SDK 收据保留，root 直接使用应用 HOME 仍被拒绝。空仓库测试复用 SHA256 校验过的三份原始归档缓存，真实执行解包、安装及探测，不计为冷下载加速测试。
- [conflict.json](conflict.json)：旧实例身份和冲突记录；修复后的设备命令在停止旧实例前返回 `PORT_IN_USE`。原安装脚本的最小回归测试明确失败，新脚本在任何依赖下载或停服前拒绝冲突。
- `test_port_guard.py`：14 个实际解析/归属场景，包括 IPv4、IPv6、无 IPv6、连接非监听状态、当前进程、子进程、孙进程、孤儿进程、旧 HOME 与错误 socket。实际正式 procd 子进程监听也通过了升级前检查，见 [owned-port.json](owned-port.json)。
- [service.json](service.json)：7/7，正式 procd 服务运行，UID 32771，应用独立 HOME，当前仓库绑定，准备状态 ready，携 token 的 Gateway health 成功；通过 OpenClaw 自身 `openclaw-memory-host` 加载 sqlite-vec `v0.1.7` 并执行最近邻查询成功。
- [browser/browser.json](browser/browser.json)：4/4，真实 LuCI 页面显示已安装、运行中、GNU Node 与 glibc 2.39，HTTP readiness 成功，无页面异常。开发环境直连设备 HTTP 超时，本轮通过临时 SSH 转发访问设备原生 uhttpd，并未修改防火墙。截图中的 token 已隐藏。
- 本地契约 52 项、AgentFlow 20 项通过。OpenClaw 全套 60 项中，安装流程及执行检查通过；发现一项旧测试写死 meta release 1，将其改为检查界面与元包版本/修订一致性后，该失败项和端口回归重跑通过。合计 59 项通过、1 项本机未提供 sqlite-vec 文件而跳过；实际设备向量查询已通过。
- [source-audit.json](source-audit.json)：最终直接部署的 83 个程序文件内容与模式一致，1 个用户配置保留。原 tasks.lua 另备份于设备测试目录的 `backup/tasks.lua`；分次部署各自提供 rollback 脚本。

没有清理用户数据，没有调用模型 API，没有重启系统或执行 ARM 验收，没有编译 IPK/APK。当前 Gateway 仍按用户现有配置仅本机监听；本轮不改变其监听范围。
