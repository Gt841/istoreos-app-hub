# x86_64 当前提交运行部署

192.168.30.7 已运行当前提交 `755ddd86585944bee730fb76b2cc2875faf02169`（实现提交24b1bae）。本次只操作该机，未重启设备、未编译IPK/APK。

- 75文件直部署清单：74个非配置文件原本就与提交版本一致，0文件需覆盖；1个配置在文件部署时保留。摘要、权限及归属审计通过。代码回滚命令在direct-deployment.json。
- 按既定本机加速设计，将 mise.main.acceleration 和 openclawmgr.main.install_accelerated 从0设置为1。切换前外层配置私有备份位于 `/mnt/mise-runtime/acceptance/direct-deploy/run-x64-20261124T125316Z/configuration-before`。SDK绑定、应用数据配置、模型/鉴权配置和全局默认均未改变。
- 本机iStoreEnhance与OpenClaw均保持自启动和运行，无需额外重启已匹配的服务。
- Gateway为OpenClaw2026.3.28，固定GNU Node24.22.1/npm11.19.1，专用UID32771；认证健康及OpenClaw自身loader的sqlite-vec查询等12项通过。
- 11个已验证SDK可由运行时页面查询。新UID65006冷客户端缓存下，不设置ISTORE_RUNTIME_ACCELERATION覆盖值，正常固定Go入口由持久设置选择ks-cli；模块、官方sumdb和本机网关11项检查通过。TLS/校验未关闭。
- 真实浏览器4项通过：未认证请求不泄露凭据、认证状态绑定实际版本、OpenClaw页面、运行时页面。临时会话已销毁。

管理入口：

- http://192.168.30.7/cgi-bin/luci/admin/services/mise
- http://192.168.30.7/cgi-bin/luci/admin/services/openclawmgr/config

保留原应用监听：127.0.0.1:18793。没有开放LAN监听或新增端口转发。目前尚无模型provider/API凭据，Gateway正常不代表已验证模型聊天；用户可通过管理页配置模型及需要的监听范围。

本次没有改写产品源码或应用数据，也不更改M7中ARM64重启待验收、M8未实施的状态。属于源码直部署运行确认，不替代后续包验收。
