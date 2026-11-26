> 后续用户已要求私有 glibc 和 sqlite-vec 硬门禁；当前追加目标见 [glibc 改造任务树](openclawmgr-glibc.md)。以下保留原 musl 阶段的目标与验收历史。

# OpenClawMgr 安装优化目标与任务树

## 目标与范围

将 OpenClawMgr 的安装和升级改为可验证、可取消、失败能恢复原运行时的流程。
保留 LuCI/taskd/procd、现有 data 目录和 stable/latest 入口；OpenWrt 包管理器拥有
ks-cli/KSpeeder，OpenClawMgr 拥有自己的 Node/OpenClaw 运行时和安装事务。
本地实施阶段不发布、不修改远程设备，不把本地 fixture 结果当作真实设备验收。
后续用户另行授权在 192.168.30.7（x86_64）与 192.168.30.93（arm64）验收，
对应证据独立保存在 `docs/evidence/openclawmgr-devices-20261123/`。

## 任务树与完成标准

- T1 错误与预检查
  - T1.1 下载、npm、配置、启动、健康检查失败必须返回非零。
  - T1.2 安装和升级均检查架构、libc、持久目录、可用空间和 inode。
- T2 Node 运行时
  - T2.1 固定版本和四种 arch/libc 产物的 HTTPS 来源及 SHA256。
  - T2.2 缓存和新下载均先验摘要；暂存解压后实际执行 Node/npm。
  - T2.3 系统/已有 Node 必须通过版本、npm 和目标 engines 检查才能复用。
- T3 包安装与加速
  - T3.1 加速下载和 npm 使用 ks-cli；关闭加速走 HTTPS/原生 npm。
  - T3.2 latest 只解析一次，安装精确版本；记录 metadata integrity。
  - T3.3 去掉 musl 全局 ignore-scripts；明确必要脚本与原生依赖验证。
  - T3.4 不写用户全局 npm/Git 配置；终端沿用相同进程级入口。
- T4 安装事务
  - T4.1 候选目录安装与 CLI/原生依赖验证期间保留旧服务。
  - T4.2 验证后停服务，切换 current，保留 previous；兼容旧 node/global 布局。
  - T4.3 配置备份、安装记录、启动/健康失败回退；不声称自动回退业务数据。
  - T4.4 TERM/INT/HUP 等待子进程退出再清理；异常中断保留可恢复状态。
- T5 集成与文档
  - T5.1 init/CLI/卸载兼容新旧布局，取消入口不提前删锁或强杀协调者。
  - T5.2 增加必要包依赖并将 app-meta PKG_RELEASE 从 2 提升到 3。
  - T5.3 文档说明版本策略、Git/脚本下载边界、数据迁移及设备验收要求。
- T6 验收（最多三轮）
  - T6.1 隔离 fake UCI/procd/网络/npm；不得安装宿主服务或真实 OpenWrt 包。
  - T6.2 覆盖新装、升级、下载/摘要/npm/运行时/健康失败、取消及旧布局迁移。
  - T6.3 检查 shell/JS/Lua 语法、包依赖与版本、最终 diff。
  - T6.4 每轮记录发现、修复、命令和结果；第三轮后如仍失败明确列出。

## 设计约束

安装顺序：预检查 → 暂存 Node → 解析包精确版本和 engines → 安装候选 →
CLI/原生依赖验证 → 备份配置 → 停旧服务 → 切换 → 启动/健康检查 → 提交记录。
程序恢复与数据恢复分开；启动新版本可能迁移业务数据，必须保留升级前的数据备份。
mise 是后续运行时管理方案，本次不增加第二套运行时管理器。

## 验收记录（2026-11-23）

| 轮次 | 检查结果 | 审查及修正 |
| --- | --- | --- |
| 1 | 23/23 通过；shell 语法与 diff whitespace 通过 | 核心下载错误、SHA/SRI、安装、回退和取消行为验证；审查补充恢复幂等性、备份权限和中断覆盖 |
| 2 | 32/33 通过 | 唯一失败是夹具把固定系统脚本路径也放入含空格目录；修正为只让用户 base_dir 含空格。硬中断、二次恢复、连续升级均已通过 |
| 3 | 36/36 × 2 个 shell 环境通过；27 项静态检查通过 | 默认 shell 与 BusyBox ash/applets 双矩阵；Lua 5.1、ShellCheck、JS/shell 语法、包依赖与权限检查；结束于第三轮 |

### 实施映射

| 任务 | 实现 / 验证入口 |
| --- | --- |
| T1 | `install-runtime.sh` 的 preflight、明确的返回码；入口 start/restart/apply_config 不再吞掉失败 |
| T2 | `node-pins.sh` 四平台 SHA256；`runtime-check.cjs` 的 Node/libc/SQLite 和 engines 门禁 |
| T3 | ks-cli download/npm、`npm-git.sh`、`npm-env.sh`；精确版本 pack 和独立 SHA512 复验 |
| T4 | 候选安装、phase journal、current/previous、data 快照、失败回退、信号清理和 recover_install |
| T5 | 旧目录迁移、CLI npm shim、LuCI 取消、init 临时启动覆盖、卸载；meta release 3 与依赖更新；README |
| T6 | `apps/openclawmgr/tests/test_installation.py`；最终证据归档到 `docs/evidence/openclawmgr-installation-20261123/` |

T1–T6 的本地实施与验证均已完成。最终机器可读结果见
[`../evidence/openclawmgr-installation-20261123/verification.json`](../evidence/openclawmgr-installation-20261123/verification.json)，
验证范围与发布前待办见同目录 `verification.md`。本次未提交、未推送或发布。

### 来源与边界

- Node 24.22.1 来源：[official SHASUMS](https://nodejs.org/dist/v24.22.1/SHASUMS256.txt)、
  [unofficial SHASUMS](https://unofficial-builds.nodejs.org/download/release/v24.22.1/SHASUMS256.txt)。
  本机已下载并校验 official x64/glibc 归档，实际 Node/SQLite 检查通过。
- Node/SQLite 版本门禁依据：[OpenClaw Node compatibility](https://docs.openclaw.ai/install/node-compatibility)。
  不根据 Node 的版本字符串推断其实际链接 SQLite 安全性。
- npm 脚本策略依据：[OpenClaw installation](https://docs.openclaw.ai/install)。
- 对照实现：本仓库 `apps/istoreenhance/ks-cli/Makefile`；工作区 ks-cli 的
  `internal/app/tool_command.go`、`openwrt.go`；zsetup-scripts 的
  `lib/install-transaction.sh`、`lib/install-launcher.sh`。不复制其他仓库的下载引擎。
- 本次不编译/发布 ipk，不写远程设备，不宣称 musl 原生模块/procd/KSpeeder 真机联调通过。
  断电/文件系统损坏和外部数据副作用不由 SIGKILL fixture 证明。

## 后续真实设备验收目标与任务树

用户授权两台设备测试，并明确选择“先验证 Gateway，明确记录缺少向量扩展加速”。
设备验收保留之前三轮本地历史记录；以下真机结果以新的证据目录报告为准。

- D1 保护基线：备份候选会覆盖的文件，记录软件包变化及 ARM 已有 KSpeeder 状态。
- D2 真正执行：musl Node/npm、ks-cli npm/Git、精确 OpenClaw 包 SHA512、原生能力探测。
- D3 Gateway：taskd 提交、procd 非 root 进程、认证 health、新装与同版本事务升级。
- D4 故障：准备阶段取消/失败保留旧服务，切换后健康失败或硬中断恢复；逐项注明实测架构。
- D5 归档与恢复：保存逐设备证据，移除测试服务，恢复原文件和 ARM CLI，说明保留依赖变化。

设备中发现并修正：BusyBox df 不支持 -i、下载器 sidecar 清理、归档 UID、
包装器异常后的子进程回收、Lua 模式错误、CLI 健康命令不支持 --no-color。
仅对已核对源码的精确 2026.3.28，允许 sqlite-vec/PTY 不可用时使用上游既有回退；
记录缺失并探测 FTS5/普通子进程。其他版本仍严格失败。Matrix 与模型推理不作为 Gateway 通过证明。
重启现场另补空配置恢复入口和无效快照保护，最终回归为 46 项 × 2 种 shell，日志见新证据目录。

### 真机最终判定

按三轮上限结束本轮验收：x86_64 新装、同版本升级、Gateway、取消通过；ARM 最终 Gateway 未通过，
重启后发现零长度配置/快照，恢复程序已实际拒绝无效备份并保护现场。两台测试环境恢复完成。
46 项 × 2 种 shell 及 26 项静态检查通过。真实覆盖、未覆盖项、重启证据和软件包变化均见
[`设备验收报告`](../evidence/openclawmgr-devices-20261123/verification.md)。不能以本地回归替代 ARM 通过。
