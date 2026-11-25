# Runtime 目录及 HOME 兼容验收（2026-11-24—25）

用户指定标准：根目录 `/mnt/<硬盘>/Configs/Runtime`，mise 管理 HOME 为 `<根目录>/home`，执行时显式传入 HOME，参考 AgentFlow。

## 代码依据与修改

- AgentFlow init 先加载 `/lib/functions/mise.sh`，调用 `istore_runtime_env`，再把 `HOME`/`PATH` 传给 procd。控制器的 mise 查询也使用相同 helper。其原有默认 HOME 是 `Configs/Runtime/home`。
- 建议目录由 `Configs/MiseRuntime` 改为 `Configs/Runtime`；自定义目录和已有根保持可见，页面同时显示管理 HOME。
- `mise.sh` 保留非空旧 `runtime_dir` 的 HOME 含义；为空时解析为 `<storage_root>/home`。首次旧入口初始化优先采用已配置 `storage_root`，否则参考 QuickStart `Configs/Runtime/home`。不追加重复 `home`，不回退继承的 `/root`。环境准备无网络探测，并显式设置 HOME 和 XDG 路径。
- 管理器 link/where、默认查询和 root 默认 wrap 使用 `<storage_root>/home`；执行以显式环境传入 HOME。首次初始化创建该目录。mise 的 SDK 登记和配置继续按架构/ABI 隔离。
- 非 root 用户继续使用 `users/<uid>/home`；OpenClaw 和其他应用明确提供的 `ISTORE_RUNTIME_HOME` 保留。原 `users/0/home` 不自动搬迁或删除，显式引用仍可运行；共享 SDK/管理目录不能用作 HOME。
- 同步设计原型的 HOME 提示和 wrap 示例，生产构建继续排除设计模块。
- 直接部署工具增加旧 mise 脚本的备份、原子更新及审计。mise 包 release 26→27；runtime/LuCI/meta 沿用同一待提交候选的 release 2，不重复递增。

## 实机验收

仅测试 `root@192.168.30.7`，未操作 ARM。系统现有根仍为 `/mnt/mise-runtime/Runtime-live`，因此本次实际管理 HOME 为 `/mnt/mise-runtime/Runtime-live/home`。没有把 11 个环境及应用绑定搬到新标准目录，也没有修改系统 UCI 或重启服务。

- [修复前](red.json)：实际旧 helper 因 `runtime_dir` 为空而退出 1，虽然已有 `storage_root`；测试断言失败且配置不变。
- [实际执行](home-device-final.json)：23/23。AgentFlow 使用的 helper、`mise-istore exec`、`mise-exec`、3 个 GNU Node/npm 组合及其子进程、4 个 Python、2 个 Go、2 个 Zig 均验证实际 HOME/缓存。非 root 默认 HOME、显式旧 root HOME、OpenClaw UID32771 的实际固定 Node + 独立应用 HOME 均通过；拒绝管理器根、SDK 或缓存目录作为 HOME。无需下载。
- [显式旧配置入口](legacy-explicit-device.json)：5/5。隔离 UCI 下实际 mise 入口、stdin/参数/退出码、交互 shell 及 ks-cli 计划验证通过。可选网络工具故意阻塞，固定程序运行不调用它们。
- [首次配置](first-use-device.json)：两块真实磁盘分别初始化任务私有根及 root HOME，再删除测试根。文件系统/UUID 检查实际执行；全局 `/etc/config/mise` 内容不变。
- [真实 LuCI 及首次配置 UI](storage-ui/storage-paths-live.json)：7/7。API 返回两个 `Configs/Runtime` 选项及现有自定义根，HOME 显示随目录选项变化；已安装根继续保护。首次配置表单保存被浏览器拦截，未修改实机配置。
- [弹窗回归](dialog-regression/dialog-layout.json)：32/32，桌面/手机/矮屏和深浅色组合通过。

## 本地检查与部署

- [检查汇总](checks.json)：59 个前端/原型契约测试、[10 个旧 helper 测试](legacy-unit.log)、[7 个磁盘策略测试](enumeration-tests.log)、类型检查、18 个 Lua 文件及 shell 语法、生产前端构建、差异空白检查通过。依赖和构建/测试临时输出使用 SSD 缓存。
- [生产边界审计](production-modules.audit.json) 保留，设计模块没有进入生产产物。
- [部署](deployment.json)：47 个文件中更新 9 个，38 个一致；[设备文件审计](source-audit.json) 47/47。仍为直接文件开发部署，未构建 IPK/APK、修改包数据库、推送或发布。
- 临时 LuCI 会话已全部销毁，凭据文件已删除，未写入证据。

实际页面：[存储目录及 HOME](storage-ui/installed-storage.png)。完整截图集合按现有证据规则仅留本地。
