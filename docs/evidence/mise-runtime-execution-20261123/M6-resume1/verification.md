# M6 续作：pip 配置隔离

结果：**M6 通过**（用户明确要求继续后，一次优化通过）。pip 配置隔离、实际生产 LuCI 和双架构重启验收全部通过。历史三轮失败记录保留在 [M6 原报告](../M6/verification.md)，不覆盖当时的失败事实。

根因：设备实际 pip26.3 的 `Configuration.items()` 返回 `(配置文件路径, 选项字典)`，旧代码却按 `(section.option, value)` 遍历，得到的选项名只是 `conf`，始终无法识别 `install.target`。在选定 venv 中运行检查仍不能解决结构误判。实际探测已确认 venv 的 prefix/解释器/配置路径均正确，退出23也原样保留，排除了启动器与退出状态假设。见 `diagnosis.json`。

修复：仍在选定 venv 中执行检查，改为 `Configuration.get_value()` 读取 global/install/环境层的 target、prefix、root、python、user。该查询由 pip 处理其内部平面或按文件嵌套结构；只输出命中的选项名，不清空正常包源、find-links 等配置。私有 pip API 若出现其他不兼容错误将失败，不静默放行；应用直接执行任意 Python 并不构成文件系统沙箱。

| 检查 | x86_64 | ARM64 | 证据 |
| --- | --- | --- | --- |
| 原用例修复前 pip退出0且创建外部目录 | 已复现 | 已复现 | `*-red.json` |
| 原用例修复后退出2、不创建外部目录、恢复临时配置 | 通过 | 通过 | `*-green.json` |
| 两版本 GNU/musl，global/install 五种目标参数、显式配置文件、正常配置/本地 wheel、错误继承目标清理 | 53项通过 | 55项通过 | `*-pip-policy.json`；ARM另测 ks-cli 调度前拒绝 |
| 修复后实际非root venv/pip/原生 wheel/console/stdin/子进程/TLS/故障清理完整场景 | 64项通过 | 64项通过 | `*-full-application.json` |
| 实际生产 LuCI 的 pip/venv 信息、wrap、四类命令、测试 Python3.13musl 删除重装、无pip版本选择、移动主题 | 5项通过 | 5项通过 | `ui-*/python-live.json`；仅删除本任务的 Python SDK，原应用目录保留 |
| 本机实际 pip24.0 平面配置API兼容 | 3项通过（10个目标子用例） | 不替代设备测试 | `local-pip-compatibility.json` |
| 正常重启后四种固定 venv/native/console/TLS，重新拒绝 pip site target | 22项+原用例通过 | 22项+原用例通过 | `*-python-postboot.json`、`*-config-postboot.json` |
| 重启后现有 OpenClaw 认证 Gateway、专用UID32771、OpenClaw 自身loader sqlite-vec0.1.7 最近邻 | 12项通过 | 12项通过 | `*-gateway-postboot.json` |
| 配置/旧全局默认/既有二进制/OpenClaw绑定/持久挂载不变，ARM AgentFlow健康 | 通过 | 通过 | `reboot-comparison.json`、`*-system-*.json` |
| 重启后源码及资源字节/权限审计 | 73个通过 | 73个通过 | `*-source-audit-postboot.json`；各保留1个已有配置 |

本轮仅修改 Python 配置检查，复用先前二进制和前端，无IPK/APK构建。两个直部署清单 `*-direct.json` 含备份与回滚命令。临时 LuCI 会话已销毁，私有凭证文件已删除。

最终 boot ID：x64 `8c08d91f-949e-45b5-b277-e21c4575fec3`，ARM `698dba48-268f-4da1-b629-c6d7a51ff9da`。所有实际故障配置都已恢复，原应用数据与其他运行时保留。包依赖、文件归属、安装升级钩子及 IPK/APK 构建继续按用户要求待人工验收后人工进行；源码直部署不代表这些包项目通过。M7/M8 尚未实施。

这次问题可由“实际目标 pip 版本 + 实际配置 + 正式 wrap”的回归用例提前发现，因此保留 `python-pip-policy.lua` 和本机旧 pip 兼容测试，不再只验证解释器前缀或代码中的配置遍历形式。
