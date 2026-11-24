# M7：Go/Zig 执行记录

后续网络验证：已证明 KSpeeder/ks-cli 可以加速该 sumdb 请求，两台设备均通过真实模块下载和校验，见 [加速路径报告](../M7-resume1/verification.md)。x64 本次临时复用 ARM 服务，M7 其余验收仍未完成。以下保留当时的失败事实。

结果：**未通过**。M6 已在 [续作报告](../M6-resume1/verification.md)中完整通过；按此前 M1–M8 自动推进授权进入 M7。三轮优化后的普通用户场景仍有必选项失败，按用户约定暂停，M8 尚未开始。

## 已完成与未完成

| 检查 | x86_64 | aarch64 | 证据 |
| --- | --- | --- | --- |
| 固定官方原始 SDK 下载缓存，SHA256/字节数核验 | 通过 | 通过 | `*-prefetch.json`；开发机预取不记作设备加速 |
| Go1.26.10/1.27.4、Zig0.15.2/0.17.1，完整现场安装与 mise 登记 | 四实例通过 | 四实例通过 | `*-install-matrix.json` |
| 安装器实际版本/ELF架构/环境、最小项目编译与执行 | 四实例通过 | 四实例通过 | 上述收据 probes，程序真实退出37；不是只查版本 |
| 官方Go归档合法文件名与恶意路径/链接/类型/重复项回归 | 18项通过 | 18项通过 | `*-archive-contract.json` |
| 普通UID65001：Go1.26环境/持久路径、CGO透传、另一UID缓存、gofmt、编译/显式输出、固定Go子进程前的准备 | 前16项通过 | 尚未执行 | `x64-device-initial.json`；完整程序运行在后续检查，未冒充已通过 |
| Go1.26普通用户的真实公开模块获取 | **失败** | 尚未执行 | `x64-device-initial.json` 第17项 |
| Go1.27普通用户、Zig用户编译/C/C++、完整缓存矩阵 | 尚未执行 | 尚未执行 | 测试脚本已准备，未因 SDK 探测通过而继承为通过 |
| 正式原生工具链页面安装/使用与M7重启验收 | 尚未执行 | 尚未执行 | 浏览器脚本仅语法检查，未运行 |

第三轮实际阻塞：`github.com/google/uuid@v1.6.0` 的模块信息已获取，但 Go 校验 go.mod 时访问 `https://sum.golang.org/lookup/github.com/google/uuid@v1.6.0`，直连超时，Go 返回失败。没有关闭校验或把部分下载记作成功。x64 原测试环境没有 KSpeeder 常驻服务，先前已明确按源站路径测试；ARM 的 ks-cli Go 装包尚未执行。需要后续解决实际校验服务网络通路，再继续完整矩阵。

## 优化记录

1. 初始官方 Go 归档在解包前被拒绝，因文件名包括合法的 `!` 模块转义和 `Þ` UTF-8 测试文件。原白名单只允许ASCII。增加这两类字符，仍拒绝 ASCII 空白/控制/反斜杠/引号/绝对路径/遍历与链接逃逸；以两份实际官方归档和恶意输入回归验证。见 `archive-name-diagnosis.json`、`tar-name-representation.json`、`*-initial-failed.json`。
2. Go 设置 `GOENV=off` 时，`go env -json` 将环境文件路径显示为空。修正错误的 `off` 字面断言，但新的“显式写入必须失败”断言仍失败。见 `go-env-diagnosis.json`、`*-opt1-failed.json`。
3. 实际 Go 的 `GOENV=off` 只关闭配置读取，显式 `go env -w` 仍会写入并返回0。固定 wrap 增加明确拒绝 `env -w/-u` 的策略，包括 `-C` 形式；进程级变量/正常编译参数仍保留。随后两架构四 SDK 安装/真实编译均通过，但普通用户模块校验的源站网络检查失败，不能把 M7 标为完成。见 `go-write-disabled-diagnosis.json`、`*-opt2-failed.json`、`*-direct-opt3.json`。

先前写入探测只在本任务创建的 Runtime-live/users/0/home 中生成了 `GOTOOLCHAIN=auto`。已核对内容、UID和探测时间窗口，私有备份后清理；见 `*-probe-cleanup.json`。没有进入原用户的 HOME 或改 mise 全局默认。测试 UID65001 的模块部分下载保留在专属持久缓存，Go 未发布未经校验的成功结果。

当前 Go/Zig SDK 为经过基础探测的开发候选，固定入口和下载缓存保留。源码直部署有逐文件备份和 rollback 命令，不删除应用数据或其他 SDK。IPK/APK 仍待人工验收后人工编译，没有公开发布。M6 的 pip 隔离和现有 Gateway 收尾复验记录见 `*-pip-close.json`、`*-gateway-close.json`，配置与业务基线见 `*-system-close.json`。
