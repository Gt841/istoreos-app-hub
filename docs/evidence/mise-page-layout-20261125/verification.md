# Runtime 页面展开与主题边界修复

2026-11-25，x86_64 `192.168.30.7` 真实 LuCI/Argon 页面。

复现命令：`apps/mise/web/tests/page-layout-live.browser.mjs`，通过 SSD wrapper 执行 Node，使用 `luci-session.py` 创建的私有临时会话。测试只读取运行时状态，没有提交设置或重启业务。

## 原因与修正

1. 2048px 窗口下宿主可用内容宽度为 1768px，旧 `.runtime-product` 被限制在 1240px，仅利用 70.1%。QuickStart 的 scoped 样式又将 margin 改为 0，导致剩余空间集中在右边。移除该旧限制，采用 QuickStart `pages/device/index.vue` 的流式页面和 1640px 居中工作区。
2. Argon 全局 h2 阴影进入插件，标题产生白色装饰块。参照 QuickStart `home/luciHomeBoundary.css`，只在 `.mise-surface` 内重置标题阴影和颜色，保留系统侧栏和顶栏。
3. 私有库 ID 使用带 padding 的 inline small，盖住前一行引用/验证信息。改为独立块并设置间距，移动端将操作按钮排到说明下方。

存储页在 1600px 及以上采用左右两列：存储与下载在左，公共库及缓存在右；较小窗口纵向排列。表单随可用列宽展开。

## 验证

- `before/layout.json`：旧页面在 2048px 明确失败（70.1% 宽度利用）。
- `intermediate/layout.json`：宽度修复后，精确复现库说明与代码块重叠。
- `final/layout.json`：7/7 通过。四档宽度 2048/1440/1024/390，无横向溢出、无标题阴影、库说明不重叠；运行环境及任务页正常；深色标题使用 QuickStart 文本 token。
- `final/storage-2048.png` 与 `final/storage-390.png`：最终实际页面截图；另有深色截图。
- `source-audit.json`：51 个直接部署的 Mise 文件内容和模式通过。此次仅更新 CSS 静态产物；未改运行时仓库配置、SDK 或应用绑定。
- 前端生产构建和 `git diff --check` 通过。沿用当前尚未发布候选中已经提升的版本，不重复增加 release；未编译 IPK/APK。

之前仅验证内容不溢出的测试无法捕捉“过窄但不溢出”。本次增加可用宽度比例、QuickStart 工作区展开和行间几何断言，直接覆盖该问题。
