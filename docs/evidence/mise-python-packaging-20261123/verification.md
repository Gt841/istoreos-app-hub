# Python pip/venv 与 npm 高级选项验收

状态：目标及 P1–P5 完成，设计预览验收通过。预览 http://127.0.0.1:5180/mise 。

## 交付

- Python 安装默认包含配套 pip/venv，无 pip 版本选择。安装复核和任务明确准备/验证步骤；失败候选不提交，用户明确重试才重新执行。
- Runtime.pythonTools 承载 pipVersion、venv 状态及 probe/design 来源。详情只读显示回传信息，缺少版本/验证时显示未读取/未验证。当前 25.0.1 是设计样例，不伪称实际设备读取；所选 CPython ensurepip 源码基线摘录见 python-source-baseline.json。
- 使用弹窗增加可编辑的持久磁盘 venv 目录和创建、安装 requirements、运行、shell 四条可复制命令，保留基础版本查询和脚本样例下载。路径非法或占用公共管理目录时不生成可执行命令。
- Python wrap 新增 --create-venv 和 --venv，创建不存在的目标并离线初始化 pip；已激活的受管理 venv 自动沿用。未登记本地归属、运行时不匹配、入口变化、基础解释器不匹配或启动器丢失 venv 信息时明确失败，不静默回退共享解释器。
- venv 的 python 入口通过 CPython 的 __PYVENV_LAUNCHER__ 协议返回同一 SDK 启动器，pip 入口和子进程保持相同 SDK/私有 GNU loader 路径。创建流程实际验证 prefix/base/executable/version/user-site，然后写入 venv 内的本地归属文件。该文件不是中央应用登记，也不是权限安全边界。
- 共享 pip 命令仅版本/帮助查询；PIP_REQUIRE_VIRTUALENV/PYTHONNOUSERSITE 防止默认安装到公共解释器，并清除继承的用户/目标安装目录覆盖。pip/uv 缓存和 Python TMPDIR 位于持久 HOME；应用仍可显式改变自己的命令配置。
- npm 当前默认版本始终显示，兼容版本选择移到默认收起的高级选项；Node 22/24 的默认值与请求模型同步，切换语言/版本重置。
- QuickStart 复制的 7 份源码摘要不变，未增加应用使用登记或真实安装 API。

## 验收过程（两轮，未超过三轮）

- 实施预检查时，真实 CPython 的负向路径测试把 ../ 输入通过 path.join 提前规范化，导致测试预期错误；修正为原始路径，同时修正 ensurepip 故障注入参数位置。产品路径检查无需为此改变。这些预检查记录在 checks-round-1.log 开头，不伪造为全程零失败。
- 第一轮：类型检查、58 项模型/wrap/真实本机离线测试、构建全部通过；新增 Python/npm 8 组、原产品 17 组、Rust/Zig 8 组、Java 6 组、QuickStart 宿主 6 组，共 45 组浏览器检查通过，零页面错误。
- 人工查看手机使用/安装、npm 桌面高级截图，发现 Python ABI 提示仍引用 OpenClaw 示例。第二轮更正该文案，清理继承的 pip 安装目标变量，并强化本机负向测试：SDK 启动器丢失 venv 身份时必须失败清理，不能回退。
- 第二轮：类型检查、58 项测试、构建全部通过；Python/npm 8 组浏览器复测全部通过。其余页面/宿主逻辑未改，不重复扩大回归。
- 手机覆盖 320/390，桌面 1440，深浅主题；复制/下载、目录输入/转义、状态未知、pip/venv 失败重试、npm 高级选择及语言重置均有检查。第二轮手机 Python 安装截图人工确认已更新。

## 真实本机离线检查

本机 /usr/bin/python3 为 CPython 3.12.3，具备 ensurepip/venv/pip。在 SSD 临时沙箱中以固定 SDK sh 入口转发到该系统 Python，未改系统解释器，也没有下载 SDK 或访问 PyPI。

测试创建带空格和单引号路径的 venv，用 zipfile 现场生成纯 Python wheel，通过 venv pip 安装，验证该包在目标 venv 可导入、在共享 Python 无法导入；pip 生成的控制台脚本、shell、sys.executable 子进程、stdin 执行均进入目标 prefix，并记录经过同一 SDK 入口。测试不匹配的本地归属、被改写的入口、未验证的激活环境、越界/符号链接路径、既有目录保护、pip 初始化失败和启动器丢失 venv 身份后的候选清理。临时文件完成后移除。

## 实际边界

本轮交付的是产品交互与可下载 wrap 样例，不是生产安装器。页面本身不创建虚拟环境或安装包。Runtime.pythonTools 在预览中全部为设计数据，没有真实设备探测。

本机 smoke 的 SDK 入口只转发系统 CPython，虽验证固定入口重入与 venv 行为，仍未验证真实私有 GNU loader/运行库、3.12.10/3.13.3 目标 SDK 或 ARM 固件。__PYVENV_LAUNCHER__ 为 CPython 内部启动器协议，正式 SDK 必须保留它并验证该确切版本的 prefix、原生扩展、pip、venv 及子进程；不支持时拒绝提交，不能依赖本轮原型的样例状态放行。

本地归属文件只用于兼容性和误操作检查，不防恶意修改。既有其他方式创建的 venv 暂不自动导入，目录/SDK 不支持移动；应在新环境按 requirements 重装。显式 pip 配置、项目脚本与依赖安全不属于本功能的权限隔离承诺。

本轮未改动 mise 生产包配方、meta release、LuCI 部署，不提交或发布代码。

参考：[Python venv](https://docs.python.org/3/library/venv.html)、[CPython 3.12.10 getpath](https://github.com/python/cpython/blob/v3.12.10/Modules/getpath.py)、[CPython 3.13.3 getpath](https://github.com/python/cpython/blob/v3.13.3/Modules/getpath.py)。
