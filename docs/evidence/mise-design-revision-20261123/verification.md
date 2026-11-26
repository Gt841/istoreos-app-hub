> 宿主后续已按用户要求改为直接复制 QuickStart ui-design 完整组件，见 [最新宿主复制验收](../mise-quickstart-host-20261123/verification.md)。本报告的默认版本、应用归属与 wrap 检查仍保留。

# mise 设计修订：全局默认、专属 wrap、应用归属与严格样式

本次按用户修正更新既有设计预览，仍位于 http://127.0.0.1:5180/mise 。当前实现不安装真实运行时、不修改设备或现有 mise 包，也未提交/推送。

## 实现结果

- Node/Python 分别展示 mise 全局默认，明确只读。本页没有设默认或全局切换。默认环境加入删除保护。
- 应用使用情况只读展示应用上报的固定版本、状态与引用。删除了应用切换对话框、模型事务和 API；API 拒绝 kind=bind，也没有 set-default 操作。安装或清理不改变任何应用配置。
- 每个版本提供“使用此版本”：Node/npm、Python/pip、进入 shell 三条固定环境命令；支持复制和 wrap 脚本样例下载。
- wrap 将 HOME、XDG、mise 配置/数据/缓存、npm 缓存或 pip/uv 缓存放在持久分区。默认 HOME 按 UID 隔离，npm prefix/Python user base 按环境 ID 隔离，应用可设置自己的 ISTORE_RUNTIME_HOME。明确版本/架构/libc，不依赖 /root 或用户当前默认版本。
- glibc 调用管理器安装环境的专属启动器，不给宿主命令注入全局 LD_LIBRARY_PATH。缺少存储/启动器时，在创建 HOME 前退出。
- 页面改用 QuickStart 当前正式语义色（浅 #155dfc、深 #91b9ff）、Arial 字体、生产设备页工作区/按钮，以及 NetworkWidgetDialog 的弹窗声明。同步源码记录 commit 和逐文件 SHA256；只变选择器/作用域，声明值可比对。MIT 许可保留。

## 验证范围

模型与 wrap 共 23 项检查：只读默认/应用、安装保持配置、默认/引用删除保护；生成脚本的 POSIX shell 执行、工具参数、持久 HOME/缓存、版本隔离、子进程和自定义应用 HOME。脚本检查把 /mnt 映射到 SSD 临时目录并使用假解释器，证明封装逻辑，不宣称真实 Node/Python、glibc 或 ARM 设备通过。

浏览器覆盖 15 组，包括原有安装复核/取消/刷新续看/失败重试、应用只读和 API 拒绝切换、全局默认只读、wrap 命令复制及实际下载、手机/桌面主题、键盘、离线/加速异常、QuickStart 实际样式值、同源与设备请求拒绝。覆盖两种示例架构，架构状态仍是设计样例。

QuickStart 来源与声明的 9 项核对见 style-provenance.json。工作区与弹窗复制后的完整声明对照原 SFC 相应 style 块；颜色、字体、25px 桌面标题、7px 按钮与 18px 弹窗圆角还经过浏览器计算样式检查。

## 本次检查记录

第一轮：23 项模型/wrap、15/15 浏览器组通过。人工查看手机弹窗后补齐与上游 shade 16px 留白等价的原生 dialog 宽度限制；生成脚本检查把 &&/|| 写法改为明确 if，复核 ShellCheck。

第二轮：复核上述两处修正及全部交互，最终结果见 verification.json、checks-final.log 与 round-2/browser.json；达到通过条件即停止，不进行第三轮。

## 证据

- [最终浏览器记录](round-2/browser.json) · [类型/模型/wrap/构建](checks-final.log)
- [样式来源核对](style-provenance.json) · [同步来源摘要](../../../apps/mise/web/src/styles/quickstart/sources.json)
- [桌面浅色](round-2/desktop-light-0.png) · [桌面深色应用只读](round-2/desktop-dark-1.png)
- [桌面 wrap](round-2/desktop-light-wrap.png) · [手机 wrap](round-2/mobile-dark-wrap.png)
- wrap 交互、命令复制及实际下载在 round-2 浏览器 R2 检查中，下载样例为 round-2/downloaded-node-wrap.sh。

正式集成仍需：安装器生成真实入口、注册 mise SDK、准备各 UID 的可写目录与权限、验证挂载和收据、接入应用引用上报。这里不保证自动识别全部手工 wrap 引用；详情/清理文案已说明这一边界。此前 OpenClaw ARM 健康检查待复验状态不被本次设计验证覆盖。
