# OpenClawMgr (openclawmgr)

## 交互/操作设计

目标：所有“长耗时/可失败”的操作都通过 `taskd` 运行，并在 LuCI 中弹出日志窗口（xterm），执行期间禁止并发启动其他任务。

### 操作分层

- **主流程（常用）**
  - `安装`：验证 Node 与 OpenClaw 候选后部署、生成配置；默认不启用服务
  - `升级`：验证候选后切换；保留原运行状态，启动失败恢复旧运行时与数据快照
  - `启动/重启/停止`：服务控制（必要时联动 enabled）
- **高级（危险/低频）**
  - `卸载`：移除运行时（保留数据目录）
  - `清理（含数据）`：移除运行时 + 删除数据目录

### 日志策略

- **任务日志（taskd）**：每次点击操作都创建/复用 `task_id=openclawmgr`，立即弹窗追踪 `/var/log/tasks/openclawmgr.log`。
- **安装器日志（installer.log）**：`${base_dir}/log/installer.log` 持久保存阶段和退出状态；完整命令输出在 taskd 日志中。LuCI 可“一键查看”安装器日志（只读）。

### 并发控制

- LuCI 侧：操作按钮点击后立即禁用，直到 taskd 返回任务结束。
- 系统侧：依赖 `taskd` 自身锁机制（`/etc/init.d/tasks task_add ...` 返回非 0 表示已有任务在跑）。

### Save & Apply（配置应用）

- `Save & Apply` 不直接在 LuCI 进程内执行重启，而是通过 taskd 创建 `task_id=openclawmgr` 任务去执行：
  - `"/usr/libexec/istorec/openclawmgr.sh" restart`
- 页面加载时如检测到 `openclawmgr` 任务在运行，会自动弹出 taskd 日志窗口。

## 依赖

- `luci-lib-taskd`（含 `luci-lib-xterm` 与 `taskd`）、curl/CA、tar/xz、jsonfilter、Git HTTPS、ttyd。
- `ks-cli` 使用现有 OpenWrt 软件包；不运行普通 Linux 的 ks-cli/zsetup 安装器。
- `openclawmgr-glibc` 提供私有 GNU libc 2.39；`coreutils-timeout`、`coreutils-stat`（读取 inode）及现有 libstdcpp/libatomic；系统 BusyBox 需提供 `setsid`。
- 开启安装加速时需要已启用的 `istoreenhance`；缺少或关闭时明确报错，可关闭安装加速后使用源站。

## 安装事务

实现目标、任务树及最多三轮检查记录见
[`../../docs/plans/openclawmgr-installation.md`](../../docs/plans/openclawmgr-installation.md)。

1. 安装和升级都检查持久目录、架构、libc、空间和 inode。默认预留 2 GiB 工作空间，
   另外计算现有 data 快照所需空间；至少需要 30000 个可用 inode（不报告 inode 总量的文件系统除外）。
2. Node 固定为官方 24.22.1，覆盖 x64/arm64，URL 和 SHA256 维护在 `node-pins.sh`。
   两种固件都使用私有 glibc 2.39：`openclawmgr-glibc` 安装基础库到
   `/usr/share/openclawmgr-glibc`，安装器校验清单后复制到候选 Node 目录；每个 release 独立保留库。
   不复用系统 Node 或旧 musl Node。已有管理器 glibc Node 必须通过清单、版本、平台和 SQLite 检查
   才可复用；不满足 engines 时尝试固定 Node，仍不满足则保留原安装并报错。
3. stable 仍是 `openclaw@2026.3.28`；latest 只解析一次。校验目标 engines，
   按精确版本 `npm pack`，再独立核对包名、版本及 SHA512，随后安装本地 tarball。
   依赖包仍由 npm 使用其完整性元数据验证；不声称仅锁定顶层版本就锁定了整个依赖树。
4. 候选在 `${base_dir}/.install.*/candidate` 安装，使用独立 HOME 做 CLI smoke。
   sharp（目标包声明时）执行基本功能检查；sqlite-vec 必须加载成功，实际执行 `vec_version()`、
   建立 vec0 表、插入向量并验证最近邻查询。缺少扩展不再允许降级通过安装。
   node-pty 执行加载检查；已核对的 2026.3.28 仍允许其普通子进程回退，并明确记录 PTY 不可用。
   Gateway 健康不等同于 Matrix 频道、PTY 交互或模型推理的端到端验证。
5. 候选验证期间旧服务继续运行。切换前先停止服务并确认停止，完整备份 data 到
   `backups/事务ID/data.tar`。然后切换 `current`，生成配置，按需启动并检查 gateway health。
   health CLI 为慢设备冷加载预留每次 60 秒、最多 3 次，失败仍回退。
6. 失败时恢复旧入口和 data 快照，失败候选写入的数据保存在同一备份目录的
   `failed-data`。回退失败保留事务日志和锁；恢复可再次尝试。成功升级保留 `previous`。
   配置写入使用临时文件和 rename；备份目录为 0700，配置文件为 0600。

运行时目录：

```text
OpenClawMgr/
  current -> releases/事务ID
  previous -> releases/上一个事务ID
  node -> current/node
  global -> current/global
  releases/事务ID/{node,global,receipt.json}
  # node/bin/node 为入口；node/bin/node.real 为官方 ELF
  # node/glibc/ 保存该 release 独立的 loader、库和校验清单
  data/
  npm-cache/
  backups/事务ID/{data.tar,failed-data/}
```

旧版本的 node/global 实体目录在停服后迁入独立 legacy release，继续通过原路径使用。
记录 `current/receipt.json` 包含精确版本、engines、npm、平台、包完整性、Node 来源/摘要、
原生模块能力及安装时间；`runtime` 记录 isolated-glibc、实际 glibc 版本和库清单 SHA256。复用 Node 时记录实际可执行文件 SHA256，不把它说成重新验证了原始归档。
历史 releases 和成功备份不自动删除，需运维确认后清理；卸载运行时保留 data 和备份。
“清理（含数据）”会删除这些内容。

## glibc 启动链路

已有 musl 安装在更新插件后，需要在界面执行一次“升级”来迁移运行时。单独更新插件或运行库包
不会重写正在使用的 Node；每次运行时升级才会将当前包内的库复制到新 release。

参考 baidudrive/open-drive 的私有 loader 方案，不修改系统 `/lib` 或 loader 链接。
`node/bin/node` 通过该 release 的 `glibc/ld.so --library-path ...` 执行 `node.real`。
预加载的 `node-loader.cjs` 让 `process.execPath` 指向同一入口，npm 生命周期脚本、
`child_process.fork`、终端 CLI 与 procd 因而使用同一 glibc Node。不给宿主 sh/git/ks-cli
设置全局 LD_LIBRARY_PATH。npm 自身优先读取宿主 `/usr/bin/ldd`；入口与进程级策略
显式设置 `npm_config_libc=glibc`，保证 Sharp 等 optionalDependencies 选择 glibc 产物。

`openclawmgr-glibc` 的下载源及 SHA256 固定在其 Makefile：Ubuntu libc6 2.39-0ubuntu8
（按架构下载），加上已发布 baidudrive-runtime-v1.0.6 中的 GCC C++ 库；只安装运行库，不安装 SDK。
包的 Prepare/install 命令可独立核对；无需设备运行 apt 或 Docker。
启动新的管理器 glibc release 时，procd init 再次检查运行库清单和向量功能，失败则拒绝启动。
旧 musl/legacy 布局保持可启动，以支持升级失败回退。

## 加速与脚本策略

- Node 下载使用 `ks-cli download --mode auto`，管理端口读取 OpenWrt UCI；关闭加速走 HTTPS 源站。
  下载及其 sidecar 放在事务私有目录，取消一并清除；解压不继承归档中的用户 ID。
- npm 的查询、打包和安装显式使用 `ks-cli npm`，服务 readiness、能力和 TLS 端口由 ks-cli 处理。
  依赖安装使用 prefer-offline 复用持久缓存，缺失内容仍联网获取；版本解析和独立完整性校验照常执行。
- npm 的 Git 子进程通过 `npm-git.sh` 显式调用 `ks-cli git`，关闭加速则调用原生 Git。
  支持的 GitHub HTTPS 读取由 ks-cli 加速；SSH、私有源和其他平台保留 ks-cli 的原生语义，
  不写用户 Git 配置、不擅自改写 SSH 鉴权方式。生命周期脚本自发的 HTTP 下载不保证被覆盖。
- 不再因 musl 全局设置 ignore-scripts。npm 11.16+ 对顶层 OpenClaw 显式添加 allow-scripts；
  必要原生模块仍须通过实际检查。缺少平台产物时失败并保留旧服务，不自动在路由器安装编译工具链。
- LuCI 交互终端通过 npm shim 复用上述进程级策略；shim 在交给 ks-cli 前移除自身 PATH，避免递归。
  用户手动升级 OpenClaw 会绕过管理器事务，并可能因收据版本不一致而被启动检查拒绝；
  使用界面“升级”可保持收据一致并获得回退保护。

## 取消与恢复

取消先给安装协调进程发送 TERM，协调者终止并等待自己的子进程组，再回退和清理。
LuCI 仅在协调者清理完成后删除 taskd 状态；不强杀协调者，也不提前移除锁。
有异常中断的事务时，后续安装会要求先恢复：

```sh
/usr/libexec/istorec/openclawmgr.sh recover_install
```

恢复失败时保留日志并返回非零，不删除恢复证据；空配置不阻断恢复入口，恢复前先检查备份
归档。缺失/无效归档不会触发停服、指针切换或 data 移动。事务文件不完整、多个中断日志或磁盘故障
需要人工检查；本地 SIGKILL 测试不是断电/文件系统损坏保证。所有外部业务状态、数据目录之外
的文件和远端副作用不在快照范围内。成功提交后的跨版本数据降级也不能仅靠切换 previous。

## 本地验证与设备验收

```sh
/var/cache/build-cache/run.sh -- env OPENCLAWMGR_TEST_NODE=/path/to/node-24.22.1/bin/node \
  python3 -B apps/openclawmgr/tests/test_installation.py
```

在仓库根执行。测试用 fake UCI/procd/网络/npm，只有 runtime-check 与微型 CLI 使用真实 Node，
不安装宿主服务、不运行真实 OpenWrt 包。可用 `OPENCLAWMGR_TEST_SHELL='busybox ash'` 和
`OPENCLAWMGR_TEST_BUSYBOX=/absolute/path/to/busybox` 验证 BusyBox applets。
历史本地验证见 `docs/evidence/openclawmgr-installation-20261123/`；后续 x86_64 与 arm64
设备验收证据见 `docs/evidence/openclawmgr-devices-20261123/`，以其中的最终验收报告为准。
glibc 改造与后续设备结果见 `docs/evidence/openclawmgr-glibc-20261123/`，任务树见
`docs/plans/openclawmgr-glibc.md`。旧证据中的向量降级结果不代表当前策略。
设备测试部署后端候选文件，不等同于 SDK 构建的 ipk 安装或浏览器端完整验收。

## 配置来源

- `UCI` 仅保留 `enabled`、`base_dir`、`install_accelerated` 这类外层管理配置。
- OpenClaw 运行配置统一以 `${base_dir}/data/.openclaw/openclaw.json` 为准，包括 `port`、`bind`、`token` 以及模型/鉴权相关设置；LuCI、安装脚本与 init 脚本均优先读取该文件。
