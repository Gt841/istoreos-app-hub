# M1 公共契约验收

状态：通过。首次自检暴露 core:rust 隐式 rustup 行为，完成一次优化后两台复验通过。

交付：公共包职责、持久布局与旧 runtime_dir 兼容规则；Lua 5.1 校验模块；不含 scene 的生产 TypeScript 契约；36 项精确版本/构建/架构/ABI 产物锁；维护期锁生成工具和上游元数据快照。

- 两台目标均通过 50 项 Lua 契约测试，覆盖 npm/库修订/产物身份不覆盖、路径/字段/平台错误、禁止全局切换和独立 pip、过期/修订错误计划、收据与未知验证状态。
- 36 项清单逐项通过设备上的正式 Lua 模块校验；六语言每架构至少两个版本，GNU/musl 目标组合覆盖。产物数组与清单修订 SHA256 固定；上游原始元数据见 upstream-metadata.tar.gz。目录 available 只表示有产物，不表示 SDK 已在设备验证。
- 两台固定 mise 2026.8.14 均完成六语言 × 两个登记键的 link/where/exec 探测（共 24 个组合），路径指向原 SDK，两个键互不覆盖，探测用全局配置摘要不变。探测 SDK 是明确标注的假命令，仅证明登记协议；真实工具验证属于 M3/M6–M8。
- core:rust 不能直接用定制键：会调用 rustup。第一次优化采用 `http:istore-rust` 通用后端，正确链接已有 SDK，不再隐式安装。首次 ARM 超时产生的任务私有子进程已收拢；不影响主 AgentFlow/KSpeeder，受保护文件摘要再次核验通过。
- 生产契约 TypeScript 类型检查通过；没有改动设计宿主或 QuickStart 源码。

逐设备原始结果见 `<IP>-initial.json`、`<IP>-optimization-1.json`；首次失败未覆盖。应用/SDK 安装、运行库、正式包与 Web 接入均不属于本里程碑已通过范围。
