# M4 通过：移除旧探测，选择性接入 ks-cli

2026-11-24 UTC，目标 x86_64 `192.168.30.7`、aarch64 `192.168.30.93`。本次用户授权续作解决上轮兼容阻塞；M4 通过，后续进入 M5。未公开推送、发布或触发 GitHub Actions。

## 原因与修复

两台已安装 ks-cli **0.9.1**，无需为本问题再次更换客户端二进制。阻塞来自 mise helper 自带的旧探测：每次准备 HOME 都会访问网关和 Node 镜像，且忽略 `acceleration=0`；GNU Wget 的 `-T 3` 不能限制总重试时间。上轮实际等待超过 120 秒。

已删除环境初始化中的网络探测及旧镜像变量注入。`mise-istore` 的明确下载类子命令按开关直接交给 `ks-cli mise`，本地 `exec`、版本和 shell 使用原生 mise。显式镜像、关闭加速或缺少可选 ks-cli 时保留原生语义。完整规则及前置全局选项的调用限制见 [运行时契约](../../../product/mise/runtime-contract.md)。

不能将所有命令统一转给 ks-cli：当前 0.9.1 会对 `mise exec` 协商加速服务。固定 SDK 的本地执行不应由服务健康决定。公共管理器原有 `ks-cli download` 和 npm/git wrap 不变，不重复实现网关探测。

## 复现与验收

- [旧真实 IPK helper 的红测试](legacy-unit-red.txt) 在故意不响应的可选网络工具下超过 1 秒，确实重现环境初始化阻塞；[六项绿测试](legacy-unit-green.txt) 通过。原/新 helper 摘要见 [回归记录](legacy-regression.json)。测试覆盖本地离线、加速路由、开关、缺少 ks-cli、自定义镜像、参数/stdin/退出码。
- 构建器 21 项测试和 preflight 通过。构建器修订 `a4cf9d0ded21db195f6d2be4e1b8f2d9c4428182`；候选补丁 SHA256 `07e15dbe563be846ebd990241000f673ed1c9820ad4a0a6854428e82d3803e52`。两架构均使用 clean SDK 和 canonical feed 刷新，逐个验证实际 origin/固定提交。归档目录包含日志、输入、锁、构建状态和 IPK SHA256；IPK 保留在构建器 artifacts。
- 两台各五个实际 IPK 的来源、载荷、依赖、架构、注册、文件模式通过；重装后逐个校验安装文件摘要与候选相符。版本保持本次候选的 mise r26、ks-cli 0.9.1-r1、新核心/页面/元包 r1，没有反复增加待发布 release。
- 实际安装入口在故意阻塞 wget/curl 的环境下执行 Node、保留 stdin/空格参数/退出码，并启动交互 shell。本地各项 x86 约 0.06–0.11 秒、ARM 约 0.18–0.35 秒；没有调用阻塞工具。真实 ks-cli 的只读执行计划确认下载路由和 SHA256 校验保留，未因此安装或启动加速服务。这不是一次额外的真实加速下载测试；实际源站/加速下载证据沿用 M2/M3。
- 两台以 UID 65001 执行正式固定 wrap，验证 Node/npm、持久 HOME/TMP、固定 execPath 及 Node 子进程；共享 SDK 未迁移。实际系统 UCI 下 ARM 原默认 Node 24.20.0 经两个公开入口均通过，AgentFlow health 成功，iStoreEnhance/AgentFlow 原进程及二进制保持原状。
- 最终 IPK 上实际页面完成权限/CSRF/参数边界、第二版本 musl Node 的安装与刷新、真实 wrap 下载、保护、删除及缓存清理；两台桌面与 320/390 视口、深浅主题、焦点及真实过期计划错误颜色通过。此前 M4-resume2 的六组功能和三组故障/取消/中断恢复证据保留；最终包审计证明对应核心、transport 和样式已经进入实际 IPK。

| 检查 | x86_64 | aarch64 |
| --- | --- | --- |
| 构建 | [mise-m4ks-x64-20261124040156Z](mise-m4ks-x64-20261124040156Z/build.status) | [mise-m4ks-arm64-20261124040156Z](mise-m4ks-arm64-20261124040156Z/build.status) |
| 来源 / 包内容 | [来源](x64-build-audit.json)、[IPK](x64-ipk-audit.json) | [来源](arm64-build-audit.json)、[IPK](arm64-ipk-audit.json) |
| 实际安装 | [通过](x64-package-install.json) | [通过](arm64-package-install.json) |
| 已安装旧入口 / 普通 UID | [旧入口](x64-legacy-device.json)、[UID](x64-ordinary-user.json) | [旧入口](arm64-legacy-device.json)、[UID](arm64-ordinary-user.json) |
| 正式页面 | [完整复验通过](x64-final-browser-r2/production-final.json) | [完整复验通过](arm64-final-browser/production-final.json) |
| 实际宿主样式 | [通过](x64-host-r2/production-host.json) | [通过](arm64-host/production-host.json) |
| 最终状态 | [通过](x64-final-state.json) | [通过](arm64-final-state.json)、[原业务](arm64-legacy-business.json) |

## 验收脚本纠正与现场

本轮产品代码只需上述一轮修复。验收中纠正了几处夹具问题，原失败记录仍在：公共 SDK 按协议要求显式 `ISTORE_RUNTIME_HOME`，不能假设仅改变 HOME 就覆盖固定 wrap；没有加速服务的 x86 只读 explain 需要明确端口；页面已有同名历史任务，标题定位必须限定在当前 dialog。首次 x86 页面安装已实际完成，随后仅删除该测试 musl 实例，恢复一实例起点并完整重跑。会话清理命令补齐 `--destroy` 后实际执行成功。相应 initial-fixture、reset 和 final-destroy 证据均保留，不覆盖为假成功。

ARM 的保护性旧 helper 回退已由新 IPK 正式替换，两台当前 `/lib/functions/mise.sh` 都为 `40022def3ec421028d09f2851231b8dec5dee3699ec6301888abc09e13a78083`，与候选源码及包一致，不再存在上轮的 helper/包数据库偏差。未改旧默认，未删除旧 SDK、数据或配置。两台 Runtime-live 各保留 Node 24.21.0/glibc/npm 11.19.0 及其私有库；测试 musl 实例经页面删除。无安装锁，核心 work 为空，各三份临时 rpcd 会话及私密会话文件均已删除。

本轮没有重启设备，也没有宣称 OpenClaw Gateway/sqlite-vec 已通过；它们属于后续 M5。M5–M8 不能继承本报告为完成。对这类故障的预防已落为环境初始化无网络的回归，避免以后再次把可选加速与本地 SDK 启动耦合。
