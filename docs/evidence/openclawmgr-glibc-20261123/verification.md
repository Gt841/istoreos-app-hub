# OpenClawMgr 私有 glibc 验收（2026-11-23）

用户追加目标：参考 baidudrive/open-drive，让 Node/npm/OpenClaw 全链路使用隔离 glibc，并要求 sqlite-vec 生效。先前允许向量扩展缺失的标准已撤销。

## 结论

源码已实现私有 glibc、正确选择 GNU npm 原生依赖及向量硬检查。**设备验收部分通过，不能宣称两个架构均完成。**

| 设备 | 实际结果 |
| --- | --- |
| x86_64 192.168.30.7 | 从旧 musl 升级成功并提交；独立认证 Gateway health OK；服务 UID 998 调用 OpenClaw 自带加载器和 vec0 最近邻查询成功；缺失扩展拒绝启动及恢复后的公开 restart 通过。 |
| ARM64 192.168.30.93 | 最终候选完成 npm 安装、原生向量查询及 CLI 检查；Gateway 日志确认监听，但安装器 health 未通过，事务自动回滚 exit=1。独立 UID 999/fork 向量查询另行通过。不能作为完整 Gateway 验收通过。 |

最后根据 ARM 结果将 health CLI 总时限从每次 10 秒调整为 60 秒，最多 3 次；增加真实延迟 11 秒回归。
**此最后的健康时限修正仅经本地回归，未再次执行设备完整安装。** 两台设备通过项对应修正时限之前的部署版本；其余 glibc/npm/vec 源码与最终版本一致。

## 实现及来源

- 新增 openclawmgr-glibc 包，按架构下载 SHA256 固定的 Ubuntu libc6 2.39-0ubuntu8，组合已发布 baidudrive-runtime-v1.0.6 的 libgcc/libstdc++。不依赖设备 apt/Docker，不修改系统 /lib 或 loader。
- 安装到 /usr/share/openclawmgr-glibc；每个候选 Node 复制独立 loader/libraries 和清单。复用 Node 时更新候选运行库，旧 release 保留自己的库以便回退。
- 固定官方 Node 24.22.1，bin/node 通过私有 ld.so --library-path 执行 node.real。预加载修正 process.execPath，npm 生命周期、fork、CLI、procd 均经过相同入口，移动候选目录后仍有效。不向宿主 sh/git/ks-cli 注入全局 LD_LIBRARY_PATH。
- npm-install-checks 优先读取宿主 /usr/bin/ldd；仅切换 Node 仍会误选 musl optionalDependencies。因此入口和共享 npm 环境强制 npm_config_libc=glibc。
- sqlite-vec 必须加载并返回版本、建立 vec0 表、插入向量和返回正确最近邻。安装及新 managed release 的 init 启动均执行硬检查。保留原事务、快照、current/previous、取消/恢复。
- 同一待发布 meta release 保持 3，不重复增加。

旧 x86 glibc 2.36 运行固定 Node 时 SIGSEGV；open-drive 本地 1.0.7 的 2.39 探测成功，但其整包发布 URL 为 404，故使用上述可下载、固定摘要的 Ubuntu 包。真实 package Prepare/install 解包复制命令已对两个架构执行，输出与部署内容逐字节一致。SDK include 宏使用夹具，这不是完整 SDK ipk 构建。

## 最多三轮检查记录

| 轮次 | 发现、处理与结果 |
| --- | --- |
| 1 | x86 源站 Matrix 依赖下载慢触发每条命令 900 秒超时，exit=124，旧 Gateway PID 21947/health 保持。ARM 首次完整安装时设备重启；正常 recover_install 恢复 preparing 事务 exit=0。 |
| 2 | x86 热缓存安装被 Sharp 硬检查拒绝，定位为宿主 ldd 导致选择 musl 产物；未切换旧服务。ARM 进行 Node/glibc/vec、非 root UID 和 fork 轻量探测，均通过。修正 npm libc 选择并增加回归。 |
| 3 | x86 最终候选成功提交并完成下述全链路检查。ARM 仅追加一次最终配置完整安装：npm/GNU Sharp/vec/CLI 通过、Gateway 监听，但 health 失败自动回滚；随后修正短时限并做本地延迟回归，不再全量重试。 |

ARM 首次 reboot 的 boot ID 从 f039b600-93fd-4760-ac6c-a5c6e9e70867 变为 15109b6a-9070-49ea-88e0-6ba2e17a5545；日志有 SQUASHFS 读取错误，但没有确定的 panic/OOM 根因，未执行 reboot。最终配置的第二次完整安装及清理期间 boot ID 一直保持后者，不能将之前重启归因于或声称被本次修改修复。

## x86 详细证据

第三次升级于设备时间 13:59:32 提交，release=20261123134634-OKKpAM，exit=0。收据记录实际 glibc 2.39、sqliteVec available=true/version=v0.1.7/nearestNeighbor=true，Sharp 基本功能与 node-pty 加载成功。previous 中旧 Node 实际 report 为 musl。

真实 Gateway 以 UID 998 运行，独立认证 health OK。同一 UID 调用 OpenClaw 发布包自己的 requireNodeSqlite/loadSqliteVecExtension，返回 ok=true；vec0 查询 rowid=1、distance=0.141421377658844。见 x86_64/54-committed-gateway-and-openclaw-vector.log。

移走真实 vec0.so 后 init 未注册 Gateway 实例；恢复原 SHA256 字节后重新启动。OpenWrt rc.common 外层仍返回 0，因此负面判据是“没有运行实例”，不声称 init 外层非零。公开管理入口另有 health 门禁；恢复后的管理器 restart exit=0、health OK，并再次由服务 UID 完成 OpenClaw 自带加载器查询。见 x86_64/56-missing-vector-startup-refusal.log、57-restored-vector-manager-restart.log。

memory status --json exit=0，backend=builtin/provider=none/vector.enabled=true；未配置 embedding provider，不声称端到端语义记忆检索通过。

## ARM 详细证据

独立官方 Node/glibc 2.39/sqlite-vec 0.1.7 在实际 UID 999 下和 child_process.fork 子进程中均返回正确最近邻，目录移动后仍通过。直接解包探测最初出现的 cwd/文件权限问题已修正；生产 npm 产物读取权限另行确认正常。

最终安装 14:13:21 启动，14:26:03 原生检查通过，14:26:04 CLI 通过，14:26:06 激活。npm 正确获取 GNU ARM Sharp/libvips。syslog 14:26:33 确认 Gateway 监听 19189；14:28:32 health 失败并发送 SIGTERM，14:28:39 回滚结束 exit=1。见 arm64/74-arm-gateway-process-state.log、76-postrollback-tree-log.log、final-installer.log。

每次 health 命令最多 10 秒、没有输出，慢设备 CLI 冷加载超时是当前判断，未取得独立认证 health 成功，不能把监听日志替代认证探测。源码已改为每次 60 秒、3 次有界重试，并有 11 秒响应回归，但设备效果仍待验证。失败候选由正式回滚流程清除，没有手工改指针或补依赖制造成功结果。

## 本地检查与边界

最终默认 shell/BusyBox 回归结果见 regression-final.json；静态检查见 static-checks.json，最后时限修正复查见 final-followup-checks.json。真实 Prepare/install 命令输出见 package-recipe-check.json。

测试仅使用用户授权 .7/.93、独立目录和 loopback 19189，无模型密钥。x86 使用源站 npm，ARM 使用既有 KSpeeder/ks-cli，没有替换或停止其服务；Node 归档在开发机预置、安装器再次核对 SHA256，不声称验证了完整 Node 加速下载链路。没有付费模型调用。完整 SDK ipk 构建、浏览器 ACL/CSRF/UI、Matrix 频道、PTY 交互会话和语义 embedding 检索均未列为通过。未提交、推送或发布。

两台测试服务、账号及五项临时系统路径均恢复基线，19189 端口与安装锁已清空。测试日志/数据保留在各设备 Configs/openclawmgr-glibc-acceptance-20261123 私有目录。ARM KSpeeder 三项保护文件摘要一致且仍运行；本阶段未安装 opkg 包，保留前一阶段已记录的 timeout/Git 依赖。见 x86_64/59-final-restoration-verification.log、arm64/79-arm-final-restoration-verification.log。
