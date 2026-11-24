# 环境准备结果

用户授权：先准备环境，然后连续实施 M1–M8；每个里程碑自检后最多优化三次。环境准备已通过当前开发/安装测试门槛，后续里程碑仍按各自真实设备标准验收。

- x86 `/dev/sdd` 的 68,719,476,736 字节经只读程序逐字节确认全零；无挂载/holder/文件系统签名。随后创建 ext4，UUID=f371c867-d169-436f-b560-58dc3f4f482d，挂载 `/mnt/mise-runtime`，独立 UCI fstab 项。读写、执行、卸载重挂后的持久性通过，约 61.8 GiB 可用、4,194,289 空闲 inode。其他磁盘/测试挂载与历史数据未清理。
- ARM 错误 inode 0xeeac0d3e 精确对应 USB `/dev/sda2` 的旧 iStoreOS 22.03.7 x86_64 映像；当前 `/rom` 对应 mmcblk1p2，为 iStoreOS 24.10.8 aarch64，root inode 不同，报错偏移也超过当前映像 bytes_used。当前映像与 USB 映像均在本机完整解码通过；不声称旧 USB 数据损坏，内核自动挂载兼容性问题留有原始证据。
- 为旧 USB 映像 UUID 增加 disabled fstab 项，针对它重新执行固件的自动挂载扫描，无挂载、无新增 SquashFS 错误（8→8）；未修改固件或 USB 字节。ARM 使用独立 NVMe 验收目录，写入/执行通过。旧 mise HOME、AgentFlow、KSpeeder 受保护文件摘要一致，两个服务 PID 保持。
- x86 私有 bootstrap 目录部署来源与 SHA256 固定的 mise 2026.8.14 musl 和 ks-cli 0.9.1，不覆盖系统路径，不伪称已安装 opkg 包。使用 `.93` 现有 KSpeeder 的明确 admin URL 做下载测试，未启动第二个加速服务或替换原服务。
- 同一 Node 发布校验文件：源站/auto（实际选择 origin）及强制 accelerated（实际选择 admin_proxy）下载内容一致，SHA256=fdfbffc969c0f604beff0124d409b33a43b53f5c681d6220f80023e0d6df9dc4。完整语言归档与安装仍在对应里程碑验证。
- 开发机安装 Lua 5.1、lua-cjson 和 squashfs-tools 作为测试/诊断工具；构建缓存保持 SSD。构建服务器已有双架构 SDK，本轮不修改其共享缓存或部署配置。

工具适配记录：BusyBox cmp 的 -n 不支持 64 位长度；无上限逐字节 cmp 太慢，已中止其任务进程，改用附带源码的只读静态验证器完成全盘检查。第一次 unsquashfs 命令使用了本机版本不支持的参数，原失败记录保留；后续通过支持的 -pf 完整解码验证。没有把工具命令错误算作文件系统损坏。

限制：本阶段未重启整机，后续需要重启的验收仍待执行；USB 屏蔽规则在当前 hotplug 路径通过，不冒充整机重启后验证。未手动重刷固件、清理共享任务或把旧镜像挂到运行根目录。
