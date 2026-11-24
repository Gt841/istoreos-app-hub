# 运行时环境：产品与样式契约（修订）

## 三类版本使用方式

1. **mise 全局默认**：按 Node/Python/Go/Rust/Zig/Java 分别只读显示。默认值由 mise 配置管理，此页不提供切换、自动选择或“设为默认”；安装新环境不会改变默认。
2. **用户指定版本**：每个环境的“使用此版本”提供固定入口，支持 Node/npm 或 Python/pip，以及该版本的 shell。命令包含精确版本/架构/libc，不依赖用户当前 PATH、/root 或全局默认。
3. **应用自行使用**：应用按自己的配置调用固定 wrap；本插件不登记或统计应用依赖，不显示应用页或应用计数，也不宣称能够自动判断使用情况。

mise 默认是删除保护；公共 glibc 的保护根据已安装环境判断。删除其他环境时，必须提示固定 wrap 将失效、依赖它的应用或脚本无法启动，由用户自行确认。应用依赖登记留待实际需求出现后设计，本轮没有后台登记或调用遥测。

## wrap 与目录约定

- 入口：`<Runtime>/wrap/<语言-版本-架构-libc>`。
- 固定启动器：`<Runtime>/environments/<id>/bin/node` 或 `bin/python3`。glibc 由此已验证的启动器处理，不对宿主 sh/git/ks-cli 设置全局 LD_LIBRARY_PATH。
- 默认用户 HOME：`<Runtime>/users/<uid>/home`；XDG 配置/缓存/数据均在其下。
- mise SDK：`<Runtime>/mise/<arch>-<libc>`；配置为用户自己的目录，缓存位于持久 HOME。正式安装器须将该 SDK 注册为同一个固定环境，不能让 mise 另找一份 Node/Python/Go。
- npm user prefix、Python user base 按完整环境 ID 隔离，避免跨版本安装包。
- 应用设置 `ISTORE_RUNTIME_HOME=/mnt/.../<application>` 时保留其独立 HOME；必须是持久磁盘路径。应用与其他用户不会被改全局 HOME。
- 使用之前检查存储与环境启动器是否存在，未安装/磁盘离线立即退出，不先创建 HOME。正式管理器还须验证挂载、收据并为各 UID 预置有合适权限的用户目录；只读 SDK 与可写用户目录分开。

下载为脚本样例，不是已经安装的运行时。测试把 /mnt 映射到 SSD 临时沙箱，并使用可检查参数/环境的假解释器验证路径、工具分派及 shell 子进程；不是 ARM 或 glibc 实机验收。

## 工具能力目录与 Go

src/domain/catalog.ts 是受控目录：名称、示例版本、ABI 选项、默认平台、大小及检查说明统一配置。具体 wrap 的环境变量和命令分派保留语言适配，新增语言仍须验证；不将 upstream mise 所有工具直接标为支持。

Go 环境 ID：go-<version>-<arch>-native。native 表示标准 Go 工具链安装方式，不表示所有 Go 产物都无 libc 依赖。两种架构使用同一交互，不提供 glibc/musl 选择，不安装私有 glibc。正式安装须按实际下载产物检查 ELF、系统/内核要求，并在设备验证 go version、gofmt、纯 Go 编译执行。

wrap 的环境目录即完整 Go 分发根目录（bin/go、bin/gofmt、pkg、src）；设置 GOROOT、MISE_GO_VERSION、GOTOOLCHAIN=local 和 GOENV=off，避免持久 go env 或模块要求静默切换工具链。项目要求更高版本时应失败并由用户选对应 wrap，不自动安装。

GOPATH/GOBIN/构建缓存/临时目录按用户及完整环境 ID 隔离；模块缓存按用户共享，均位于持久 HOME 下，禁止落到 /root 或共享只读 SDK。go install 的命令写入该用户版本的 GOBIN。wrap 默认 CGO_ENABLED=0；显式 CGO_ENABLED=1 时保留，由调用者准备目标 libc 匹配的 C 编译器、头文件与库。本插件不自动提供这些组件。

Go 示例版本 1.27.4/1.26.10 来自 [Go 发布目录](https://go.dev/dl/)，是预览选择，不是在线版本目录或真实安装收据。依据：[mise Go](https://mise.jdx.dev/lang/go.html)、[Go cgo](https://pkg.go.dev/cmd/cgo)。ks-cli 只保留与 Node/Python 一致的下载策略交互；没有实际调用或声称加速 Go 模块、编译。

## QuickStart 样式来源

`src/styles/quickstart/sources.json` 固定本次源码摘要及 QuickStart commit；MIT 许可证随复制内容保留。`scripts/sync-mise-quickstart-style.py --source /path/to/quickstart` 可重新生成。

- home/homeSemanticColors.css：当前正式首页语义变量，浅色强调 #155dfc，深色 #91b9ff；替代之前以旧 root.scss 紫色为主的近似实现。
- pages/device/deviceVisualTokens.css：生产设备页语义变量、按钮色，字体沿用 Arial/Microsoft YaHei。
- pages/device/index.vue：工作区容器、标题、tab、手机断点声明，选择器映射到 mise 同角色元素，声明值保留。
- pages/device/deviceCenterList.vue：主要/次要按钮的完整声明。
- home/NetworkWidgetDialog.vue：弹窗、标题、正文、关闭控件的样式声明；原生 dialog 负责焦点/模态 mechanics。
- pages/index/components/Card.vue：卡片样式参考归档；当前工作区以 device/index.vue 为主。
- design/istoreHostShellPrototype.css：宿主 200px 侧栏、64px 顶栏、品牌尺寸/颜色的参考。

只改变选择器/作用域的复制部分与 mise 自身必要的行布局、命令框、任务状态样式分开；不把宿主 reset 注入全局。构建只读取仓库内的同步文件，不依赖相邻 QuickStart checkout。主题变更不重建产品状态。

## 预览与正式宿主

预览入口 `scripts/ui-design.sh`，按用户要求占用 5180；保留端口与 PID 身份保护。预览只运行同源内存数据服务，不代理设备，不调用真实 ks-cli 或语言包安装。场景切换会重置本会话；任务在服务存活时可刷新续看，服务重启后重置。

`src/main.ts` 的 mountRuntime(root, service) 保留正式 LuCI 挂载接口；未来由认证模板提供 API/路由/语言/主题/CSRF，适配真实任务服务。当前没有生产 API、LuCI 包或设备部署。

## 最新宿主接入：直接复制 ui-design 前端代码

按用户截图反馈，已用 src/quickstart 下复制的 IStoreHostShellPrototype.vue、完整宿主/shell CSS、ThemeSelector.vue、theme.ts 及正式颜色/字号文件替换旧自制宿主。六个源码文件逐字节一致，宿主 Vue 仅登记 mise 导航，详见 src/quickstart/sources.json。

现在保留原版菜单搜索、完整 SVG 菜单、手机展开/遮罩/键盘与焦点、主题图标菜单和持久化服务。由同一 design-content-region/qs-product 插槽挂载 mise；本地不再重写宿主 chrome。复制的是设计宿主及其依赖，生产 LuCI 仍使用系统本身的宿主。

同步完整宿主：scripts/sync-mise-quickstart-host.py --source /path/to/quickstart。原样式声明同步入口继续用于 mise 内容页，不替代完整宿主复制。当前验收见 docs/evidence/mise-quickstart-host-20261123/verification.md。

## Rust / Zig（受控范围）

目录增加 Rust 和 Zig。Rust 示例 1.91.1、1.90.0 为已发布稳定版本样例，不宣称最新；Zig 示例 0.17.1、0.15.2。官方 Rust channel manifest 逐个确认两架构 GNU/musl 下 rustc/cargo/rust-std 的 available，Zig index 确认两架构归档，摘录保存在 mise-rust-zig-design-20261123/upstream-artifacts.json。发布资源存在不代表当前 iStoreOS 设备满足内核/libc 要求。

Rust 使用 minimal（rustc/cargo/宿主 rust-std），不开放 nightly、rustfmt/clippy、附加标准库目标和组件增删。GNU/musl 是运行编译器的宿主 ABI；不能把“能编译 musl 目标”当成“编译器能在 musl 系统运行”。正式安装须核验该版本 host triple、libc 最低版本、动态依赖和内核，并配置 GNU 私有 loader；宿主 C 链接器、build.rs 的 C 依赖与交叉编译工具链不在本轮范围。

wrap 必须调用 environments/<id>/bin 下实际工具链的 rustc/cargo，不得指向 rustup 通用代理。RUSTC/RUSTDOC 固定到该环境，RUSTUP_TOOLCHAIN 为精确版本+host triple，RUSTUP_HOME 位于 <Runtime>/rustup/<arch>-<libc>，由安装器管理并链接到同一工具链。wrap 不创建/修改共享 rustup 目录，也不提供 rustup CLI，RUSTUP_AUTO_INSTALL=0；项目工具链要求不触发自动安装或切换。CARGO_HOME 按用户及环境 ID 隔离，CARGO_TARGET_DIR 默认位于持久 HOME 的缓存下，按环境 ID 与 pwd -P 的绝对工作目录区分；TMPDIR 位于同一版本的持久缓存。cargo --target-dir、项目配置和显式命令可改变产物输出，直接 rustc 输出仍由命令决定。此设计不限制项目脚本主动执行外部工具。

Zig 使用标准平台归档（native ID），安装 UI 不选择 libc。产物架构与 ABI 通过 zig 的 -target 等参数指定，不安装对应 libc 全局环境，不自动接入 Rust linker 或 Go CGO，也不加入 ZLS/nightly 管理。完整归档根位于 environments/<id>，bin/zig 由安装器链接到同根 Zig，ZIG_LIB_DIR 固定到其 lib。全局缓存按环境 ID 隔离；本地缓存再按 pwd -P 绝对工作目录隔离；TMPDIR 位于持久 HOME。zig-out/cc 输出仍由项目或命令决定。正式下载应保留 Zig 官方签名校验，即使经 ks-cli 或镜像下载。

参考：[mise Rust](https://mise.jdx.dev/lang/rust.html)、[Rust 平台](https://doc.rust-lang.org/stable/rustc/platform-support.html)、[mise Zig](https://mise.jdx.dev/lang/zig.html)、[Zig 多版本归档](https://ziglang.org/learn/getting-started/)。src/domain/wrap.ts 的显式适配器统一生成脚本，UI 不复制安装任务流程。五个语言入口在手机允许换行，不重写 QuickStart 源码样式。

## Java 产品交互

本轮固定发行版 Eclipse Temurin，完整 JDK（不是单独 JRE），21/25 LTS 两个系列。示例构建为 temurin-21.0.9+10、temurin-25.0.1+8，均为已发布的历史设计样例，不宣称最新或作为生产推荐版本。双架构归档及 checksum 文件从官方 GitHub release API 核对；Adoptium latest API 本次返回 403，保留失败记录并使用已发布固定构建。证据位于 mise-java-design-20261123/upstream-fixed-artifacts.json。

版本字段包含厂商和构建号，ID 如 java-temurin-25.0.1+8-aarch64-glibc；不同厂商/构建不能合并成 java-25。UI 将该身份展示为 Temurin JDK + 完整版本 + LTS，安装请求必须是目录中的确切构建。正式 mise 后端仍须将该发布身份映射到验证过的安装路径/收据，不能假设所有后端使用相同构建字符串。

初版仅私有 glibc，不提供 ABI 或发行版下拉，不在 musl 宿主上直接让 mise 自动选择另一个产物。Java hint、复核、详情均说明发行版、JDK 与固定 ABI。后端拒绝 musl/native、其他厂商、major/latest 浮动请求及不在目录的构建。安装后计入公共 glibc 引用；mise 默认只读，不设置默认，也不登记应用。

wrap 固定 environments/<id>/bin/java、javac、jar，提供四条可复制命令（含 shell）及脚本样例。JAVA_HOME/JDK_HOME 指向同一完整 SDK；TMPDIR 位于持久 HOME 的按环境 ID 缓存目录。JAVA_TOOL_OPTIONS 保留已有内容，再追加带双引号的 -Duser.home 和 -Djava.io.tmpdir 默认值，使 javac/jar 和 shell 子 JVM 也能继承。HOME 包含空格可用；双引号无法直接作为该 JVM 选项的路径内容，本轮在创建 HOME 前明确拒绝。调用者显式 JVM 命令参数/其他 JVM 选项仍可覆盖默认属性，本功能不是沙箱。缓存与临时目录默认落盘不代表 javac/jar 构建产物也自动迁移，后者由命令/项目决定。

不设置全局 LD_LIBRARY_PATH。正式私有 GNU 启动器须验证整个 JVM（含 libjvm.so、JNI 和原生库加载、TLS），不能只检查 java 入口可执行。还须验证 javac/打包/运行及实际 user.home/java.io.tmpdir；本机没有 Java，当前脚本测试使用假解释器检查参数/环境，不能作为真实 JVM/设备验收。

参考：[mise Java](https://mise.jdx.dev/lang/java.html)、[Java VM 属性](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/System.html)、[Java 启动选项](https://docs.oracle.com/en/java/javase/25/docs/specs/man/java.html)。Maven/Gradle 的发行版与缓存不在此插件本轮管理范围，由应用自行处理。

## Python pip/venv 与 npm 默认交互（当前修订）

此前 Python 的 PYTHONUSERBASE 安装约定由本节取代：共享 SDK 只提供解释器与配套 pip/venv 能力，不作为默认应用包安装位置。Python 安装没有 pip 版本下拉；复核和任务包含 pip/venv 准备验证，失败不提交，完成后显示读取的 pip 版本与 venv 状态。Runtime.pythonTools 传递 pipVersion、venv 状态与 source（probe/design）；缺失数据必须显示未读取/未验证，不能推测版本。当前服务的 25.0.1 均明确标为设计样例，来自所选 CPython 的 ensurepip 源码基线，不代表实际设备探测。

使用弹窗保留版本查询，并增加应用目录输入及创建环境、安装 requirements、运行和 shell 四条命令。路径只接受 /mnt 持久分区，禁止公共 SDK 管理目录、回退和控制字符；命令正确引用带空格或单引号的目录。页面只生成命令，不创建文件或执行包安装。requirements.txt/app.py 按项目替换。默认示例目录按完整 SDK ID 区分，普通用户可更换到应用自己的目录。

wrap 支持 --create-venv <dir> 与 --venv <dir> python/pip/--shell；已激活的受管理 venv 也按同一逻辑路由。共享 pip 命令仅用于版本/帮助查询；共享解释器设置 PIP_REQUIRE_VIRTUALENV=true、PYTHONNOUSERSITE=1，并清除 PYTHONUSERBASE 以及继承的 PIP_USER/PIP_PREFIX/PIP_TARGET，不默认安装到共享 SDK 或用户 site。显式参数和项目脚本仍是用户控制，本约定不是权限沙箱或安全隔离。

新建环境必须是不存在的目标。通过固定 SDK 创建不含 pip 的 venv，替换 python/python3/pythonX.Y 为指回同一 SDK 启动器的 sh 入口；CPython getpath 使用 __PYVENV_LAUNCHER__ 定位该 venv，确保 sys.executable、pip 入口及 Python 子进程再次经过原 SDK 的私有 loader，而不是直接运行无法加载的 GNU ELF。此变量是 CPython 启动器实现细节，正式安装必须针对确切 CPython/启动器验证；不能将它视为跨 Python 实现的通用 API。探测 prefix/base/version/用户 site 后才离线 ensurepip 并写入该环境的本地归属文件（固定 SDK、版本/架构/libc ID、路径和入口摘要）。此文件只用于核对本地环境归属，不是中央应用使用登记，也不是对不可信目录的安全认证。

后续使用检查归属、入口摘要、配置和实际解释器 prefix/base/version；不匹配、启动器丢失 venv 信息或不是此方式创建的环境均报错，绝不静默回退共享解释器。已有普通 venv 暂不自动导入或改写；用户应新建环境并按 requirements 重装。创建失败仅移除本次新建且 inode 未变的候选，不清理已有目录或父目录。虚拟环境与其 SDK 均不能随意移动。

HOME、pip/uv 缓存、Python TMPDIR 位于持久磁盘。通过 --venv 进入的 shell 保留固定版本及私有库路径；不设全局 LD_LIBRARY_PATH。正式 SDK 的 bin/python3 必须保留 __PYVENV_LAUNCHER__ 并完成所有 GNU native loader 处理。未接入的启动器明确失败，不声称已完成 ARM 或 GNU 固件验证。

npm 默认取 Node 配套版本，当前版本始终可见；高级选项默认收起，允许兼容的独立 npm，语言/版本切换重置配套选择。安装模型也为省略 npm 的请求选择正确默认。

验收：最多三轮，当前记录见 docs/evidence/mise-python-packaging-20261123/verification.md。本机真实 CPython 离线 smoke 使用系统 Python 和 SDK 启动器沙箱，不使用私有 glibc 或固件；本地产生的 wheel 仅安装到新建临时 venv，无 PyPI 访问。
