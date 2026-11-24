> 后续增量：Python pip/venv 与 npm 高级选项验收见 ../mise-python-packaging-20261123/verification.md；本报告保留 Java 接入时的历史结果。

# mise Java 产品交互验收

状态：设计预览通过；预览 http://127.0.0.1:5180/mise 。

## 实现范围

- 第六个语言入口 Java；Temurin JDK 21/25 LTS，多版本并存，版本身份包含厂商、补丁版本和 build，UI 显示完整 JDK/LTS。
- 示例为历史已发布构建 temurin-21.0.9+10、temurin-25.0.1+8，不宣称最新或作为生产推荐。官方 GitHub release API 中确认双架构 GNU JDK 归档与 checksum 文件存在，见 upstream-fixed-artifacts.json。Adoptium latest API 的 403 原始结果保留于 upstream-artifacts.json。
- 初版固定私有 glibc，隐藏 ABI/厂商选择，明确说明不开放 musl、Maven/Gradle；API 拒绝不支持组合、浮动版本、其他厂商和未列出的 build。
- 复用复核、后台任务、详情、清理；全局默认只读且不可清理，Java 计入公共 glibc 引用。删除环境前提示固定 wrap 失效影响，不恢复应用使用情况功能。
- 使用页四个命令入口：java/javac/jar/shell，支持复制与脚本样例下载。固定 JAVA_HOME/JDK_HOME；TMPDIR 在持久 HOME；JAVA_TOOL_OPTIONS 保留原选项并追加默认 user.home/java.io.tmpdir，子 JVM 可继承。自定义 HOME 的空格可用，双引号在创建 HOME 前拒绝；显式 JVM 参数仍可覆盖默认属性。
- 从刷新后的任务结果查看使用方法时，同时选中该任务的语言，关闭弹窗即可看到新环境。

## 检查与迭代

- 第一轮：类型检查、49 项模型/wrap 沙箱、构建通过；既有产品 17 组、Rust/Zig 8 组、QuickStart 宿主 6 组通过。Java 6 组中 4 组通过、双架构刷新流程 2 组失败：关闭使用弹窗后仍停留 Node 筛选，无法找到已安装 Java 行。
- 第二轮：修复 showInstalled 的语言选择；类型检查、49 项测试、构建再次通过；既有产品 17 组和 Java 6 组全部通过。未改动 QuickStart 宿主源文件；7 个源码摘要一致。
- 最终覆盖共 37 组浏览器检查，页面错误为零。Java 覆盖双架构复核/刷新续看/下载与复制/默认保护/清理、首次同时准备 glibc、失败重试、无效请求、六语言切换、1440/390/320 深浅主题。
- 模型/wrap 覆盖 Java 双架构与两个 build、glibc 引用、默认保护、严格身份、java/javac/jar 参数与 shell 子进程、持久 HOME、带空格自定义 HOME、JVM 选项保留和拒绝双引号路径。
- 人工检查 Java 320 浅色列表、390 深色使用弹窗、桌面安装弹窗与第二轮手机深色安装截图。脚本、构建、依赖和临时目录通过 SSD 缓存入口。

## 验收边界

这是产品交互预览。没有下载/安装真实 JDK，没有执行真实 JVM、javac、jar，没有在 x86/ARM 设备验证，也没有实际调用 ks-cli。本机无 java/javac；wrap 测试使用假解释器验证参数和环境，不等于已验证 JVM 实际属性。

正式后端须使用当时受维护的版本目录，验证归档完整性及精确身份，将发布 build 映射到实际 mise 路径/收据；验证完整私有 glibc JVM 原生库（含 libjvm.so/JNI/TLS）、用户/临时目录与编译打包运行。需要 Maven/Gradle 的应用自行管理其工具与缓存。显式命令输出位置仍由应用/项目决定。

参考：[mise Java](https://mise.jdx.dev/lang/java.html)、[Temurin 21 发布](https://github.com/adoptium/temurin21-binaries/releases/tag/jdk-21.0.9%2B10)、[Temurin 25 发布](https://github.com/adoptium/temurin25-binaries/releases/tag/jdk-25.0.1%2B8)、[Java 启动器](https://docs.oracle.com/en/java/javase/25/docs/specs/man/java.html)。
