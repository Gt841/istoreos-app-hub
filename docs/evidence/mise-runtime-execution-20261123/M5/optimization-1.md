# M5 优化 1（进行中）

实际自检发现两项问题，未降低 Gateway/向量/回滚验收标准：

- x86_64：协调器被 SIGKILL 后，recover_install 返回 0，但实际 npm 安装子进程仍存活。见 x64-interruption-red.json。原本机夹具会主动 killpg，掩盖了此缺口。
- ARM64：第三方 Matrix 原生库的 GitHub 生命周期下载在原 900 秒上限内只完成约 60%，安装退出 124，未激活应用。共享 SDK 安装成功独立保留，不算应用成功。

修复：OpenClaw 命令复用公共 system.run 的持久进程握手，在私有事务中记录进程身份。恢复先原子关闭命令登记目录，再按 boot ID/PID/start/session 回收进程，最后恢复数据和删除候选。x86_64 同一真实 npm/SIGKILL 回归已通过，见 x64-interruption-green-r1.json。本机 Lua 是夹具，不能验证 nixio，此回归保留为目标设备测试 interruption-device.lua。

ks-cli 0.9.1 的 npm 适配加速 registry，Git 通过显式适配；它保留第三方脚本任意 HTTP 下载的原目的地。未把 npm 加速宣称为所有生命周期流量加速。依赖安装单独给出 3600 秒有界时限，其他命令保留原时限，期间仍可取消并恢复所属进程。ARM64 正在复验。

仍使用源码/二进制直部署，不构建 IPK/APK。包验收留待人工确认。


ARM64 首次直部署复验已于设备时间 14:13:58 完成 Gateway 认证 health 并提交，初始 disabled 状态保持停止。随后显式 start 和 Gateway/OpenClaw loader/vec0 查询通过。

固定 Matrix 0.4.0 原生下载新增标准 npm script-shell 适配：只匹配确切版本、postinstall 命令、工作目录和脚本 SHA256；其他脚本原样交给 /bin/sh。两架构原生文件按 GitHub release API 的官方 SHA256/字节数缓存和复验，已完成真实缓存/损坏拒用测试。缺缓存使用选定的 ks-cli download 或源站下载；保留原脚本的可选 Matrix 下载失败语义，实际可用性另记录，不替代 Gateway/Sharp/sqlite-vec 必选检查。ks-cli accelerated 原生下载探测曾返回 502，不能记为下载加速成功。

一次 ARM64 测试调度重叠：旧布局测试在依赖边界测试尚未结束时被启动，触发预期的应用锁拒绝；测试 finally 的 service stop 干扰前一健康检查。此轮边界/旧布局结果不得计为通过。先恢复服务并等待原进程退出，再串行复验。


优化 1 的新增实际检查已通过两架构：Node24.22.1/npm11.19.1 固定公共实例、非 root Gateway、OpenClaw memory-host loader 的 vec0 最近邻、缺 SDK/vec 拒启、真实 legacy 升级及卸载保留数据、切换后向量故障自动恢复旧 release/认证/数据、取消/协调器 SIGKILL 恢复及公共 SDK worker 所属取消、另装 Node24.21.0/npm11.12.1 和 r2 库后旧 Gateway PID/绑定不变。

最终本机 59 项测试，58 通过、1 项本机 vec 扩展条件跳过，后者由真实设备向量查询覆盖。设备普通重启已发起，等待重启后的最终自动启动/向量和 LuCI 检查。本轮继续保留源码直部署、包验收待人工的边界。
