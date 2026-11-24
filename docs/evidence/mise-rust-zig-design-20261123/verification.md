> 后续增量：Java 的当前验收见 ../mise-java-design-20261123/verification.md；本报告保留加入 Rust/Zig 时的历史结果。

# mise Rust / Zig 增量验收

状态：设计预览通过。预览 http://127.0.0.1:5180/mise 。

## 交付

- 受控目录现包含 Node/Python/Go/Rust/Zig；五个筛选在窄屏换行，不修改复制的 QuickStart 宿主。
- Rust 示例 1.91.1/1.90.0：minimal（rustc、cargo、宿主 rust-std），x86_64/aarch64 的 GNU/musl。选择的是编译器宿主 ABI，不是输出目标；不管理 nightly、组件或额外交叉目标。
- Zig 示例 0.17.1/0.15.2：两架构标准归档，不选择 libc；zig cc/c++ 等参数原样传递，不自动配置 Rust/Go 的 C 依赖。
- wrap 显式语言适配器复用同一持久 HOME/公共目录逻辑。Rust 固定真实 rustc/cargo、RUSTC/RUSTDOC、版本+host triple；不调用 rustup 或修改共享 RUSTUP_HOME。Cargo_HOME、构建/临时目录按版本和工作目录隔离。
- Zig 固定 SDK lib 和二进制，设置持久的全局/本地缓存与临时目录。本地缓存按工作目录隔离；zig-out、直接 rustc 输出和显式参数仍由项目决定。
- 复用安装复核/后台任务/清理流程，不新增页面；默认仍只读且不可删除，Rust GNU 环境计入 glibc 引用，Zig 不引用 glibc；应用使用情况保持移除。

## 检查

- 官方元数据：两份 Rust channel manifest 的四个 host triple 均有 minimal 三组件；Zig index 的两个示例版本均有两架构归档。摘录见 upstream-artifacts.json。这不等于设备兼容认证。
- 类型检查、41 项模型/wrap 沙箱测试、构建通过，输出在 SSD；详见 checks-round-1.log。
- 17 组既有产品、6 组 QuickStart 宿主、8 组 Rust/Zig 浏览器检查通过，页面错误为零。
- 新流程覆盖 Rust 四种架构/ABI 组合、Zig 双架构的复核→任务→wrap 下载→清理；五种默认环境删除保护、语言切换字段重置、1440/390/320 深浅主题与无横向溢出。
- 第一轮均通过，人工发现手机长截图保留页面滚动位置，固定顶栏落在截图中间；第二轮仅修改截图测试，回到页首再拍摄，8 组编译器检查再次通过。产品/宿主代码没有为截图修改。
- 已人工查看第二轮 Rust 320 浅色和 Zig 390 深色弹窗，以及首轮 Rust 桌面安装弹窗。QuickStart 7 文件摘要与前轮一致，见 host-provenance.json。

## 范围限制

本轮没有真实下载/安装 Rust/Zig、没有设备编译运行，也没有实际 ks-cli 调用。wrap 测试使用 SSD 沙箱假解释器核对参数、环境及目录隔离，不能替代工具链执行验收。

正式安装器须检查具体 SDK 的 ELF/libc/内核要求、签名/摘要和组件可用性；GNU 工具链须提供私有 loader 启动器，Rust 必须使用实际 toolchain bin 而不是 rustup 代理，并将统一 RUSTUP_HOME 指向同一份工具链。Zig 必须保留完整 lib 并提供约定 bin/zig 入口。C 链接器、第三方本地库、项目自定义构建输出和交叉目标兼容性不在本轮承诺内。

参考：[mise Rust](https://mise.jdx.dev/lang/rust.html)、[Rust 平台支持](https://doc.rust-lang.org/stable/rustc/platform-support.html)、[mise Zig](https://mise.jdx.dev/lang/zig.html)、[Zig 下载](https://ziglang.org/download/)。Rust 版本为历史稳定版本设计样例，不宣称最新。
