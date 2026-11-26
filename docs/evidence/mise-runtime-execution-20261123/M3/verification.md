# M3 首次执行记录：三次优化后未通过

历史状态：用户随后授权继续，本里程碑已通过，见 [续作报告](../M3-resume/verification.md)。

M2 已通过后开始 M3。当前两台各有五个真实 Node/npm 实例，但 x86 加速装包验收未通过；已按用户“最多优化三次”的要求停止，未进入 M4–M8。不存在正式包安装、LuCI 产品接入或新 OpenClaw Gateway/sqlite-vec 通过的结论。

## 任务树与验收标准

1. 双架构固定 Node SDK，验证 glibc/musl、多版本和实际 npm。
2. 默认使用配套 npm；受控独立 npm 形成新实例，实际 engines 不兼容时失败回滚。
3. 固定 wrap/CLI exec，持久 HOME/XDG/state、npm prefix/cache/TMP；普通 UID 可运行，不能改 SDK 或其他 UID 的目录。
4. 真实 mise 登记同一 SDK，不再次下载或切换全局默认；ks-cli npm/git 使用确定的原生入口，参数、stdin、fork、生命周期与退出码保持。
5. 验证默认保护、卸载/重装、旧配置与 AgentFlow 兼容；两台全部必选项通过后才进入 M4。

完整标准沿用 `docs/product/mise/runtime-milestones.md` 的 M3。本轮实现涉及核心、适配器和目录协议；没有修改产品设计预览或 OpenClaw 源码。

## 已实现

- Node 安装适配器、不可移动的最终 SDK 路径、候选 inode 所有权和实际探测；只有探测与 mise 登记完成、持久提交后才发布 wrap。
- SDK 内的固定 Node/npm/npx/git 入口；GNU Node 使用私有 loader 和 execPath 预加载，子进程返回同一启动器。普通用户执行不依赖管理页面或修改 `/root`。
- JSON `prepare-user` 管理动作、普通 UID 的目录隔离、应用自有 `ISTORE_RUNTIME_HOME`；支持 HOME 中空格及引号；拒绝符号链接、路径回退和不安全目录。不可访问的继承工作目录才转入持久 HOME，可访问项目目录保持。
- HOME/XDG/state、mise state、npm 前缀/缓存及 TMP 按 UID 和实例固定，清除会干扰版本选择的 Node/mise 环境变量。安装和运行没有设置宿主全局 LD_LIBRARY_PATH。
- 独立 npm 11.12.1 使用官方注册表 metadata 和 SHA512，另锁定 SHA256；复合 artifact_set 包含 Node 与 npm。受控清单从 36 扩展为 44 项，revision=`e690f3de941c47d42c76ff360b19bc96cbd8435f386b6dcbc8e9da3d3892237a`。
- 为旧 ks-cli 的五个只读 UCI 查询提供管理器持有的公开配置，仅包含端口、启用状态和空 cache 字段；其他 UCI 操作转交原命令。原 KSpeeder 配置仍为 0600，命令保持原 UID；没有复制凭证或以 root 运行用户 npm。
- mise 登记目录对普通用户只读；精确解绑先收集所有属于本 SDK 的链接，再删除，避免留下依赖长键的别名。没有调用 mise uninstall 删除共享 SDK。

## 实例矩阵

两台均完成并保留五个实际安装，见各自 `*-final-verification.json`：

| Node | ABI | npm | x86_64 | aarch64 |
| --- | --- | --- | --- | --- |
| 24.21.0 | glibc | 配套 11.19.0 | 已安装/探测通过 | 已安装/探测通过 |
| 24.21.0 | glibc | 独立 11.12.1 | 已安装/探测通过 | 已安装/探测通过 |
| 24.21.0 | musl | 配套 11.19.0 | 已安装/探测通过 | 已安装/探测通过 |
| 24.22.1 | glibc | 配套 11.19.1 | 已安装/探测通过 | 已安装/探测通过 |
| 24.22.1 | musl | 配套 11.19.1 | 已安装/探测通过 | 已安装/探测通过 |

x86 根为 `/mnt/mise-runtime/Runtime`；ARM 根为 `/mnt/nvme0n1-1/Configs/mise-runtime-acceptance-20261123/Runtime`。新 SDK 与旧 mise HOME 分离，管理器源码在各设备 M3 隔离 share 目录，不冒充已安装系统包。

## 三次优化与实测

| 轮次 | 修改及结果 |
| --- | --- |
| 首次自检 | 两台首个 GNU Node 探测被 HOME 父目录权限检查拒绝；真实 `/mnt` 为 root 持有的 sticky 1777 |
| 优化 1 | 允许受保护 sticky 父目录，仍拒绝不安全 HOME 本身；两台 GNU 安装通过，ARM 五实例全部完成。ARM 前 28 项运行检查通过，普通 UID 继承不可访问 `/root` 工作目录失败。x86 musl 下载速度过低失败，候选清理并保留旧实例 |
| 优化 2 | 不可访问工作目录转入持久 HOME，补 XDG/state 隔离；两台各完成五实例。两台前 31 项运行检查通过；非 root ks-cli 无法读取 0600 的原 UCI 配置，npm 加速失败 |
| 优化 3 | 加入非秘密只读 UCI 兼容视图和公开只读 mise 登记；ARM 全部 34 项运行检查、实际不兼容 npm engines 回滚、五 SDK mise exec、普通 UID mise exec、默认保护、实际卸载/缓存复装、Git 参数及 Git/npm 退出码通过。x86 前 31 项通过，npm 加速请求被网关 HTTP 403 拒绝，M3 未通过 |

关键原始文件：`192.168.30.93-runtime-opt3.json`、`192.168.30.93-engines-opt3.json`、`192.168.30.93-compatibility-opt3.json`、`192.168.30.93-reinstall-opt3.json`、`192.168.30.93-command-status-opt3.json`、`192.168.30.7-runtime-opt3.json`。

运行检查覆盖：五实例版本/ABI/npm、冲突 HOME/PATH/NODE_OPTIONS、参数中的空格/引号/字面 `$()`、stdin、execFile/fork、shell、私有 HOME、安全目录拒绝、两 UID 执行与隔离、源站/加速 npm、真实 npm 安装生命周期及删除二进制后拒绝回退。x86 在加速步骤停止，后续 lifecycle/移走二进制和额外 engines/兼容/卸载复验仍未执行，不能借 ARM 结果代替。

engines 负例修改了官方 npm 的测试副本，要求 Node >=99，重新计算夹具摘要后仅用于隔离候选；未加入生产清单。ARM 实际执行到 engines 拒绝，清理候选，已有 Node 摘要、状态修订及锁均符合预期。

## 下载与环境的真实限制

ARM 实际 SDK 下载记录既有 origin，也有 admin_proxy。x86 的 musl 24.21.0 在 ks-cli auto 选择 admin_proxy 后仍过慢，触发工具的最低速度错误。随后开发机从同一固定上游下载两个 x86 musl 归档，本机及设备 SHA256 均与锁一致，预置缓存后由安装器复验、解包、运行；不把缓存安装称为该设备再次完整下载。对应 `node-*-x86_64-musl-upstream1-cache-preparation.json`。x86 24.22.1 GNU 归档仍由设备实际下载完成。

为复用 ARM 已有 KSpeeder，本轮建立 x86 5003/5443 到开发机、再到 ARM LAN 端口的临时 SSH 转发。最后失败的请求为 `https://dl-npm.linkease.net:5443/is-number`，403 响应原文：

```text
mirror route is only available from localhost
```

直接 curl 同一路径也返回 403；两台代理环境变量均未设置。已经确定本次转发触发 localhost 限制，不能据此断言 Node/npm 或运行时安装本身出错，也不能把 x86 加速验收判为通过。后续应让 ARM 端连接从 `127.0.0.1` 进入，例如 ARM 本机回环的 SSH local forward 再接 x86 reverse forward；保持网关限制不变。此拓扑修正及复验属于下一轮，本轮未实施第四次优化。

## 停止现场与未覆盖项

- 两台各五个已验证并发布 wrap 的实例保留；没有未完成安装任务或遗留锁，boot ID 与 M2 重启后相同。最终剩余约 60.18 GiB / 48.14 GiB。
- 临时 SSH 转发进程 5833 经完整 argv/进程组核验后终止，x86 5003/5443 监听已消失，见 `x86-test-forward-cleanup.json`。
- ARM 原有 KSpeeder/AgentFlow 仍运行；受保护程序、旧配置和旧 helper 摘要复核一致，AgentFlow CLI 返回 `0.3.3-20260923-2ad19a3b`。完整的旧应用启动/代理命令回归尚未完成，不能由 PID/版本号代替。
- 补充诊断曾使用设备没有的 printenv，初份 x86 `*-final-state.json` 的代理变量显示不作为证据；后续 `*-final-verification.json` 用 nixio.getenv 重查。x86 原本未安装系统 mise 配置/helper，读取这两个文件报不存在属于已知 bootstrap 状态。
- ARM 混合诊断中旧 helper 网络探测超过 45 秒；单独记录为未完成，不能算兼容通过。只清理了包含私有 M3 legacy 脚本路径的诊断进程及其子进程，PID 5932/5919；未停止业务服务。
- 本机 Lua/脚本语法、44 项清单契约、Web TypeScript 检查通过，node_modules 实际位于 SSD。当前源码及证据均为未提交候选，无正式包安装、推送或公开发布；OpenClaw 接入和 M4–M8 仍待执行。
