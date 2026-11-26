# 运行时环境交互预览

Vue 3 + TypeScript 页面，遵循 QuickStart 视觉/交互与 LuCI 挂载模式。本目录同时维护设计预览和正式 LuCI 入口。下文的设计预览使用示例数据，不调用设备；正式入口连接 `mise-runtime`，只启用已实现的真实能力。阶段验收状态见 [里程碑](../../../docs/product/mise/runtime-milestones.md)。

正式入口通过 `apps/mise/tools/build-web.sh` 构建，生产资源由 `luci-app-mise` 持有，挂载到 `/cgi-bin/luci/admin/services/mise`，使用系统原有宿主。构建命令（从仓库根目录执行）：

```sh
/var/cache/build-cache/run.sh -- bash apps/mise/tools/build-web.sh
```

正式资源不包含设计宿主或 mock 服务。当前核心启用 Node/npm；其他语言的预览交互不代表设备能力已验收。旧 `mise-istore` 的本地执行与 ks-cli 下载接入规则见 [运行时契约](../../../docs/product/mise/runtime-contract.md)。

从 istoreos-app-hub 根目录：

```sh
./scripts/ui-design-prepare.sh
./scripts/ui-design.sh start mise
./scripts/ui-design.sh status mise
./scripts/ui-design.sh logs mise
./scripts/ui-design.sh stop mise
```

打开 http://127.0.0.1:5180/mise 。`ISTORE_UI_DESIGN_PORT` 可改独立端口；`ISTORE_UI_DESIGN_HOST` 默认 0.0.0.0，可设 127.0.0.1 仅本机访问。预览没有设备权限，端口仍只应暴露给需要评审的人。Node 24+、npm、curl、ss、flock、setsid、Python 3 和统一 SSD 缓存入口为开发环境要求。

prepare 通过 /var/cache/build-cache/run.sh 在项目专属 work/mise-web-deps 执行锁定 npm ci；源码目录的 node_modules 为指向该 SSD 目录的忽略链接。已有非本预览 node_modules 不覆盖。Vite cache 和正式构建输出也在 SSD，构建不依赖相邻 QuickStart 源码。脚本只管理自己记录且身份匹配的进程，端口冲突不回收其他监听者。

```sh
/var/cache/build-cache/run.sh -- npm --prefix apps/mise/web run typecheck
/var/cache/build-cache/run.sh -- npm --prefix apps/mise/web test
/var/cache/build-cache/run.sh -- npm --prefix apps/mise/web run build
MISE_DESIGN_EVIDENCE="$PWD/docs/evidence/mise-design-20261123/round-N" \
 /var/cache/build-cache/run.sh -- node apps/mise/web/tests/browser.mjs
```

浏览器测试使用 Playwright 与已有 Chromium；可用 PLAYWRIGHT_CHROMIUM_EXECUTABLE 指定路径，不自动安装浏览器。切换场景在右下角；任务存在预览服务内存中，刷新/关闭页面不中断，停止服务后重置。示例会话最多 100 个，服务长期重启或达到上限可能回收旧会话。场景切换重置本会话，故障只注入一次。

产品组件为 src/RuntimeApp.vue；服务契约在 src/services/runtime.ts。src/design 是独立宿主、模拟数据与服务，生产挂载 src/main.ts 必须显式提供真实 adapter，不能隐式启用示例数据。

设计基线与任务树见 docs/product/mise/；验收见 docs/evidence/mise-design-20261123/。本轮不改变现有 mise 运行库包，不发布 LuCI/IPK。

## 版本使用方式（修订）

全局默认只读展示；应用自行决定固定版本，本页不修改应用版本。每个环境提供“使用此版本”，可复制 Node/npm、Python/pip、Go 和 shell 命令，下载 wrap 脚本样例。样例约定 HOME/缓存/mise 数据放在持久分区，应用可显式指定 ISTORE_RUNTIME_HOME；不在预览中创建真实环境或入口。

QuickStart 正式样式声明已同步到 src/styles/quickstart，来源摘要及 MIT 许可证随文件保存。可用 scripts/sync-mise-quickstart-style.py --source /path/to/quickstart 更新，日常构建无需该 checkout。

## 直接复用 QuickStart ui-design 宿主

src/quickstart 保存完整复制的设计宿主、宿主/shell CSS、原版 ThemeSelector 与主题服务、正式颜色与字号文件。宿主 Vue 只增加 mise 导航接入；其余六个文件保持原文。原版菜单搜索、SVG 导航、手机菜单及主题交互直接运行，旧的自制宿主样式已移除。

复制/更新：`python3 -B scripts/sync-mise-quickstart-host.py --source /path/to/quickstart`。来源与变更见该目录 sources.json，MIT 许可保留。正式 LuCI 部署使用系统真实宿主；此复制内容仅进入设计预览。

## Go

Node/Python/Go 的受控能力目录在 src/domain/catalog.ts。Go 选择版本即可，隐藏 libc/npm；标准工具链不引用私有 glibc。wrap 支持 go/gofmt/--shell，所有可写目录在持久 HOME 内；GOTOOLCHAIN=local 固定工具链，GOENV=off 不读取持久 go env，默认 CGO_ENABLED=0，调用者可显式开启并自备 C 工具链。

“应用使用情况”、应用计数及模拟引用已移除；清理环境须确认 wrap 失效的影响，全局默认和被环境引用的公共库继续受保护。当前依然是交互原型，Go 也没有真正安装；沙箱假解释器测试不等于真实 Go 编译或 x86/ARM 设备验收。本轮证据见 docs/evidence/mise-go-design-20261123。

## Rust / Zig（当前追加）

受控目录现支持 Node、Python、Go、Rust、Zig。Rust 只提供 minimal（rustc/cargo/宿主标准库），选择宿主 GNU 或 musl，不管理 nightly/附加组件/交叉目标；wrap 固定实际 rustc/cargo，并隔离 CARGO_HOME、构建目录与临时目录。公共 RUSTUP_HOME 由未来安装器维护，wrap 不写共享工具链或调用 rustup。需要的 C 链接器或本地库由项目自行准备。

Zig 标准归档不区分安装 libc，支持 zig/zig cc/c++ 等参数透传；构建目标由命令决定。wrap 设置 ZIG_LIB_DIR 和按版本/工作目录隔离的持久缓存，不重定向 zig-out 等显式产物。

两者都复用既有复核、任务、默认保护和清理流程。仍然是设计预览，没有真实 Rust/Zig 编译验收；官方元数据核对和测试证据见 docs/evidence/mise-rust-zig-design-20261123/。

## Java（当前追加）

受控目录增加 Java：Temurin JDK 21/25 LTS，示例为已发布的固定构建，不宣称最新。初版仅 glibc，暂不管理其他发行版/JRE/musl/Maven/Gradle。环境身份包含发行版、完整补丁版本、构建号、架构和 libc。

四个使用入口：java、javac、jar、shell。wrap 固定 JAVA_HOME/JDK_HOME，并通过 JAVA_TOOL_OPTIONS 默认设置持久磁盘上的 user.home/java.io.tmpdir，保留调用者其他选项；显式 JVM 选项仍可覆盖。自定义 HOME 支持空格，双引号路径在创建目录前拒绝。不自动改变编译产物输出位置。

Java 与其他语言共用任务/清理流程，全局默认只读且保护，Java 环境计入 glibc 引用。当前仍为交互预览，未安装或执行真实 JVM；证据见 docs/evidence/mise-java-design-20261123/。可使用相同 SSD 入口运行 tests/java.browser.mjs。

## Python 应用依赖与 npm 高级选项（当前修订）

Python 安装包含配套 pip/venv，pip 版本不单独选择。详情区显示回传的版本、venv 可用性与来源；未读取时明确显示未知。本预览的数据来源是设计样例，不表示实机探测。

使用弹窗可填写应用的持久磁盘虚拟环境目录，复制 --create-venv、--venv ... pip install -r requirements.txt、python app.py 和 shell 命令。下载的 Python wrap 样例包含本地 venv 创建与归属验证；调用仍经过固定 SDK 启动器，未保留 venv/loader 信息时失败。共享 pip 只用于查询；应用依赖在独立环境中安装。已有目录不覆盖，不自动导入其他方式创建的环境。

npm 的配套版本始终展示，独立版本选择已移入默认收起的高级选项。

相关任务树见 docs/product/mise/python-packaging-plan.md；证据见 docs/evidence/mise-python-packaging-20261123/。npm test 新增 tests/python-venv.test.ts：使用本机 /usr/bin/python3 的 ensurepip/venv 进行离线沙箱测试，需要这些模块；不会访问 PyPI、修改系统 Python 或部署设备。浏览器增量 tests/python-packaging.browser.mjs 使用相同 SSD/证据目录入口。
