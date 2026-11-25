# 公共运行时 Interface v1（M1）

状态：M1–M3 的契约、核心事务和实际 Node/npm 验收已通过。正式系统包、LuCI 和业务接入由后续里程碑完成。

## 所属与引导

- `mise`：固定上游 musl 管理器及旧 mise-istore/mise-exec/环境函数兼容。
- `mise-runtime`：Lua 5.1 + luci-lib-jsonc/luci-lib-nixio 及宿主下载/归档工具；自身不依赖 Node/Python，不依赖管理页面。拥有 CLI、数据目录规则、任务、SDK/库收据、wrap 和产物锁。
- `luci-app-mise`：生产 Vue 构建、LuCI 认证模板/动作入口、产品资产与应用注册；不会交付设计宿主。认证请求经校验后调用公共 CLI，不能提交任意 shell。
- `app-meta-mise`：软件中心元数据及依赖，不持有运行时、产品清单或 Web 副本。
- OpenClaw：依赖 mise-runtime，不强制安装 mise 管理页面；OpenClaw 包、应用数据、专用 UID、Gateway、sqlite-vec 检查属于自身。

Lua JSON 库是宿主工具依赖，不意味着核心依赖新的 Vue 页面。设备已探测这两个 Lua 库可用；本机测试适配 cjson 不进入生产包。

## 配置与布局

旧 `/etc/config/mise` 的 `runtime_dir` 永远保持 HOME 含义。新增 `storage_root` 表示公共管理器根目录，不能把旧 HOME 当根再追加 home。`mise-istore`、`mise-exec` 和 AgentFlow 使用的 `istore_runtime_env` 优先保留显式 `runtime_dir`；未配置时使用 `<storage_root>/home`，两者都没有时拒绝执行，不回退继承的 `/root`。首次旧入口初始化仍可参考 QuickStart 的 Configs 目录，默认 `Configs/Runtime/home`。用户显式配置新根后，只建立新目录；不自动搬移、修改、接管或清理旧 SDK/HOME。

存储选项统一为 `/mnt/<硬盘>/Configs/Runtime`，与 AgentFlow 原有 Runtime 目录兼容；可自定义其他规范目录。`read` 的 `storage_paths` 枚举直接挂载在 `/mnt` 下、可读写且可执行的持久块设备，保留当前自定义根；`storage_default` 优先参考 QuickStart 的 `conf_dir`，不回退系统 `/root`。枚举不创建目录。`storage_locked` 表示已有环境或当前根离线，不允许直接改路径；固定 wrap 和应用绑定含绝对路径，不提供自动迁移。目录尚未配置时，建议值只填入表单，用户保存后才初始化。

```text
<storage_root>/
  home/                        mise 管理及 root 默认 HOME（显式传入子进程）
  libraries/<library-id>/        私有 loader、C/C++ 库、摘要和来源
  environments/<instance-id>/  不可变 SDK、私有启动器、receipt.json
  wrap/<instance-id>           管理器生成的真实固定使用入口
  mise/<arch>-<abi>/           管理器专有登记；链接到同一个 SDK
  users/<uid>/                非 root 用户 HOME/XDG/缓存；管理器按 ABI 隔离的配置
  tasks/<task-id>/             持久阶段日志与恢复记录
  plans/<plan-id>.json         绑定状态修订与精确产物的短期计划
  cache/                      可重下、可校验的归档
```

配置根只接受规范的 `/mnt/...`，不允许空格、回退、重复分隔符、控制字符；应用自己的 HOME/venv 按独立路径协议验证，不能由根路径约束误删此前认可的引号/空格支持。语法校验之外，M2 对实际挂载身份、路径解析/符号链接、权限、只读/noexec、容量/inode 实施检查。

共享 SDK 和库只有管理器可写；应用 HOME 不重新分配给公共服务。路径离线时在 mkdir 之前失败。有已安装环境不能直接修改根；暂不提供自动磁盘迁移。

## 身份与收据

产物清单项锁定 tool/version/build/arch/abi、全部 URL/SHA256、归档布局、配套 npm；`artifact_set` 为其产物数组排序键 JSON 的 SHA256。Java 版本包含 Temurin 厂商与完整构建号；Rust 为 minimal 的组件集合。维护工具生成 catalog revision；路由器不解析 latest。

实例 ID 由工具、完整版本、架构/ABI、构建、独立 npm（如有）、运行库实例（GNU 时必填）及完整 artifact_set 摘要组成；同 Node 配不同 npm 或库修订产生不同实例。实例路径长度由契约限制；不得截断或以显示版本覆盖已有实例。

`receipt.json` schema_version=1：包含完整清单项、实例、实际 npm、library、artifact_set、时间、根、精确 mise_key、verified 和 probes。只有版本/架构/ABI/launcher 必选探测全部 passed 才能标 verified；各语言和应用追加的探测必须在相应提交门槛中完成。配置文件的 verified 字段不是防篡改认证；M2/M3 的可信目录、摘要和实际重查构成使用门槛。

应用 release 的 `runtime.json` 只保存 schema_version、instance、artifact_set、library、receipt_sha256。应用选择精确实例，不读取全局默认；不建立中央应用表或调用遥测。删除环境时不宣称无人使用；保护已知默认和被环境引用的库，按产品提示显式删除其他实例。

## 命令与错误

建议入口 `/usr/sbin/mise-runtime`；公共查询/变更采用一个 JSON 请求及 JSON 响应，固定执行采用结构化 argv。CLI 不接受 shell 源码或 eval 表达式。

| 操作 | 输入 | 结果 |
| --- | --- | --- |
| read / catalog | op | 真实状态/受控产物目录 |
| plan | entry、可选 npm、明确 source=origin/ks-cli | 复核计划；不安装 |
| submit | 计划 id | 持久任务 id，不能据此宣称成功 |
| inspect / wrap | 实例 id | 收据/实际脚本 |
| cancel / recover | 任务 id | 安全取消/中断恢复结果 |
| remove / library-remove | 实例/库 id | 删除检查与结果 |
| cache-clear | op | 只清理可重建缓存 |
| settings | path、布尔 acceleration | 验证后的配置 |
| prepare-user | 数值 uid、可选 gid | 管理员预置该 UID 的私有持久 HOME |

每个操作拒绝未知字段；不接受全局默认切换、应用版本修改、pip 版本选择或任意下载 URL。执行入口使用 `exec <id> <工具> [argv...]` 或安装后的固定 wrap，工具按语言白名单分派，不走 JSON command 字符串。前端响应按动作区分 state/plan/task/receipt/text/error，移除原型中把所有 value 误约束为 Plan 的类型。

mise 管理的 link/where/默认查询和 root 默认 wrap 显式使用 `<storage_root>/home`；mise 数据及配置继续按架构/ABI 隔离，避免原有全局工具与固定 SDK 混用。普通 UID 的默认目录由管理员先通过 prepare-user 预置在 `users/<uid>/home`；应用也可提供自己拥有的 ISTORE_RUNTIME_HOME。普通 UID 和 OpenClaw 不共用管理员 HOME。HOME/XDG/state/npm 前缀/cache/TMP 都位于持久分区。可访问项目工作目录保持不变，仅在继承了无法访问的工作目录时转入自身 HOME。旧 `users/0/home` 的内容不会自动搬移或删除；显式引用它的应用仍可继续使用。

旧 ks-cli 的非秘密端口配置保存在管理器 network/uci 目录，只有其五个只读查询使用该视图；原系统 UCI 权限、其他查询和修改操作不变。保存运行时设置会刷新此配置；不复制 KSpeeder 凭证，不提高调用者权限。

计划锁定实例、catalog revision、存储根和状态 revision，生命期最多 300 秒；过期、状态或目录修订改变时重新复核，不能自动重放旧计划。M2 对目录及磁盘状态再次校验。

响应 schema_version=1；成功 `ok=true,value=<操作结果>`，失败 `ok=false,error={code,message,phase?,task_id?}`。失败使用稳定代码（INVALID_INPUT、UNSUPPORTED、OFFLINE、NO_SPACE、BUSY、STALE_PLAN、INTEGRITY、PROBE_FAILED、INTERRUPTED），CLI 同时非零退出。日志不能含模型密钥/token。

## mise 登记和生产数据

在管理器独立 MISE_DATA_DIR/CONFIG_DIR/CACHE_DIR 下，用确切 `istore-<instance-id>` 键登记已有 SDK；每种语言分别验证 link/where/exec 行为和必要环境变量。应用/普通用户执行固定 wrap；即使工作目录存在 mise.toml 或项目工具链文件也不静默换版本。不得借登记再下载另一份 SDK、修改旧 HOME 中的全局默认或调用不加版本的 mise use。

固定 mise 2026.8.14 的 core:rust 会在登记/解析过程中调用 rustup；Rust 使用 `http:istore-rust@istore-<instance-id>` 通用后端链接同一 SDK，配套环境由固定 wrap 管理。其余语言使用已分别验证的内置登记键。通用后端不接收安装 URL，不用于自动更新或远程安装，SDK 的唯一管理者仍是公共安装器。

目录记录 upstream availability，不代表 device verified。安装器/正式页面额外使用已验收的语言/架构/ABI 能力；未启用能力给原因，未知值保持未知。容量由真实 statfs/测量得到，配套 npm/pip 由实际 SDK 探测；不把示例版本/大小或 Python ensurepip 源码推断当设备收据。

M1 的 mise 登记探测使用无网络的小型假 SDK，只证明固定管理器的登记/查询/执行协议；M3/M6–M8 仍必须使用实际 SDK 验收。


## 旧入口与 ks-cli 加速兼容

`mise-istore`、`mise-exec` 的环境初始化只准备持久 HOME/XDG/PATH，不探测网络，也不再写入旧镜像替换变量。本地 `exec`、版本、查询和交互 shell 不要求 KSpeeder 可用。

`mise-istore install|i|upgrade|up|ls-remote|latest|outdated ...` 在 `mise.main.acceleration` 启用、ks-cli 可用且没有显式镜像变量时，直接转交 `ks-cli mise ...`，保留参数、stdin 与退出码。服务就绪、能力与下载完整性由 ks-cli/原生 mise 负责；不在 helper 重复探测。未启用加速或缺少可选 ks-cli 时，旧入口执行原生 mise。用户显式设置 `MISE_NODE_MIRROR_URL`、`MISE_GO_DOWNLOAD_MIRROR` 或 `MISE_URL_REPLACEMENTS` 时也保留原生语义。

上述自动路由识别入口的首个 acquisition 子命令；带前置全局选项或其他远端操作可显式使用 `ks-cli mise ...`，并自行保证持久环境。普通 `mise-exec` shell 中可调用 `mise-istore install ...`。不将全部命令一律包装为 `ks-cli mise`：当前 0.9.1 会对 `mise exec` 协商服务，不能让已安装的本地应用依赖加速服务健康。

公共固定实例的安装下载和 npm/git wrap 已分别使用 `ks-cli download`、`ks-cli npm/git`，不经过这一旧入口；其显式加速策略不因旧入口可选兼容回退而改变。

加速服务在 iStoreOS 上由 `istoreenhance` 提供（其后端就是 KSpeeder）；`ks-cli` 是客户端，不是另一个常驻服务。默认加速路径为固定 wrap/安装器 → ks-cli → 本机 iStoreEnhance → 支持的上游。加速验收须同时具备客户端和健康且能力匹配的本机服务，两种架构采用相同策略，不能因服务缺失而静默切换源站。用户明确选择源站的能力保留。

Go wrap 对 `go get`、`go mod download` 接入 `ks-cli go`；Go proxy 的 module 与 sumdb 请求一起经网关，保留 `GOSUMDB=sum.golang.org`、原生签名/哈希和 TLS 检查。版本查询、已安装应用运行、离线编译仍直接执行固定 SDK；加速不改变版本、HOME、缓存隔离及全局默认，也不宣称加速编译。


## 管理进程以普通 UID 执行固定实例

`/usr/share/mise-runtime/native/bin/exec-user UID GID INSTANCE COMMAND [ARGS...]` 仅 root 可调用，文件没有 setuid 位。它清除附加组、设置正数的非 root UID/GID，然后原进程 exec 到公开的 `mise-runtime exec`；不新建会话、不拼接 shell，保留参数、stdin、信号和退出码。调用者必须准备目标 UID 的持久 HOME，并明确 `MISE_RUNTIME_ROOT`/`ISTORE_RUNTIME_HOME`。此入口不向 LuCI 请求白名单开放。
