# 运行时多硬盘目录选择（2026-11-24）

目标：参考 AgentFlow 的目录习惯，为每块已挂载硬盘提供运行时存储选项，并支持自定义文件夹名。

## 命名与边界

AgentFlow 当前代码的应用目录为 `/mnt/<硬盘>/Configs/AgentFlow`，旧 mise HOME 为同级 `/mnt/<硬盘>/Configs/Runtime/home`。新公共运行时使用独立 `storage_root`，建议 `/mnt/<硬盘>/Configs/MiseRuntime`，也可输入 `/mnt/<硬盘>/MiseRuntime` 或其他满足现有路径契约的名称。不会把 AgentFlow 的旧 HOME 接管为新管理器根。

当前 `.7` 有 11 个固定环境，且 OpenClaw 的绑定和 wrap 引用现有绝对路径，所以保留 `/mnt/mise-runtime/Runtime-live`。已安装环境时选择框锁定，可展开查看其他硬盘目录；本次不实现自动搬迁。未配置目录时建议值只填表，保存后才初始化。

## 修改

- 核心新增只读 `storage-paths.lua`：枚举直接挂载于 `/mnt/<硬盘>` 的可写、可执行块设备，排除 loop/ram、系统 overlay、临时或网络挂载和容器子挂载。继续调用现有 `store.validate` 检查规范路径、符号链接和文件系统。查询不会创建建议目录。
- `read` 增加 `storage_paths`、`storage_default`、`storage_locked`。优先参考 QuickStart `conf_dir`，保留当前自定义目录，无磁盘时不回退 `/root`。
- 生产页面提供硬盘下拉框和自定义输入；保存实际路径，不提交“自定义”占位值。已有环境或离线根的路径锁定；后端保留原有保护。
- 核心包 release 更新为 2。LuCI/meta 已在同一待提交候选中递增为 2，不重复递增。

## 验证

- [修复前探针](red/storage-paths-live.json) 对旧 API 报错 `Storage read must expose disk choices`。
- [枚举策略测试](enumeration-tests.log)：7/7，覆盖多磁盘去重、QuickStart 自定义 Configs、当前离线根保留、无磁盘、非法偏好和不安全父目录。
- [实际首次配置测试](first-use-device.json)：对 `.7` 的 `/mnt/mise-runtime`、`/mnt/vio4-0` 分别通过公共 CLI 初始化临时运行时根，验证真实 UUID/文件系统及状态后清理测试根。通过空 `MISE_RUNTIME_ROOT` 隔离系统配置；`/etc/config/mise` 摘要前后一致。
- [浏览器验收](green-final/storage-paths-live.json)：7/7。实际 API 返回两个硬盘建议目录及现有自定义根；实际页面展示且保护现有根；后端拒绝直接换根。首次配置、自定义命名及无磁盘 UI 使用明确拦截的只读响应，保存请求被截获，不到达设备。移动布局和真实只读权限通过，实际 SDK/任务/配置前后一致。
- [弹窗回归](dialog-regression/dialog-layout.json)：32/32，通过桌面、手机、矮屏及深浅色组合，之前修复的居中和标题遮挡问题未复发。
- [构建检查](checks.json)：生产构建、类型检查、差异空白检查通过；产物输出位于 SSD。[生产模块边界](production-modules.audit.json) 通过。
- [直接文件部署](deployment.json)：44 文件中更新 4 个，其余 40 个一致。[设备审计](source-audit.json) 44/44；未构建 IPK/APK、修改包数据库或迁移现有应用。

真实设备截图：[已有环境的存储页](green-final/installed-storage.png)。首次配置 UI 的手机截图：[浏览器拦截场景](green-final/first-use-storage-mobile.png)。会话凭据只放在 SSD 私有文件，测试后销毁，不写入证据。
