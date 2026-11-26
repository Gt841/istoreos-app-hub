# M4 再次续作验收：正式包已安装，兼容性仍未通过

2026-11-24 UTC。本次用户授权续作已完成三次优化；M4 保持未通过，停止推进，M5–M8 未开始。原失败历史保留，未降低标准。没有公开推送、发布或触发公共构建。

## 本轮任务树与验收范围

- 构建可追溯：修复 feed 来源/固定提交校验，真实 SDK 构建双架构五个包，检查依赖、包归属、安装后文件摘要和产品注册。
- 正式 LuCI：修复真实 HTTP 到管理器的 stdin 传递，保持动作白名单、认证、读写权限与 CSRF 边界。
- 真实产品流程：页面完成持久目录配置、安装、刷新、取消、失败重试、中断恢复、真实 wrap 下载、删除保护及缓存清理，对照磁盘状态。
- 宿主与风格：在真实 Argon 宿主检查 QuickStart 深浅主题、桌面及 320/390 手机宽度、键盘焦点和错误语义颜色。
- 候选晋级与兼容：把已验证的修改重建为正式 IPK 并重装；复验旧 mise 入口及原有业务。任何必选项失败都不进入 M5。

## 三次优化及结果

| 次数 | 修改 | 自检结果 |
| --- | --- | --- |
| 1 | 构建器在刷新后、收集包前校验全部 Git origin 和不可变提交；修正错误 HEAD 后重新索引，拒绝错误 origin/缺失离线提交 | 构建器共 21 项测试通过；双架构真实 SDK 构建、来源和五包审计通过；实际安装后页面暴露 stdin 故障 |
| 2 | 抽取真实 LuCI transport；pipe 复用 fd 0 时先复制到独立描述符，再 dup2，避免自复制后关闭 stdin/CLOEXEC 残留 | 实际模块在两台设备的正常/已关闭 stdin 场景通过，原实现失败；两台六组产品功能通过，视觉跟进及三组真实故障/维护流程通过 |
| 3 | 对产品根内 notice 增加语义色覆盖，抵抗宿主 Argon 的 `!important`；手机测试以实际视口重新初始化；重新构建并安装最终正式包 | 双架构两组宿主/样式检查通过；最终包构建、来源、载荷、安装后摘要及独立权限/CSRF 复验通过；旧入口兼容回归暴露可选加速网络探测超时，M4 未通过 |

第 2 次视觉失败是测试选择器同时匹配产品与宿主空 dialog；已将选择器限定到产品根，跟进结果保留。最终重装后首次 x64 权限测试使用了 rpcd reload 前创建的 root 测试会话，reload 后该会话被重新授予写权限；重建有限权限会话后，两台权限/CSRF 独立复验通过。上述失败原件均保留，不能将单个失败报告改写为成功。

## 正式构建及测试证据

构建器最终修订 `7467d9953016a2373b089b73bea44fe45d2cae99`；候选补丁 SHA256 `31c1345e0d8f3cfabcc96af05d51fef8b1be6b0ae9bb28663493ebc0ebc1826d`。初次与最终构建的 `build.log`、`build.status`、输入配置、feed 锁和包 SHA256 已分别归档；IPK 留在构建器 artifacts，不作为文档附件重复提交。

| 证据 | x86_64 | aarch64 |
| --- | --- | --- |
| 最终构建 | [mise-m4final-x64-20261124023813Z](mise-m4final-x64-20261124023813Z/build.status) | [mise-m4final-arm64-20261124023813Z](mise-m4final-arm64-20261124023813Z/build.status) |
| 全 feed/SDK/补丁来源 | [通过](x64-final-build-audit.json) | [通过](arm64-final-build-audit.json) |
| 五个 IPK 载荷 | [通过](x64-final-ipk-audit.json) | [通过](arm64-final-ipk-audit.json) |
| 最终实际重装及文件摘要 | [通过](x64-final-package-install.json) | [通过，之后单独回退 helper](arm64-final-package-install.json) |
| 页面六组功能 | [前六组通过，视觉选择器失败原件](x64-browser-r2/production-browser.json) | [前六组通过，视觉选择器失败原件](arm64-browser-r2/production-browser.json) |
| 视觉/焦点跟进 | [通过](x64-browser-r2-visual/production-browser.json) | [通过](arm64-browser-r2-visual/production-browser.json) |
| 故障、恢复、删除、清理 | [三组通过](x64-maintenance-r2/production-maintenance.json) | [三组通过](arm64-maintenance-r2/production-maintenance.json) |
| 实际宿主样式与过期计划 | [两组通过](x64-host-r3/production-host.json) | [两组通过](arm64-host-r3/production-host.json) |
| 最终重装后权限/CSRF | [独立复验通过](x64-final-auth/production-final.json) | [独立复验通过](arm64-final-auth/production-final.json) |
| 停止后的现场状态 | [只读检查](x64-final-state.json) | [回退后旧入口及业务检查](arm64-final-state.json) |

功能/维护/样式测试发生在真实已安装核心上，其中 transport/样式使用过临时源码覆盖；最终 IPK 重建并重装后，文件摘要证明同一修改已进入包。最终包上的额外 musl 安装/删除完整流程没有执行，最终权限专项通过不能替代这一流程，也不能据此宣称 M4 全部通过。实际 transport 的红/绿回归见 [transport-regression.json](transport-regression.json)。

正式包版本：`mise 2026.8.14-r26`、`ks-cli 0.9.1-r1`、`mise-runtime 0.1.0-r1`、`luci-app-mise 0.1.0-r1`、`app-meta-mise 0.1.0-r1`。产品注册和兼容链接均指向同一产品清单。生产入口构建及类型检查通过；生产资源不引入设计宿主/mock。

## 阻塞项及保护现场

ARM 的升级前 mise helper 不探测网络；候选 helper 的 `istore_runtime_env` 会调用可选加速探测。`istore_runtime_url_available` 优先选择 GNU Wget 1.24.5，执行 `wget -q -T 3 ...`。`-T 3` 不是整个调用的总时限，默认重试/退避使不可用的 Node 镜像探测持续等待。现场镜像地址 `https://dl-node-unofficial.linkease.net:5443/index.json` 解析到本机，但未及时响应；curl 的总时限探测也未成功。

本轮实测旧 `mise-istore exec -- node --version`/`mise-exec` 在候选 helper 下不能在 30 秒内返回；单独的默认环境 helper 探测等待到 120 秒被外层 timeout 终止（124）。直接以原 HOME/XDG 调用 mise 则能执行 Node 24.20.0，表明 SDK 和默认版本未丢失。以上为本轮现场诊断记录；没有为补写证据再次运行无界网络探测。

已从 M4 安装前归档恢复 ARM `/lib/functions/mise.sh`，SHA256 为 `e34daa2ae450f044c58d42be3707ab5ee425aa84ce3bd24bb6f1586c17aeecde`，与旧基线一致。**ARM 包数据库仍为 r26，但这一文件已主动回退为旧版，因此当前设备不再是全文件与候选 IPK 一致的状态；这不是完成候选，也不能直接作为发布验收。** 其他新核心、页面、收据、SDK、配置均保留；没有回退或清理用户数据。x86 保留候选 helper，尚无原有 mise 业务需要恢复；同一可选探测代码风险仍需修复。

恢复后两个旧公开入口均在 15 秒上限内返回 Node 24.20.0，AgentFlow 健康接口返回成功。原有 iStoreEnhance/AgentFlow 二进制和 helper 旧基线校验通过，进程仍为 9766/6852。现有 AgentFlow 健康不等于已重新进行一次完整重启验收；本轮没有为这一项额外重启设备。

两台当前 `Runtime-live` 各保留一个实际 Node 24.21.0/glibc/npm 11.19.0 实例和私有 glibc 库；M3 的五实例测试根保留。两台工作目录为空、无安装锁；已销毁各三份本轮临时 rpcd 测试会话及本机私密会话文件。没有残留本轮构建容器。剩余可用空间约 x86 持久盘 59.9 GiB/overlay 1.84 GiB，ARM 持久盘 47.5 GiB/overlay 454 MiB；空间不是本轮失败原因。

## 后续续作的明确目标

下一次授权续作应首先修复旧 helper 可选加速探测：所有工具分支都有总时限且只尝试一次，不可用加速不能阻塞已有本地 SDK 的环境初始化/业务启动。增加不响应端点的回归，覆盖实际 GNU Wget 和 curl/缺工具分支，再用真实双架构包重新安装，去除 ARM 临时回退偏差，重跑旧公开入口、原有业务及最终包功能流程。M4 达成后才自动进入 M5，不再处理新的产品语义。
