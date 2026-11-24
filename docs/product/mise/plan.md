# mise 产品交互目标与任务树（修订）

产品交互阶段已完成。后续正式运行时、LuCI 接入与 OpenClaw 迁移以 [runtime-milestones.md](runtime-milestones.md) 的 M1–M9 为准；下文保留设计阶段历史记录，不代表真实安装或设备验收通过。

前轮目标（应用引用部分由本轮 G1 取代）：区分 mise 全局默认与固定环境；为普通用户提供每个版本的 wrap 使用入口，将 HOME、缓存和 mise 数据放在持久磁盘；应用自行决定版本，此页只读展示应用引用；严格同步 QuickStart Web 正式页面的语义色和样式声明。

始终为设计预览：不安装真实 Node/Python/Go、不发布 LuCI 包、不修改设备。

## 前轮任务树（历史记录）

- [x] R1 全局默认：分别展示 Node/Python 的 mise 默认环境，仅只读，不提供全局切换；默认环境不能清理。
- [x] R2 应用归属：移除应用切换 UI/模型/接口，展示应用上报的固定版本及引用保护。
- [x] R3 固定版本 wrap：每个环境提供命令、环境 shell、复制及脚本样例下载；明确 /mnt 下 HOME 与 mise/cache 目录，允许应用显式提供自己的持久 HOME。
- [x] R4 严格样式来源：从 QuickStart 原源码同步语义变量、工作区布局、按钮、弹窗声明，记录 SHA256 与许可；构建不依赖相邻 checkout。
- [x] R5 检查：模型、wrap 沙箱执行、类型/构建、浏览器的默认只读/应用只读/命令下载/交互及样式值比较、桌面/手机主题截图。
- [x] R6 交付：更新规范、README、验收记录，继续在 5180 提供预览。最多三轮检查。

## 前轮验收标准（应用引用由 G1 取代）

- 全局默认显示来源、版本和 ABI；不提供改默认动作，安装新版本不改变默认和应用状态。
- 应用版本由各应用决定，API 也拒绝应用切换，不能仅隐藏按钮。
- Node/npm、Python/pip、交互 shell 都通过专属 wrap；不依赖 /root，缺少环境时在创建 HOME 之前退出。
- HOME/缓存按用户保存在持久磁盘，包前缀按版本隔离；应用可指定自己的持久 HOME。子进程沿用目标版本，glibc 通过已管理环境自己的 loader 入口使用，不向宿主设置全局 LD_LIBRARY_PATH。
- 默认或应用引用中的环境禁止清理；未登记的外部 wrap 使用不能被误称为“无人使用”。
- CSS 声明来自 QuickStart 当前 homeSemanticColors、device 页面及 NetworkWidgetDialog；同步只改作用域/选择器，颜色、字体、按钮/标题/弹窗实测值可追溯。
- 保留已有安装复核、故障重试、任务刷新续看、取消/恢复、空间和库引用保护。

上一版的应用切换和紫色近似风格已由本次修订取代，历史报告保留在 docs/evidence/mise-design-20261123。当前结果见 docs/evidence/mise-design-revision-20261123/verification.md。

## 宿主源码复制追加任务（按截图反馈）

- [x] H1 对照用户截图与 QuickStart ui-design 实际组件，定位自制宿主差异。
- [x] H2 复制完整宿主、CSS、主题菜单/状态服务和颜色/字号文件，保留许可及源码摘要。
- [x] H3 只补 mise 导航及内容插槽，移除旧自制宿主和主题控件，保留原业务交互。
- [x] H4 类型/23 项模型与 wrap、15 组既有浏览器交互、6 组宿主及手机键盘/主题检查通过。
- [x] H5 验证复制来源，归档截图，保持 5180 预览；不部署设备或发布。

## Go 与功能收敛（当前目标）

在开发复杂度可控的前提下增加 Go；以显式工具目录驱动名称、版本、平台选项和验证说明，保持 QuickStart 宿主源码不变。不一次性开放任意 mise 插件，不引入 Rust 组件、Java 发行版等额外生命周期。

- [x] G1 删除应用页、模拟应用数据、应用计数及引用删除保护；保留全局默认与真实环境→库的删除保护。
- [x] G2 注册 Node/Python/Go 工具能力；Go 仅标准工具链，隐藏 libc/npm 选择，切换语言重置不适用字段。
- [x] G3 Go 固定版本 wrap：go/gofmt/shell、持久 HOME/GOPATH/GOBIN/构建与模块缓存、固定 GOTOOLCHAIN=local、GOENV=off。默认 CGO_ENABLED=0，允许显式 1；不安装 C 编译器或承诺 CGO 兼容。
- [x] G4 验证安装复核、后台任务、默认保护、删除提示、两种架构示例、手机深浅主题与原 Node/Python/宿主回归。最多三轮。
- [x] G5 更新契约与证据，在 5180 继续提供预览，明确未安装实际 Go、未做设备验收。

当前验收：docs/evidence/mise-go-design-20261123/verification.md。两轮浏览器检查均通过；第二轮仅改截图等待以避免菜单过渡帧。

## Rust / Zig（当前追加目标）

延续设计预览范围，在受控工具目录中增加 Rust、Zig 多版本与固定 wrap；不加入 nightly、额外组件、交叉目标安装或自动配置 C 工具链。保留 QuickStart 宿主与三页结构。

- [x] C1 核对官方发布元数据：Rust 两个示例版本的 GNU/musl、x86_64/ARM64 minimal 组件；Zig 两个版本的双架构归档。
- [x] C2 接入版本/平台选择、复核任务、默认只读/保护、公共 glibc 引用保护、清理提示。
- [x] C3 抽取显式语言 wrap 适配器，保持 Node/Python/Go 行为；Rust 固定 rustc/cargo，Zig 固定 zig，HOME/缓存持久化与工作目录隔离。
- [x] C4 检查模型、wrap 沙箱、类型/构建、产品及宿主回归、新增双架构流程、320/390 手机深浅主题。最多三轮。
- [x] C5 更新契约与证据，5180 保持可预览；明确没有真实 Rust/Zig 安装或设备编译验收。

Rust/Zig 当前验收：docs/evidence/mise-rust-zig-design-20261123/verification.md。两轮检查完成；第二轮仅修正截图前滚动位置。

## Java 产品交互（当前追加目标）

在既有三页和工具目录中增加 Java，限定 Eclipse Temurin JDK 21/25 LTS、私有 glibc、x86_64/ARM64；复用安装任务，不新增厂商、JRE、Maven/Gradle 或 musl 组合管理。仍是设计预览。

- [x] J1 核对已发布构建及双架构归档，身份包含厂商、完整补丁版本及构建号。
- [x] J2 接入 Java 筛选、版本显示、复核、详情、默认只读/删除保护、glibc 引用与清理影响提示。
- [x] J3 固定 java/javac/jar/shell wrap，JAVA_HOME 和 JVM 默认 user.home/java.io.tmpdir 指向持久磁盘，保持调用者其他选项与参数。
- [x] J4 类型/构建、模型与 wrap、双架构 Java 流程、手机深浅主题及五种语言/QuickStart 回归；最多三轮。
- [x] J5 文档与验收证据，5180 提供预览；明确不安装真实 JDK、不做设备验收。

Java 当前验收：docs/evidence/mise-java-design-20261123/verification.md。第二轮修复刷新后从任务结果返回时的语言筛选；Java 6 组与既有产品 17 组复测全部通过。

## Python pip/venv 与 npm 高级选项（当前目标）

详细任务树与验收标准：[python-packaging-plan.md](python-packaging-plan.md)。Python 默认准备/验证 pip/venv，详情如实展示已读取及未知状态，应用包改为独立 venv 使用；wrap 校验归属并保留固定 SDK 启动路径。npm 默认配套，高级选择收起。最多三轮，不变更生产安装器或部署设备。

Python 本轮 P1–P5 全部完成，两轮验收通过，详见 docs/evidence/mise-python-packaging-20261123/verification.md。
