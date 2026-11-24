# Go sumdb 的 KSpeeder 加速验证

后续更新：已按用户要求补齐 x86_64 本机 iStoreEnhance，双架构均不再依赖转发，并修复 runtime 服务状态误报。见 [本机服务续作报告](../M7-resume2/verification.md)。以下保留此前技术验证过程。

结果：**可以使用 KSpeeder/ks-cli，已在实际 x86_64 与 ARM 设备验证通过。** 仅解决并验证此次网络路径，不将 M7 的其余待验收项标为通过。

此前 x86_64 只有 ks-cli，没有 KSpeeder 常驻服务，M7 因而选择源站。`proxy.golang.org` 路径未能完成 sumdb 请求，Go 直接访问 sum.golang.org 时超时。ks-cli 本身是客户端；需要可用 KSpeeder 服务提供 Go 网关。

代码核对：`kspeeder-cli/internal/app/tool_command.go` 的 Go profile 设置进程级 `GOPROXY=https://dl-golang.linkease.net:<port>,direct`，保持原生完整性检查。KSpeeder 的 Go 路由包括 module metadata、artifact 和 `golang:sumdb`，代理 `/sumdb/sum.golang.org/supported`、lookup 和 tile 请求。配置说明见相邻 kspeeder 仓库的 `kspeeder/docs/router-backed-download-mirror.zh-CN.md`。

## 实际测试

| 项目 | ARM64 192.168.30.93 | x86_64 192.168.30.7 |
| --- | --- | --- |
| 服务 | 原有本机 KSpeeder | 经临时、鉴权、回环地址 SSH 转发复用 ARM 服务 |
| 客户端 | 原有正式 ks-cli0.9.1 + 公开固定 Go1.26.10 wrap | 相同客户端/版本和正式固定 wrap |
| 身份/缓存 | 全新 UID65003，独立持久 HOME/模块/sumdb缓存 | 全新 UID65003，独立持久 HOME/模块/sumdb缓存 |
| 模块 | github.com/google/uuid@v1.6.0 | 同一模块 |
| 校验 | GOSUMDB=sum.golang.org；无GONOSUMDB/GOPRIVATE/GOINSECURE绕过 | 相同 |
| 真实结果 | 11项通过，退出0，约2.519秒 | 11项通过，退出0，约1.737秒 |

这是一次小模块、冷客户端缓存验证，不是受控速度基准，也不宣称服务器端缓存未命中。计时包含应用 HOME 准备、环境查询、下载和 verify，并非纯传输耗时。

Go `-x` 记录中，supported、lookup、tile 均访问 `https://dl-golang.linkease.net:5443/sumdb/sum.golang.org/...`，未直连 `https://sum.golang.org/`。下载返回模块和 go.mod 的 `h1:` 校验值，写入项目 go.sum；后续 `go mod verify` 输出 `all modules verified`。Go 在启用官方 checksum database 的前提下完成正常签名/哈希校验，没有为测试关闭 TLS、sumdb 或原生校验。

证据：`*-go-accelerated.json`、`*-download.stderr.txt`、`*-download.stdout.txt`、`*-verify.stdout.txt`。

直接通过 x86_64 访问 ARM 的 TLS 网关得到403，ARM 本机相同路径得到200，TLS验证结果均为0。保留这两个初始探测 `*-sumdb-route-probe.json`。本次通过鉴权 SSH 回环转发遵守该本机访问约束，没有放宽网关访问限制。

转发路径：x64 127.0.0.1:5443/5003 → 开发机回环35443/35003 → ARM 127.0.0.1:5443/5003。结束时所有本任务 SSH 进程已退出，开发机端口和 x64 转发端口已释放；原 ARM 服务继续健康。两机 `/etc/config/mise`、`istoreenhance`、`agentflow` 存在性及 SHA256 未变。见 `tunnels.json` 和逐项报告。

## 后续正式环境

建议在 x86_64 上准备可用 KSpeeder 服务，固定运行时入口通过 `ISTORE_RUNTIME_ACCELERATION=ks-cli` 选择加速。UI 检测到服务可用后可启用加速；Go 版本、HOME/缓存和全局默认不随下载通道改变。保持 GOSUMDB 默认官方数据库。

本次没有永久安装 x64 服务或改变其全局配置；临时转发仅用于验证。M7 剩余的普通用户完整矩阵、页面和重启检查仍待继续。测试脚本：`apps/mise/tests/go-accelerated-device.lua`、`go-accelerated-tunnel.py`。再次运行需使用新的专用 UID/目录，不能覆盖已存在的本次探测目录。未编译 IPK/APK，未发布。
