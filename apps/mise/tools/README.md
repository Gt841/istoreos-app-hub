# 测试机直接部署

开发阶段先同步脚本、二进制和正式前端资源，在两台授权设备验证真实业务。无需构建 IPK/APK，也不修改设备包数据库。人工确认功能后，再人工编译并验收安装包。

加速环境采用设备本机的 `istoreenhance`（KSpeeder 服务）与 `ks-cli`（客户端）。仅有 ks-cli 不能代表加速环境准备完成。加速验收在两种架构都选择 ks-cli，验证服务能力、真实请求路径及原生完整性检查；架构不能决定是否使用源站。不用跨设备 SSH 转发代替最终验收。固定程序运行、版本查询和离线编译不依赖服务可用；源站是明确选择的独立下载方式。

`provision-test-acceleration.py` 专用于补齐 x86_64 测试机缺失的本机服务：使用 istoreenhance 包固定 SHA256 的 0.9.1 官方二进制和仓库 init 脚本，拒绝覆盖既有安装或占用端口。写入三个文件并启用 procd，缓存位于测试盘；证据记录每个文件的摘要和回滚命令。ARM 既有服务不变。这是测试文件直部署，不是软件包安装或包依赖验收。

从本仓库根目录执行。前端有修改时先生成正式资源：

```sh
rtk proxy /var/cache/build-cache/run.sh -- bash apps/mise/tools/build-web.sh
```

`deploy-test.py` 接受固定测试机，自动识别 x86_64/aarch64，检查提供的 `exec-user` ELF 架构。该小型程序使用对应目标编译一次，后续脚本/前端修改复用同一二进制；它有变化时才重新编译，不需要 OpenWrt SDK 包构建。

```sh
rtk proxy python3 apps/mise/tools/deploy-test.py 192.168.30.7 \
  --label M5-review-001 --exec-user /path/to/exec-user-x64 \
  --with-openclaw --evidence /path/to/x64-deployment.json
rtk proxy python3 apps/mise/tools/deploy-test.py 192.168.30.93 \
  --label M5-review-001 --exec-user /path/to/exec-user-arm64 \
  --with-openclaw --evidence /path/to/arm64-deployment.json
```

每次使用新 label。部署前检查持久磁盘、路径和文件类型；先备份全部待修改文件，再逐文件原子写入并复验 SHA256/权限。设备端脚本统一 0755、普通资源 0644、新配置 0600，不照搬开发目录的组写权限。保留已有 UCI 配置。脚本初始化 OpenClaw 专用用户、刷新 LuCI/rpcd；应用服务的安装、重启及健康检查单独执行并记录。公共 SDK、应用数据、模型密钥和包缓存不随代码部署复制。

命令输出和 evidence 中有该批次的 `rollback` 命令，在对应设备执行即可恢复这次代码变更。备份留在设备私有目录；回滚会拒绝覆盖部署后又被修改的文件。回滚保留账户、配置、公共 SDK 和应用数据，应用事务恢复仍使用 OpenClaw 的 `recover_install`。

功能验收包括实际服务用户、Gateway 认证健康、向量查询、失败回滚和重启。源码直部署不覆盖包依赖、文件归属、安装/卸载钩子或包升级验收；这些项目继续保留为待人工编译后的独立检查，不标为通过。


OpenClaw 的完整设备场景使用测试租约串行执行：

```sh
lua /path/to/M5/with-device-lease.lua /path/to/M5/gateway-device.lua \
  /mnt/disk/acceptance/M5/OpenClawMgr /mnt/disk/acceptance/M5/probe
```

同一设备先等待场景退出，再调度下一项；租约及应用锁存在时会直接拒绝新场景。不同测试机可同时验证。测试被强杀留下租约时，先核对 owner.json 的 PID/start/boot ID 并确认没有所属进程，再处理测试租约；应用安装中断仍使用正式 recover_install。


部署后可只读审计先前清单：

```sh
rtk proxy python3 apps/mise/tools/audit-test.py /path/to/deployment.json /path/to/audit.json
```

后续 SDK 验收可预取确定 SHA256 的原始归档，减少设备侧重复下载：

```sh
rtk proxy /var/cache/build-cache/run.sh -- python3 apps/mise/tools/prefetch-test.py \
  192.168.30.7 --target /mnt/mise-runtime/Runtime-live --tools python \
  --evidence /path/to/prefetch.json
```

预取在开发机 SSD 下载，按目录 SHA256 校验后传到对应设备，再复验字节数与 SHA256。它只填充内容缓存，不安装 SDK/库或复制收据；设备仍通过正式管理器现场安装并探测。证据明确区分缓存准备与设备上真实源站/ks-cli 网络下载，不把预取记成设备加速验收。

Python 能力启用后，首次部署须同时传入 `--python-launch-musl /path/to/python-launch-musl-<arch>` 和 `--python-launch-glibc /path/to/python-launch-glibc-<arch>`。两者均从 `src/python-launch.c` 编译：musl 入口动态链接目标宿主 musl，GNU 入口使用无动态解释器的静态调度器，避免 pip 错误识别 wheel ABI。后续纯脚本/页面修改可复用这些二进制。
