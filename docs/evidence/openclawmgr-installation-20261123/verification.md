> 历史本地验收记录。后续授权的真实设备测试和新增修正见 [设备验收](../openclawmgr-devices-20261123/verification.md)，本目录的源码摘要对应当时版本。

# OpenClawMgr 安装优化验收（2026-11-23）

目标与任务树：[`../../plans/openclawmgr-installation.md`](../../plans/openclawmgr-installation.md)。

## 最终结果

- 第 1 轮：23/23 隔离测试通过。
- 第 2 轮：32/33 通过；一个含空格路径夹具错误，第三轮前已修正为验证用户 base_dir。
- 第 3 轮：36 项测试在默认 sh 和 BusyBox ash/applets 下分别全部通过，共 72 次执行。
- 27 项静态检查全部通过：两种 shell 的 9 个文件语法、ShellCheck warning 级别、
  3 个 Lua 文件和 2 个嵌入 Lua 块、2 个 JavaScript 文件语法，以及 git diff whitespace。
- 结束于第三轮，没有第四轮。

机器结果：`verification.json`；完整测试名称和结果：
`round-3-default-shell.log`、`round-3-busybox-ash.log`。
实施文件摘要：`source-sha256.json`。

## 实际验证范围

安装测试从实际交付的 `openclawmgr.sh` 入口运行，固定系统路径被映射到独立夹具，
UCI、procd、网络、npm 由夹具提供。覆盖下载错误码、归档摘要、npm 包 SRI、目标 engines、
CLI/原生模块失败、新装、旧目录迁移、连续升级、配置/健康失败、快照恢复、恢复再次失败后的重试、
SIGTERM 子进程清理、激活后 SIGKILL 恢复、加速开关、自定义端口、四平台 URL、含空格数据路径、
交互终端 npm shim、显式 npm Git 适配、权限、卸载以及包依赖和 release。

运行时检查使用实际 official Node 24.22.1 x64/glibc。归档下载前置 SHA256 验证通过，
实际 SQLite TEXT/BLOB/JSON 读写通过，并验证了错误架构/libc 被拒绝及 npm 脚本参数门禁。
Node 与检查工具放在 SSD 缓存工作目录；依赖/服务未安装到宿主系统。
BusyBox 版本为 Ubuntu 构建的 1.36.1，因此本地兼容性证据不能代替目标固件验收。

复现：在仓库根使用 README 中的测试命令，设置 `OPENCLAWMGR_TEST_NODE` 到
受支持的 Node 24.22.1 x64/glibc，测试只依赖 Python 标准库和 Node 自带的 npm/semver。
BusyBox 矩阵额外设置 `OPENCLAWMGR_TEST_SHELL='/absolute/path/to/busybox ash'` 和
`OPENCLAWMGR_TEST_BUSYBOX=/absolute/path/to/busybox`。

## 发布前待验收

- [ ] 构建 OpenWrt 包并确认目标固件提供 setsid、coreutils-timeout 和动态库依赖。
- [ ] x86_64/musl 设备真实新装、升级，以及 sharp/sqlite-vec/node-pty 功能验证。
- [ ] aarch64/musl 设备完成同级验证。
- [ ] 用实际 ks-cli/KSpeeder 验证能力门禁、TLS、自定义端口和 Git 依赖。
- [ ] 用实际 procd/taskd 验证启动、健康失败、取消和 recover_install。

本次没有真实 OpenClaw/npm 网络安装、SDK 编译、远程设备变更、提交、推送或发布。
不声称完成断电/文件系统损坏测试，也不覆盖 data 之外或远端业务副作用的回退。
