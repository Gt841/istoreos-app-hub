# mise 运行时执行证据

当前状态以 [execution-state.json](execution-state.json) 为准。M1–M6 通过；M7 功能及 x86_64 正常重启验收通过，ARM64 重启待验收；M8 未实施。源码直部署验收与历史安装包验收分开记录，当前候选包仍待人工确认后编译和检查。

- [产品目标与里程碑](../../product/mise/runtime-milestones.md)
- [本机 iStoreEnhance / ks-cli 与真实页面验证](M7-resume2/verification.md)
- [x86_64 正常重启验收](M7-reboot-x64-20261124T100547Z/verification.md)

Git 保存文本报告、结构化结果、校验摘要及 Markdown 报告直接引用的截图。完整截图集合、原始下载/源码归档、构建环境快照和临时二进制保留在本机原始证据目录，不随代码提交。历史失败结果保留，不把后续修复改写为首次通过。
