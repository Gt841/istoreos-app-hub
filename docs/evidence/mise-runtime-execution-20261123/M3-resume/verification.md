# M3 续作通过

用户授权在首次三次优化失败后继续。本轮两次优化：第一次修正测试转发，第二次修正独立启动探测的 shell 选项；没有修改 M3 的生产实现，全部源码仍匹配 `../M3/source-sha256.json`。

## 任务与结果

1. 设备/存储复核：两台 boot ID 未变，持久根可用，原服务仍运行。
2. 回环转发：开发机先连接 ARM 本机 127.0.0.1:5003/5443，再为 x86 做 reverse forward。x86 GET npm 网关返回 200，消除了此前 LAN 转发触发的 localhost 限制；没有放宽服务访问规则。
3. x86 补齐：34 项实际运行检查全部通过，包括普通 UID 加速 npm 装包、生命周期和缺失二进制拒绝回退。实际不兼容 npm engines 失败清理通过；五 SDK mise exec、普通 UID 精确登记键执行、默认保护、非默认卸载及全别名清理通过；缓存复装恢复为五实例；源站/ks-cli 的 Git 参数和 Git/npm 原始退出码通过。
4. ARM 前轮的同项通过证据继续有效；本轮旧 helper 在 4.6 秒内完成环境/版本探测，原 HOME 与 Node v24.20.0 保持，原 AgentFlow healthz 返回正常。
5. 独立 AgentFlow 启动：使用候选旧环境函数、实际 `/usr/sbin/agentflow` 和独立数据目录，监听 127.0.0.1:19003，healthz 正常，并核验监听 PID 25518 属于本次候选。随后回收该会话，原 AgentFlow PID 6852 与 KSpeeder PID 9766 保持。

首次独立启动探测错误使用 set -u，触发 OpenWrt functions.sh 的未定义 IPKG_INSTROOT；它不符合实际 procd 启动方式，不能判为运行时缺陷。阶段定位证据保留；修正后的 `agentflow-start.sh` 沿用真实启动语义，并增加监听进程归属验证。私有应用原始日志未复制到仓库。

所有临时 SSH 转发均按 argv/进程组核验后终止，x86 5003/5443 监听消失。隔离服务已停止，两台 SDK 与日志保留，ARM 受保护文件摘要一致。详见 `forwarding-cleanup.json`、`arm-baseline-final.json`。

本里程碑是实际双架构 SDK 和环境协议验收；正式 OpenWrt 包、LuCI 认证页面与升级路径仍属于 M4/最终交付，OpenClaw 接入属于 M5。本轮未推送、公开发布或安装新的系统包。
