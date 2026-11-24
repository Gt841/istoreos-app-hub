# M7 本机 iStoreEnhance 加速环境修正

本轮按用户明确的产品前提执行：runtime 经 ks-cli 使用本机 `istoreenhance`（KSpeeder），不是独立部署另一个产品，也不是只装 ks-cli 即算准备完成。

## 任务与验收

1. 补齐 x86_64 本机 iStoreEnhance：使用包 Makefile 固定的官方 0.9.1 归档及 SHA256，直部署二进制、仓库 procd 脚本和测试配置；不编译包、不改包数据库。缓存位于持久测试盘。
2. 两架构使用相同的显式 ks-cli 下载策略，不按架构回退源站，不依赖跨机隧道。
3. 新 UID/客户端缓存下，固定 Go wrap 真实下载模块、通过 sumdb 网关并完成原生校验；保留 TLS 与官方 checksum database。继续完整 M7 矩阵，单独记录剩余验收。

## 本机加速检查已通过

| 项目 | x86_64 | ARM64 |
| --- | --- | --- |
| 服务 | 新增本机 iStoreEnhance0.9.1，procd 启用 | 保留既有本机 iStoreEnhance |
| 全新用户 | UID65004 | UID65004 |
| 固定 Go | 1.26.10 | 1.26.10 |
| 模块 | github.com/google/uuid@v1.6.0 | 相同 |
| 实际检查 | 11/11，约1.038秒 | 11/11，约2.130秒 |
| sumdb | dl-golang网关 supported/lookup/tile，无直接 sum.golang.org 请求 | 相同 |
| 完整性 | GOSUMDB=sum.golang.org，模块与go.mod的h1值、go.sum、go mod verify通过 | 相同 |

这是全新客户端缓存的小模块正确性检查，不是服务器冷缓存性能基准。没有 SSH 端口转发或复用另一台设备的服务。原 mise/AgentFlow 配置不变；x86 新增 istoreenhance 配置是本次明确的环境准备动作。加速入口按进程显式选择，不改全局默认版本。

`x64-istoreenhance-deployment.json` 记录官方归档 SHA256、每个目标文件 SHA256/权限和回滚命令。三个文件部署前均不存在，拒绝覆盖任何既有安装。后端运行在 `/usr/sbin/iStoreEnhance`，服务为 `/etc/init.d/istoreenhance`；测试缓存和回滚材料在 `/mnt/mise-runtime/acceptance/M7-local-istoreenhance`。此步骤没有复制软件中心或页面资产，不声称已完成安装包依赖/归属验收。ARM 的现有安装未升级、未重启。

证据：`*-local-go-accelerated.json`、`*-download.stderr.txt`、`*-download.stdout.txt`、`*-verify.stdout.txt`。前一轮临时回环转发只用于验证技术可行性，其历史记录保留于 M7-resume1。

## M7 其余项目

已将 `native-device.lua` 中“ARM ks-cli / x86源站”的分支改为两机都显式 ks-cli；不把本地编译或版本查询送到加速服务。完整非root Go/Zig 已在两机各通过61项。新一轮页面检查两架构各Go/Zig各5项已通过，重启验收待完成；未将 M7/M8 标记完成。历史三次失败保持原始记录，本轮为用户再次明确本机加速前提后的续作第1轮。


## 第2轮：修复加速服务状态误报

真实设备回归显示：两台设备本机服务健康、下载加速通过，但公共 runtime read 返回 gateway=false。根因是 `status.lua` 使用 `nixio.exec("curl",...)`，该接口不搜索 PATH，相对命令返回127。已改为包依赖保证存在的 `/usr/bin/curl`，保留回环地址、禁用调用者 curl 配置/代理和1秒探测上限。

新增 `acceleration-status-device.lua` 先在原代码上验证失败（本机服务健康且read退出0，但gateway=false），更新后两机都返回gateway=true。证据为 `*-status-regression-red.json` / `*-status-regression-green.json`。不是放宽健康检查或伪造可用状态。

同步发现原浏览器测试只用 selectOption 选加速，即使选项被禁用仍可能设置值，不能证明普通用户能选择。现已增加真实选项 disabled=false 断言，旧页面记录只保留为历史、不作为这一点的验收；新检查结果保存到 `ui-*-opt2`。

本轮源码直部署每机75个文件，实际更新status.lua 1个，73个未变，已有配置1个保留；74个非配置文件逐项SHA/权限/归属审计通过。未新增发行版本号：本次未提交候选中已有 release 增量覆盖这次更新。未编译包、未发布。


第2轮真实页面复验已完成：`ui-x64-go-opt2`、`ui-x64-zig-opt2`、`ui-arm64-go-opt2`、`ui-arm64-zig-opt2` 各5项通过。每次实际操作先确认加速 option 未禁用，再选 ks-cli 完成正式任务重装；检查固定wrap、SDK实际编译/执行探测、其他运行时与默认项不变、手机深浅主题。SDK归档已缓存，本页面步骤不冒充新网络下载；真正的模块/sumdb网络路径另由UID65004冷客户端缓存记录证明。临时LuCI会话均已销毁，浏览器已关闭。

剩余：M7正常重启后的固定入口、缓存/服务与业务复测。M8尚未执行。本报告只标明已取得的源码直部署证据，不声明整个M7或M1–M8完成。

页面重装结束后，两机固定入口正向复验各39项通过，OpenClaw Gateway/内置sqlite-vec回归各12项通过（`*-native-after-ui.json`、`*-gateway-close.json`）。没有遗留本任务浏览器、LuCI会话或SSH转发；新增本机 iStoreEnhance 按本次环境准备要求继续由procd管理。


后续重启验收：x86_64已正常重启并通过固定入口、重新编译、加速/官方sumdb及Gateway/向量回归；见 [M7-reboot-x64-20261124T100547Z](../M7-reboot-x64-20261124T100547Z/verification.md)。用户本轮要求只操作x86_64，ARM64重启继续待完成。
