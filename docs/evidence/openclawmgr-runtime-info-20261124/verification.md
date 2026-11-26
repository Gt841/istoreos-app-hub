# OpenClaw glibc 运行时可见性

结论：当前Node24.22.1的版本固定策略与glibc切换相互独立。实际已安装OpenClaw2026.3.28声明Node>=22.14.0，当前版本满足要求；无需仅为切换libc改变Node版本号。本结论是当前绑定的兼容性判断，不宣称该版本是最新发布或完成其他版本的安全/兼容性评审。

已核对192.168.30.7：固定入口真实执行返回Node v24.22.1、glibc2.39、x64。正在运行的Gateway进程UID32771，映射包含绑定实例的node.real及同一私有库目录的libc.so.6；不是系统musl Node的版本显示伪装。包engines、绑定、实际执行及进程映射判断见actual-runtime.json。

原状态API只有node_version，页面无法体现ABI。新增shared-runtime.lua describe只读命令，先复用原绑定/收据校验，再返回Node/npm、ABI、架构、私有libc版本及固定实例；不改变原inspect输出。LuCI状态读取这份描述，不调用加速服务或安装SDK。服务卡增加glibc版本、mise固定运行时标签和公共管理页链接，实例通过title可查。异步状态刷新同步更新标签，缺失描述时隐藏ABI并显示待检测，不能给旧/无效安装硬贴glibc标签。

真实浏览器回归先在旧状态上失败（无runtime_info），更新后4项通过：验证固定GNU绑定、实际标签与链接、缺失信息不误报glibc、390手机宽度布局。最后一项未知态是浏览器拦截响应的负向夹具，未修改设备SDK/配置。缺失绑定CLI实际返回非0且无元数据。JavaScript语法与设备Lua loadfile编译检查、git diff --check通过。设备无独立luac，使用自带Lua编译接口检查，无需安装编译器。

直部署4文件：shared-runtime.lua、controller、view及app.js；其他70个非配置文件未变，1个配置保留。74文件SHA256/权限/归属审计通过。见deployment.json、source-audit.json及green/runtime-info-live.json；截图green/runtime-info.png。临时会话已销毁，无服务重启、Node升级或应用数据变更。源码版本号沿用同一未提交候选的LuCI r3/元包r5，不重复增加。未构建安装包，未发布。ARM64未操作。
