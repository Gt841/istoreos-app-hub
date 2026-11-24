# M4 续作验收记录

状态：未通过。用户授权续作后完成三次优化；双架构实际 IPK 编译与包内容审计通过，但 x86_64 的源码来源校验失败，因此未安装设备，未开始 M5–M8。

## 任务树与通过标准

1. 独立 feed/mirror 配置及自动检查。
2. 双架构各准确生成 mise、ks-cli、mise-runtime、luci-app-mise、app-meta-mise 五个包，源码锁、摘要、依赖、权限、资源和登记全部符合输入。
3. 实际安装后验证 LuCI 认证/ACL/CSRF、存储、安装、失败重试、取消/恢复、真实 wrap、删除/缓存、移动端/主题/焦点。
4. 旧 mise/AgentFlow/KSpeeder/SDK 兼容回归。全部通过才进入 M5。

## 三次优化与检查结果

1. 新增双架构独立 mirror 配置，只包含启用 feed；复用经 git fsck 的只读 canonical 对象种子，增加 mirror/feed 归属检查。12 项构建检查通过。实际构建随后暴露 ARM SDK 标签检出状态下 git pull 失败；两轮任务被明确取消并保留原始 failed 状态。
2. 增加可选 BASE_FEED_COMMIT，仅 mise profiles 使用；将 SDK 的 tag/branch 转成不可变提交后刷新。增加 tag、branch、非法值及未设置保持原行为的测试，15 项检查通过。真实构建通过 feed 更新，但失败于新 LuCI 和元包缺少 OpenWrt 扫描标记。
3. 为两个新包补充 call BuildPackage 扫描标记，沿用 QuickStart 的前端免二次压缩配置，增加包扫描检查。16 项构建检查通过；两台真实 clean SDK 构建均 success，十个 IPK 的内容审计均通过。最终来源审计发现 x86 metadata feed 未固定到声明的提交，整体仍未通过。未进行第四次优化。

构建器候选提交：`72adc1b9efc989d83f55e0ee3f0326f538458b7f`；补丁 SHA256：`21802448ef73a747ffa290df35912b5c170127c97b8ed27b8f8c6c6f05236bf2`。构建器在内网按 commit → release → deploy → verify 使用，未推送、未公开发布。app-hub 产品源码仍为工作树候选。

## 实际构建、审计与来源差异

- `mise-m4r3-x64-20261124T011600Z`：SDK 24.10.1 x86_64，build.status=success。五个包的元数据、依赖、ELF 架构、脚本执行位、规范注册链接、与源文件一致的前端 JS/CSS、ACL、目录/包归属通过。fetch 的 SHA256SUMS 全部通过。
- `mise-m4r3-arm64-20261124T011600Z`：SDK 24.10.8 rockchip/armv8 aarch64_generic，同样编译、fetch 和五包内容审计通过，五个 feed 的提交和 origin 均符合锁定输入。
- x86 的 istore_meta 预期 `4ead788a91cf95c23ff47396f6f81923142d9907`，实际 `07c4f21cf5c7daa77464f478440664c8d81f0189`。其余 feed 正确。详见 `x64-build-input-audit.json` / `arm64-build-input-audit.json`。TLS clone 中断后，SDK 的重试保留了未完成固定提交检出的仓库；构建器未在编译前核验这一事实，却记录更新 fresh。这是构建器的来源校验缺口，不能以编译成功或文件内容审计代替。没有更改真实的 success 状态来掩盖该差异。

候选包保留在 SDK builder 被忽略的 `artifacts/<BUILD_ID>/`；本目录保留原始 build.env、feeds.lock.tsv、状态、摘要、完整日志与独立审计 JSON。OpenLDAP 慢镜像通过官方 OpenWrt 源码镜像的相同 SHA256 归档恢复，未改变源码或校验值；见 `build-cache-recovery.json`。

## 页面与设备范围

前一阶段的 TypeScript/生产构建无 mock 导入及双设备开发后端数据检查仍有原始证据。本轮增加正式 LuCI 浏览器脚本、维护/中断故障测试、IPK 审计脚本、临时会话工具和可复用原始缓存验证工具；浏览器与设备安装验收尚未执行，不能算通过。四个注册 helper 沙箱检查通过，见 `registration-helper.json`，它不替代包安装验证。

两台设备完成安装前持久磁盘备份；本轮没有安装候选包，没有配置 Runtime-live，没有更改既有 SDK。ARM 保护基线文件 SHA256 全部相同，原 AgentFlow healthz=ok；boot ID 仍 e3eba56b-888b-44bf-a282-99e059afc7b5。x86 当前 boot ID 是 290c4092-c9f2-45bc-98ac-addb6dd920dc，与前次记录不同：根据 01:38:47 UTC 时的 uptime=3026 秒估算，启动发生在约 00:48:20 UTC，早于本轮 00:54:10 UTC 开始；未确定重启原因。其专用 ext4 磁盘仍自动挂载在 /mnt/mise-runtime，原五个环境目录仍存在，约 60 GiB 可用；没有声称本轮已对其逐个重新执行。详见 `protected-after-stop.json`。

本轮两组构建容器已自然结束；其他容器、共享缓存和 SDK 工作目录保留。正式建立的每台三种临时测试会话已销毁。会话准备工具最初因误判 ubus 成功空响应曾创建各一个未授予权限的会话，未用于测试，按创建时的 7200 秒超时自动过期；没有清理其他用户会话。5180 设计预览未调整。

## 下一步修复边界

在更新重试后、应用补丁前强制 fetch/checkout 所声明的不可变提交并校验 origin/HEAD，失败即拒绝编译；记录产物前再次校验。补充“clone 部分完成、固定提交 checkout 尚未完成”的故障回归，避免 SDK 返回成功却使用错误源。重新提交、部署，用新的 Build ID 构建，再执行设备安装与真实页面验收。该问题不需要产品语义决策；本轮按三次上限停在 M4。
