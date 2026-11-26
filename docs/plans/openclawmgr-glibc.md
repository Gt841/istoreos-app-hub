# OpenClawMgr 私有 glibc 运行时改造

目标：按照用户新要求，参考 baidudrive/open-drive，使 Node/npm/OpenClaw 使用隔离 glibc；
安装和服务启动均要求 sqlite-vec 实际加载并通过向量查询。先前“允许 vec 缺失”的标准已撤销。

## 任务树与验收

- G1 参考与来源：核对显式 loader/library-path 模式，固定全部下载来源和 SHA256。
- G2 运行库包：新增 openclawmgr-glibc，仅安装私有运行库；执行真实 Prepare/install 命令验证输出。
- G3 Node 链路：固定官方 glibc Node，候选独立复制 loader/libraries；入口支持移动目录和 npm/fork 子进程。
- G4 事务集成：保留原有候选、快照、current/previous、失败回退；不复用旧 musl Node。
- G5 向量硬检查：sqlite-vec load、版本、vec0 插入和最近邻查询；启动管理器新 release 再检查。
- G6 验证：默认 shell/BusyBox 回归；x86_64 从旧 musl 升级、ARM64 新装；两台 Gateway、vec 查询、重启检查。
- G7 文档/恢复：归档实际结果和源码摘要，恢复测试临时文件/账号，保留已有 KSpeeder；不发布。

本地首次探测中，旧 baidudrive 1.0.6 的 x86_64 glibc 2.36 运行固定 Node 时 SIGSEGV；
open-drive 1.0.7 的 x86_64 glibc 2.39 成功，但该整包发布 URL 不存在。
因此使用可下载且有 SHA256 锁定的 Ubuntu 2.39 libc6，按架构组合已发布的 GCC C++ 运行库。
只把字节一致、实际 Node/vec 探测成功的运行库作为候选，不从另一程序“文件存在”推断兼容。

所有目标与测试结果见 `docs/evidence/openclawmgr-glibc-20261123/verification.md`。
旧三轮 musl 验收结果单独保留；本次 glibc 改造是用户追加范围，最多三轮检查，不无限重试。

## 任务执行结果

- G1–G5 已实现；固定来源/摘要、两架构真实解包复制、入口与 npm/fork、事务和 vec 硬检查均有回归/实测证据。
- G6 部分通过：x86_64 升级、认证 Gateway、服务 UID 下 OpenClaw 自带 vec 加载器查询、缺失 vec 拒绝启动和恢复后的管理器 restart 全通过。ARM 最终候选 npm/GNU 原生模块/vec/CLI 通过并监听 Gateway，但 health 未通过，事务自动回滚，不能宣称双架构全通过。
- G7 已完成：实际结果和源码摘要归档，两台临时服务、账号与系统文件恢复，ARM KSpeeder 文件校验与基线一致；未发布。

## 三轮检查及停止条件

1. x86 下载超时保留旧 Gateway；ARM 完整安装期间自动重启，正常 preparing 恢复成功。未确认重启根因。
2. x86 硬检查发现 npm 优先读取宿主 ldd，选错 musl Sharp；修正为入口与共享环境强制 npm_config_libc=glibc。ARM 非 root/fork 向量轻量探测通过。
3. x86 最终候选提交并全链路通过；ARM 仅追加一次修正 libc 选择后的完整安装，向量/CLI 通过但 health 回滚。本轮没有再次重启。诊断发现 health CLI 每次总时限仅 10 秒；改为 60 秒、最多 3 次并增加 11 秒延迟回归，未再完整安装。

已按最多三轮检查约束停止全量重试。健康时限最后修正未做设备复验，ARM 独立认证 health 和正式提交仍未通过。后续在稳定 ARM 设备验证是未完成验收项，不用监听日志或独立向量探测替代。
