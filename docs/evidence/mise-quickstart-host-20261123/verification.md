> 后续增量：Go 能力与应用使用情况移除的当前验收见 ../mise-go-design-20261123/verification.md；本报告保留宿主复制时的历史结果。

# QuickStart ui-design 宿主代码直接复制验收

用户提供截图后确认差异属于宿主组件而非单个颜色。当前预览直接使用 QuickStart 的真实设计宿主 Vue、完整宿主 CSS、主题图标菜单和主题状态服务，替换此前自行绘制的简化导航与下拉框。

入口保持 http://127.0.0.1:5180/mise ，访问端口根路径也会进入 mise。仍为开发机上的模拟交互，无设备操作、真实语言安装、发布或提交。

## 复制内容及改动边界

完整文件位于 apps/mise/web/src/quickstart：

- design/IStoreHostShellPrototype.vue：菜单搜索、SVG 导航、分组展开、手机菜单、遮罩、键盘、焦点恢复和宿主框架。
- design/istoreHostShellPrototype.css、design/shell.css：原有完整宿主与内容区域布局，未摘取或重画。
- home/ThemeSelector.vue、utils/theme.ts：原版图标菜单及浅/深/系统偏好、跨页持久化与动态主题。
- home/homeSemanticColors.css、home/homeTypography.css：原版正式首页颜色及字号契约。
- 原 MIT 许可随文件保留。

其中六个源码文件逐字节一致。宿主 Vue 只有三个导航接入变更：服务分组添加 mise、选中服务分组、进入 mise 时展开服务分组。每个变更的前后文本与原始/复制 SHA256 记录在 src/quickstart/sources.json，并对照原目录核验，见 provenance.json。

本地 DesignHost 只负责在相同 design-content-region / qs-product 插槽中挂载 mise 与模拟场景工具，其他菜单目的地仅展示明确的预览边界。根路径跳到 mise。没有复制路由器读写接口、真实网络/磁盘业务，也不让预览冒充这些功能。

旧 design/host.css 中自制侧栏、顶栏、品牌和主题控件样式全部移除；没有覆盖 .host-topbar 或 .host-system-menu。保留的样式只用于 mise 场景工具、非实现页面提示及内容插槽间距。原生 mise dialog 增加显式 role，使上游宿主的原版模态检测可以正确锁定导航。

vue-router 使用与 QuickStart lockfile 相同的 4.0.14；锁定安装在项目 SSD 依赖目录。Vite /@ 别名指向已复制的本仓库源码，不依赖相邻 checkout，未设置开发代理。

## 检查

- 类型、23 项模型/wrap 测试、构建通过。
- mise 原有 15 组浏览器流程全部通过：全局默认只读、应用自行管理、固定版本 wrap 复制/下载、安装复核、任务续看、故障/恢复、主题/手机/键盘等。
- 新增 6 组宿主流程：完整导航和尺寸、搜索/分组/路由边界、原版主题菜单持久化与系统主题、手机菜单 Tab/Shift+Tab 约束与 Escape/焦点恢复、模态期间导航锁定、根路径与预览网络边界。
- 原目录摘要和复制内容核验通过；CSS/主题组件/主题服务均保持原文。
- 原有样式、安装数据、默认版本和应用版本语义保留，没有执行真实系统操作。

## 证据

- [mise 浏览器回归](round-1/browser.json) · [宿主浏览器检查](round-1/host-browser.json)
- [类型/模型/构建日志](checks-round-1.log) · [复制来源核验](provenance.json)
- [桌面浅色](round-1/copied-host-desktop-light.png) · [桌面深色](round-1/copied-host-desktop-dark.png)
- [手机菜单](round-1/copied-host-mobile-menu.png) · [手机内容](round-1/copied-host-mobile-light.png) · [手机 wrap](round-1/copied-host-mobile-wrap.png)

桌面和手机截图经查看，不把 mise 自身业务内容误称为 QuickStart 首页的网络流量/设备卡片。相同的是复制过来的宿主、导航、主题组件和其交互。

## 后续同步

`python3 -B scripts/sync-mise-quickstart-host.py --source /path/to/quickstart` 复制完整文件并校验三处导航接入文本；源文件结构变化时停止并要求维护者检查。常规构建使用本仓库快照，来源 commit、SHA256 和 MIT 许可均保留。生产 LuCI 页面仍由真实宿主提供导航，不在设备内嵌套这一设计宿主。
