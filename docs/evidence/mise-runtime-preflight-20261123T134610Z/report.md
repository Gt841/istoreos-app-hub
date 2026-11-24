# mise 实施前环境检查

检查时间：2026-11-23 13:45–13:49 UTC。结果：开发和构建资源基本具备，完整双架构实机验收环境尚未就绪。没有开始 M1–M9，没有安装软件、格式化/挂载磁盘、清理目录、停止服务或重启设备。本次预检不消耗实施整改轮次。

## 实测资源

空间统一按 GiB（1024³ 字节）列出；内存为 MemAvailable，不将缓存占用直接认定为缺内存。

| 环境 | 持久存储剩余 | 可用 inode | 可用内存 | 判断 |
| --- | --- | --- | --- | --- |
| 开发机 SSD `/var/cache/build-cache` | 219.1 GiB | 26,450,493 | 约 27.7 GiB | 足够；SSD 入口自检通过，前端依赖和浏览器已存在 |
| 开发机 `/projects`（与 `/config` 共用） | 236.2 GiB | 72,098,594 | 同上 | 源码/证据可用；构建临时输出继续使用 SSD |
| 构建服务器 `abc@192.168.9.19:7022` `/builders` | 185.6 GiB | 69,460,518 | 约 27 GiB | `make ops-preflight` 通过，8 CPU，已有 x86/ARM64 SDK |
| x86_64 `.7` `/mnt/vio4-0` | 7.65 GiB | 766,513 | 约 1.36 GiB | inode 足够，完整多语言/版本与回滚容量偏紧 |
| ARM64 `.93` `/mnt/nvme0n1-1` | 49.57 GiB | 7,503,805 | 约 2.93 GiB | NVMe 容量足够，系统健康存在阻塞项 |

两个目标均 SSH 正常，iStoreOS 24.10.8，内核 6.6.144；x86 为 `x86_64`，ARM 包架构为 `aarch64_generic`。均无 swap；后续安装/编译按设备串行和低并发执行，尚未做峰值内存或安装压力验证。

为完整 SDK 多版本/ABI、下载缓存、安装候选、OpenClaw 包与回滚预留，建议每台设备先确保至少 30 GiB 可用持久空间。30 GiB 是工作容量预算，不是已测得的最终产物总和；精确产物与实际数据备份预算在 M1/M2 再计算，空间变化后重新检查。

## x86_64：现有数据盘偏紧，发现额外 64 GiB 磁盘

- 当前独立数据盘 `/dev/sdc` 挂载 `/mnt/vio4-0`，ext4、rw，无 noexec 标记；root 的权限检查可写，未做实际写入/执行测试。
- `/dev/sdd` 容量为 64 GiB，QEMU HARDDISK，未挂载、无 holder，未检测到分区或文件系统签名。不能由此证明整盘无数据；本次没有改盘。见 `x86-extra-disk.json`。
- 现有 `.7` 上还有 QuickStart/容器/loop 等其他任务挂载，不可作为可随意回收的本任务空间。
- 两个历史 OpenClaw 验收目录合计约 4.69 GiB；均保留，没有清理。即使清理这部分，也不能达到上述 30 GiB 预算。
- 当前未安装 mise、ks-cli，也没有运行的 KSpeeder；需要在后续准备阶段补齐加速测试依赖。未安装 Node/Python 是公共运行时引导应覆盖的正常情形，不要求先手工安装解释器。
- 当前未配置 mise/OpenClaw 的测试目录，后续必须显式选择独立持久路径。
- 两次内核告警筛查均未发现匹配的 SquashFS/I/O/EXT4/OOM 错误；这不等于完整硬件健康认证。

建议：先确定额外 64 GiB 磁盘的归属/数据保留要求，准备专用持久文件系统和隔离目录，再开展全量安装验证。现有 overlay 空间不计作 SDK 数据盘替代品。

## ARM64：系统只读层读取错误需要先处理

- NVMe 为 ext4、rw，无 noexec 标记，当前旧 mise HOME 已在 `/mnt/nvme0n1-1/Configs/Runtime/home`；约 2.56 GiB 旧 HOME 和正在运行的 AgentFlow 需要兼容保留。
- 旧 mise `2026.8.14-23`、ks-cli `0.9.0` 已安装；`iStoreEnhance` 和 AgentFlow 正在运行，5003 下载网关 routes 返回 HTTP 200。
- 系统 overlay 只剩约 462 MiB；SDK、归档和缓存必须使用 NVMe。
- 当前 boot ID 为 `15109b6a-9070-49ea-88e0-6ba2e17a5545`，与此前记录一致。本次没有观察到再次重启。
- dmesg 在本次开机第 20/22 秒记录 8 条 `SQUASHFS error`，包括 xz 解压失败、块读取和 inode 读取失败。初查与约两分钟后的复查数量一致，未观察到新增匹配项。根因尚未确定，不能据此断言 NVMe 损坏、确定过去重启原因或认定问题已解决。
- busybox、mise、ks-cli、lua 的只读摘要读取成功，但不足以覆盖其余只读系统文件。未对全盘做读写压力或修复。

建议：先定位并消除/给出可信解释和验证的系统只读层错误，再做启动、持续读取和受控重启复查；或者明确选择另一台健康 ARM 设备。此问题阻塞完整实机验收，不自动重刷固件或更换 IP。

## 网络与构建条件

- 两台 Node 发布目录、npm registry、GitHub release 页面、PyPI、Zig 目录和 Temurin release API 的小型请求均取得 HTTP 200 且 TLS 校验正常。
- Go metadata GET 在两台出现连接超时；ARM Rust manifest 请求也超时。早先 x86 的 Go 页面 HEAD 曾返回 405，不能等同于归档下载完成；Rust 在 x86 的请求成功。见 `download-source-probes.json`。
- ARM 的加速网关 routes 为 200；`ks-cli --explain npm --version` 只证明本地命令解析，不证明实际网络装包或归档加速通过。完整固定产物、签名/摘要与包管理器下载链路尚未测试。
- 构建服务器已有 x86/ARM64 的 SDK 和源码缓存，Docker 预检通过。现有 x86 IPK 缓存有 21.02.3/24.10.1，ARM64 有 24.10.8 等；后续应明确选择与目标兼容的 SDK，不把 ARM SDK 套到 x86，也不直接复用旧 profile。
- mise/OpenClaw 专用 profile/feed 尚不存在。当前构建器为 feeds-only，不会自动构建本地未提交代码；实施前需确定可复现候选输入与配方同步方式，不能把旧 feed 构建成功作为新代码通过。
- 本机普通用户直接访问 Docker socket 被拒绝，`sudo -n docker` 可只读访问；实际包构建已有独立构建服务器。本次没有创建容器或开始编译。
- 构建器现有 Docker 的 swap-limit/aufs 提示保留在日志中，预检返回 0；本次没有改动 Docker。

## 开始实施的判断与前置门槛

| 范围 | 当前判断 |
| --- | --- |
| M1 契约、清单与本地开发 | 资源允许；本次尚未开始，由用户决定启动 |
| M2–M5 双架构正式安装与 Gateway 验收 | 暂不启动完整执行：先解决 x86 存储准备和 ARM 系统健康 |
| M6–M9 全语言与最终集成 | 前置门槛未全部通过，不应宣布环境已经就绪 |

完整执行前需完成：

1. x86 专用持久空间达到工作预算；可优先评估 `.7` 的额外 64 GiB 磁盘，处理前确认归属和数据。
2. ARM 只读层错误定位/处理与健康复查通过，既有 AgentFlow/KSpeeder 数据与服务有可核对基线。
3. x86 加速依赖与固定测试目录准备完毕；两台的固定产物下载和所需 Go/Rust 路由验证通过，不关闭 TLS 或完整性检查。
4. mise/OpenClaw 专用双架构构建配置和可复现源码输入路径确定；实际构建与部署仍在对应里程碑验收。

建议先准备环境，再开始完整里程碑实施；如决定先推进本地契约工作，可只启动 M1，把双架构正式安装保留在门槛之后。本次没有向用户请求格式化、修复、部署或清理的授权。

## 证据及检查限制

主要证据：`summary.json`、两台 `<IP>.log`、`<IP>-health-followup.json`、`x86-extra-disk.json`、`local-storage.json`、`ssd-status.json`、`builder-preflight.json`、`builder-storage.json`、`download-source-probes.json`。只读设备探测脚本随目录保留。

`arm-health-followup.json` 中一次 awk 引用错误导致告警统计未执行，原始失败记录保留；随后使用 `health-followup-probe.sh` 更正，实际统计见 `192.168.30.93-health-followup.json`。不将前次整体 shell 返回 0 误报为全部子检查通过。

未验证：新磁盘空白性、实际写入/执行能力、完整设备文件系统健康、安装峰值内存、完整产物网络传输、真实 SDK 构建、浏览器当前功能回归、固件重启与 OpenClaw Gateway。文档和探测结果不能替代这些实施阶段验收。
