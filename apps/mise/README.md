# 运行时仓库与依赖准备

默认持久仓库 `/mnt/<硬盘>/Configs/Runtime`，管理员默认 HOME 为 `<仓库>/home`。应用可显式指定自己的持久 HOME；旧兼容 `runtime_dir` 的实际管理 HOME 在设置页显示。

## 切换仓库

“存储与设置”选择硬盘目录或自定义目录，确认后切换当前仓库。旧目录完整保留，不复制、删除其 SDK、库、HOME、缓存或记录。新目录为空则初始化；选回已有仓库则复用其内容。已有环境不再阻止切换，安装、修复、清理或中断事务会阻止切换。旧磁盘离线时仍可选择另一块有效磁盘。

保存后手动重启相关应用，或重启系统。已接入的 OpenClaw、AgentFlow 会准备当前仓库所需的固定依赖。正在运行的进程可能仍使用旧环境，手写绝对路径脚本仍指向旧目录，需要自行调整。新 HOME 不复制旧登录信息，工具可能需要重新登录。应用业务目录保持原位置。

## 公共运行库

glibc 使用固定来源与 SHA256 配方，在仓库的 `libraries/<库ID>` 私有安装，与系统 musl 隔离。按具体版本/修订被 SDK 引用，不提供系统 libc 替换。

安装 GNU SDK 时按需准备公共库。“检查 / 修复”在后台校验文件，缺失或损坏时按原配方恢复；没有公共库时也可单独准备。仍有环境引用的库不可普通清理。无引用的库清理后，下次安装 GNU SDK 会重新准备。修复使用候选目录，保留原目录直到事务成功；失败、取消或恢复中断任务会还原其原有目录。修复后建议重启相关应用。

## 应用开发接口

应用通过 root 管理入口发送固定 JSON 请求，不修改全局语言版本：

```json
{"op":"ensure","entry":"目录中的准确条目ID","library":"准确的GNU库ID","source":"ks-cli"}
```

请求到 `/usr/sbin/mise-runtime request` 的 stdin。musl/native SDK 不传 library。返回 `task`、`owned`、`waiting`；复用活动任务、等待后再检查自身依赖。可使用 `/usr/share/mise-runtime/lib/dependency-client.lua` 的 `ensure` 等待适配器实际执行验证，成功后才更新应用绑定。调用方必须验证当前仓库未变化。

修复库使用 `library-repair`，传 `id` 和明确的 `source`。与安装共用任务锁和取消/恢复机制。加速依照 ks-cli / iStoreEnhance，归档仍按固定 SHA256 校验，npm 保留自身完整性校验。

root 读取私有 UCI；需要非 root 检查当前仓库的入口使用 `active-root.current()`。设置保存及应用准备时发布 `/var/run/mise-runtime-root.json`，该公开文件只有仓库路径，不暴露 UCI 内容或登录凭据。

后台管理任务在其子进程中明确使用当前仓库的 `home`。即使应用通过 procd 以 root 准备依赖，并继承了应用账号的 HOME，也不会将安装与探测写入应用目录。调用方的 HOME 不变，应用运行时仍使用自己的持久 HOME 和专用 UID。

目标、任务树及验收记录见 [实施计划](../../docs/plans/runtime-repository-switch.md) 和 [验收记录](../../docs/evidence/runtime-switch-20261125/verification.md)。不自动重启任意业务，也不扫描或登记应用使用情况。
