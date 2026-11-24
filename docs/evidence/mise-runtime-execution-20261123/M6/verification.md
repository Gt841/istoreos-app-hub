# M6：Python 运行时阶段记录

后续结果：用户授权继续后，已在一次优化中修复并完成 M6 全部设备验收，见 [续作最终报告](../M6-resume1/verification.md)。以下保留本轮暂停时的历史事实。

结果：**未通过**。按用户“三次优化仍失败则暂停”的条件停止，本次不进入 M7/M8。M1–M5 的通过状态保留。当前为开发文件直部署候选，未公开发布；不应作为完整 Python 隔离功能交付。

## 已取得的证据

| 检查 | x86_64 192.168.30.7 | aarch64 192.168.30.93 | 证据 |
| --- | --- | --- | --- |
| Python 3.12.16 / 3.13.18，GNU / musl，共四实例 | 通过 | 通过 | `*-install-matrix.json` |
| 实际 SSL、SQLite、ctypes、ensurepip/pip26.3、临时 venv、子进程、manylinux/musllinux 标签 | 通过 | 通过 | 安装收据 probes；上述矩阵 |
| 普通 UID65001，固定 venv/console/stdin/退出码，真实 MarkupSafe3.0.3 原生 wheel | 通过 | 通过 | `*-application-opt2.json`，每台64项；属于第三轮修改之前的结果 |
| 系统 CA 可信 TLS、自签名拒绝、显式私有 CA 可信 TLS | 通过 | 通过 | 上述应用记录中的 TLS 检查 |
| GNU/musl 固定入口、应用包不污染基座、已有目录/外来收据/配置变更/路径逃逸拒绝 | 通过 | 通过 | 上述应用记录 |
| 故意缺 ensurepip 仅清理新目标；故意缺 SDK/local receipt 明确失败 | 通过 | 通过 | 上述应用记录；故障文件均已恢复 |
| ks-cli 实际 pip 装包 | 未部署服务，使用源站 | musl 两版本通过 | ARM 应用记录；x64 环境探测失败另存，不冒充加速成功 |
| 显式公共权限不受 umask077 影响，私有默认600 | 通过 | 通过 | `*-permissions-green.json`，原红例 `permissions-red.json` |
| 正式前端类型检查、58项测试、生产构建 | 本机通过 | 本机通过 | `local-checks.json`、`production-modules.audit.json` |
| 最终源码直部署文件 SHA256/权限审计 | 73个代码/资源通过 | 73个代码/资源通过 | `*-direct-opt3.json`、`*-final-source-audit.json`；各保留1个已有配置 |
| 最终现有 OpenClaw 认证 Gateway、UID32771、OpenClaw loader sqlite-vec0.1.7 最近邻 | 12项通过 | 12项通过 | `*-gateway-close.json` |

SDK 原始归档由开发机 SSD 预取，按固定 SHA256 传输到设备内容缓存；安装、探测、登记和提交仍由设备公开 API 完成，没有复制已安装 SDK 或收据。预取不计作设备下载加速。Python 使用自带 OpenSSL 与独立默认配置，沿用系统 CA，保留显式 OPENSSL_CONF；不关闭证书校验。[上游 musl 动态构建说明](https://gregoryszorc.com/docs/python-build-standalone/main/quirks.html)解释了支持扩展加载的构建前提。

## 三轮优化与当前阻塞

1. 初始双架构 musl SSL 失败：宿主 OpenSSL 配置引用与 Python 自带 OpenSSL 不兼容的模块。源站证书路径单独调整不能解决；独立默认 OpenSSL 配置后完整 SDK 矩阵通过。见 `openssl-diagnosis.json`、`*-initial-install-failed.json`。
2. 普通 UID 的 ks-cli pip 缺少已有公开 UCI 适配路径。修正 PATH 后 ARM 真正装包通过。x64 没有 KSpeeder 服务，测试最初强行选择加速的失败保留为 `x64-application-opt2-environment-failed.json`，随后按设备实际能力选择源站，没有更改系统配置权限或安装额外服务。
3. 新红例确认 venv 自己的 `pip.conf` 可设置 `install.target`，把包安装到所选 venv 外。将配置检查移入 venv 后，**两台实际设备仍复现**：pip退出0，测试逃逸目录被创建。见 `pip-config-red.json`、`*-pip-config-opt3-failed.json`。第三轮没有解决该问题，不能宣称隔离契约通过；具体原因仍需继续定位。

最后一次复现使用：

```sh
lua /path/to/M6/python-pip-config.lua /path/to/Runtime-live /path/to/M6 green
```

复验时必须改用未使用的 label。脚本仅操作本任务 UID65001 的测试 venv 与 `pip-target-<label>` 目录，并在检查之前恢复临时 pip.conf；保留的逃逸目录只含测试 wheel 的文件，不是应用或共享 SDK。预期应拒绝安装且目标不存在；实际两者均不符。

未完成：pip site 配置目标隔离修复、第三轮后的完整应用回归、实际 LuCI Python 安装/使用流程、Python 重启验收。不能用之前64项通过替代这些检查。Python 启动器小型二进制摘要在 `python-launch-build.json`；代码备份及 rollback 命令均在直部署清单，用户配置、公共 SDK 和应用数据保留。

开发工作流已采用直接同步源码/必要二进制/生产前端资源，**IPK/APK 编译与包依赖、文件归属、安装/升级/卸载检查全部等待人工确认后人工进行**。历史 M4 包结果不能代表当前覆盖文件。
