> 后续增量：Rust/Zig 的当前验收见 ../mise-rust-zig-design-20261123/verification.md；本报告保留加入 Go 时的历史结果。

# mise Go 与功能收敛验收

状态：设计预览通过；不是正式安装器或设备验收。

- 新增 Go 筛选、示例版本、复核/任务、默认只读与保护、wrap 下载和清理。
- 受控工具目录统一 Node/Python/Go 的名称、版本、ABI 与检查说明；没有开放任意 mise 插件。
- Go 使用标准工具链，不选择 libc、不引用私有 glibc；提供 go/gofmt/shell。
- Go wrap 将 HOME/GOPATH/GOBIN/构建、模块和临时缓存放在持久磁盘；固定 GOROOT、GOTOOLCHAIN=local、GOENV=off。默认关闭 CGO，保留调用者显式开启；需要自备匹配的 C 工具链和库。
- 删除应用页、模拟应用数据与统计、应用引用删除保护；保留全局默认和已安装环境→glibc 的保护。删除环境前明确提示 wrap 失效影响。
- QuickStart 7 个复制源码的摘要与上轮一致；宿主 CSS、主题服务未改动。

## 检查

- 类型检查、28 项模型/wrap 沙箱测试、Vite 构建通过，依赖/缓存/产物均通过 SSD 缓存入口；详见 checks-round-1.log。
- 17 组产品浏览器检查和 6 组 QuickStart 宿主检查通过，页面错误为零。
- Go 的 x86_64、aarch64 示例均覆盖安装→使用→下载→删除与默认保护；模型验证没有 glibc 副作用、拒绝无效 ABI/版本。
- Node/Python 回归覆盖复核、重复安装、失败重试/取消、中断恢复、刷新续看、清理、离线和加速降级。
- 两轮浏览器检查：第一轮全部通过，但人工发现截图捕获菜单过渡动画；第二轮仅修改截图等待方式，等待原宿主动画结束后截图，17 组再次通过。未修改产品或宿主代码。
- 手机 Go 深浅主题截图与弹窗已人工检查，三种语言筛选无横向溢出。

## 范围限制

当前安装和验证状态为内存示例。未下载/安装真实 Go，未调用实际 ks-cli，未在 x86/ARM 设备编译 Go 或验证 Go 工具链 ELF/内核兼容。wrap 沙箱使用假解释器验证参数和环境，不能替代实际 Go/CGO 验收。正式后端须根据真实产物检查平台并完成纯 Go 编译执行；CGO 不在本轮范围。

依据：[mise Go](https://mise.jdx.dev/lang/go.html)、[Go cgo](https://pkg.go.dev/cmd/cgo)、[Go 发布目录](https://go.dev/dl/)。示例 Go 版本不表示自动跟踪最新版本。

预览：http://127.0.0.1:5180/mise
