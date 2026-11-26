# M7 x86_64 正常重启验收

结果：**192.168.30.7 正常重启及验收通过。** 本轮只操作该设备，未访问或重启 ARM64，M7 双架构整体验收仍保留 ARM64 重启待完成。

执行 `ssh root@192.168.30.7 reboot`，SSH 命令退出0；观测到SSH暂时不可达后恢复，启动标识从 `8c08d91f-949e-45b5-b277-e21c4575fec3` 变为 `a9a8d183-0027-42c4-96c9-a3ad1297672e`。未使用强制重启、重新安装或手动启动服务。

| 验收项目 | 实际结果 |
| --- | --- |
| 持久磁盘 | /dev/sdd 自动挂载 /mnt/mise-runtime，ext4，UUID f371c867-d169-436f-b560-58dc3f4f482d 不变 |
| 服务自动启动 | 本机 istoreenhance、OpenClaw Gateway 已由 procd 启动；没有人工启动/重启补救 |
| 既有固定入口/程序 | 非root UID65001/65002，两版Go、两版Zig，39项通过；既有程序、子进程、UID/项目/实例缓存路径仍正常 |
| 重启后新项目编译 | 两版Go1.26.10/1.27.4、Zig0.15.2/0.17.1真实执行编译、运行、C/C++、输出及缓存/固定策略检查，61项通过 |
| 加速状态 | runtime公共read返回gateway=true，与本机服务健康一致 |
| 真实网络与sumdb | 全新UID65005及客户端缓存，公开固定Go wrap→ks-cli→本机iStoreEnhance，11项通过；lookup/tile通过网关，没有直连sum.golang.org；保留TLS与GOSUMDB官方校验 |
| OpenClaw | Gateway专用非root身份、认证健康、OpenClaw自身loader加载sqlite-vec并完成邻近查询，12项通过 |
| 配置/绑定/默认 | 与重启前逐项SHA256/值比对一致 |
| 已部署源码 | 原直部署清单74个非配置文件的摘要/权限/归属审计通过，1个配置保留 |

AgentFlow在该x86_64设备重启前即未部署且9000健康检查不可用；重启后保持原基线，不将其写成“运行正常”。ARM64上的既有AgentFlow未操作。

证据为本目录JSON、Go模块/sumdb请求轨迹和前后基线。`verification.json` 汇总逐项通过情况。没有编译IPK/APK、修改包数据库或发布。此次为源码直部署功能验收，不替代后续人工安装包验收。
