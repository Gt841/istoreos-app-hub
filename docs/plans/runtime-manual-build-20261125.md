# 运行时环境、OpenClaw 与 AgentFlow 人工编译候选

日期：2026-11-25。此次提交提供源码、前端生产产物和验收记录，IPK/APK 由人工编译。

## 包版本

| 应用 | 包 | PKG_VERSION | PKG_RELEASE |
| --- | --- | --- | --- |
| mise | mise | 2026.8.14 | 28 |
| mise | mise-runtime | 0.1.1 | 2 |
| mise | luci-app-mise | 0.1.1 | 1 |
| mise | app-meta-mise | 0.1.1 | 2 |
| openclawmgr | luci-app-openclawmgr | 0.1.13 | 2 |
| openclawmgr | app-meta-openclawmgr | 0.1.13 | 2 |
| agentflow | agentflow | 0.3.5 | 4 |
| agentflow | luci-app-agentflow | 1.0.1-r6 | 空（沿用现有包命名规则） |
| agentflow | app-meta-agentflow | 0.3.5 | 5 |

上述版本覆盖运行时切换、AgentFlow 接入及最新 UI 修复。后续修复 root 后台准备任务继承应用 HOME 的问题，mise-runtime 与 app-meta-mise 继续提升至 release 2；OpenClaw 增加安装前端口冲突检查，界面包与元包继续提升至 release 2。其他包沿用各自原修订号。三个 app-meta 均已更新，软件中心可识别升级。

## 编译与安装范围

1. 更新编译源至包含此次提交的版本，按目标固件分别使用 x86_64 / aarch64 工具链编译。不要把直接测试使用的 x86_64 helper 二进制用于 aarch64 包；`mise-runtime` 的 C helper 由目标编译器生成。
2. 编译上表九个包，并按现有构建规则生成相应中文语言包及依赖。前端生产资源已同步到 `luci-app-mise/htdocs/luci-static/resources/mise`。
3. 先提供 `mise 2026.8.14-28` 与包含启动修复的 `mise-runtime 0.1.1-2`，再提供 LuCI、OpenClaw、AgentFlow 及其元包。运行时依赖 `libuci-lua`；OpenClaw 要求运行时至少 `0.1.1-2`，其他两个接口使用方（luci-app-mise、agentflow）保留最低版本 `0.1.1-1`。IPK/APK 依赖修订号分别使用 `-N` / `-rN`，由 `CONFIG_USE_APK` 选择。
4. 软件包安装后保留用户 UCI 与业务目录，检查 LuCI 缓存已刷新。切换运行时仓库时保留旧目录，用户需手动重启相关应用或系统；已接入应用会准备当前仓库中自己固定版本的依赖。

## 本次变更与验证边界

- 公共运行时：可切换仓库、固定依赖准备、glibc 检查与事务修复、非 root 仓库路径读取；默认持久路径 `/mnt/<硬盘>/Configs/Runtime`，默认管理员 HOME 为其 `home` 子目录。
- OpenClaw：启动时准备当前仓库的固定 GNU Node 及公共库，启动进度可见，真实 Gateway 与 sqlite-vec 校验通过。
- AgentFlow：替换旧 mise 独立入口，使用公共运行时与 ks-cli，固定代理版本并保留失败回滚；Go 后端与代理运行时准备分离。
- UI：参照 QuickStart 展开居中工作区、存储页宽屏两列、隔离 Argon 标题阴影、修复公共库文字重叠。
- 提交前再次通过：运行时契约 52 项、AgentFlow 20 项、前端 60 项、类型检查及生产构建。OpenClaw 安装回归 59 项，58 项通过，1 项本机 sqlite-vec 扩展测试因未提供扩展文件跳过；真实设备向量查询通过。九个包版本及八组 IPK/APK 最低依赖展开校验见 [编译准备检查](../evidence/runtime-switch-20261125/manual-build-readiness.json)。
- 真实设备证据来自 `192.168.30.7` 的直接文件部署与隔离测试；本次没有编译或安装 IPK/APK，没有执行 aarch64 验收，也未将 AgentFlow 隔离测试视为正式服务安装验收。

后续 release 2 的 HOME/端口修复与真实 OpenClaw 正式服务安装验收，见 [安装失败修复记录](../evidence/openclaw-install-home-20261125/verification.md)。原 `manual-build-readiness.json` 保留 release 1 提交时的历史检查，不代表后续修订。

详情见 [运行时切换验收](../evidence/runtime-switch-20261125/verification.md)、[AgentFlow 接入验收](../evidence/agentflow-shared-runtime-20261125/verification.md)、[UI 修复验收](../evidence/mise-page-layout-20261125/verification.md)。
