# 设备环境事件

2026-11-23 02:33 UTC 左右，arm64 192.168.30.93 安装依赖阶段出现 SSH 超时，开发机 ping 丢包。
x86_64 设备随后观测到约 1–2 秒延迟的 ICMP 响应。02:34:15 UTC SSH 短暂恢复，
`uptime` 显示 `up 0 min`，内存约 4 GB、available 3.3 GB、无 swap；/var/log/tasks 日志已消失。
测试脚本没有执行 reboot。没有证据判断重启原因。随后 SSH 再次超时，恢复命令尚不能确认执行。
此事件不能作为 Gateway 或恢复通过的证明；以后续 recovery 命令实际输出为准。

02:35:33 UTC 再次连接成功：.93 uptime 1 min，boot_id 52367011-c599-415d-81d3-2b3c2c89ef36；
.244 uptime 43 min，boot_id 89c3020f-eb5b-4044-adff-6d0bcc5517f6（仅只读检查，未部署 OpenClaw）。
两者这次观测到的启动时间不同。ARM pstore 已保存 console-ramoops-0.log，未见 panic/OOM 终止记录；
发现 SQUASHFS xz/metadata 读取错误。当前 boot 也有相同 SQUASHFS 错误。
ARM 事务实际已进入 activated；native.json、cli-version、配置 openclaw.json 和 data.tar 均为 0 字节，
installer.log 尾部含 NUL。不能据此确定重启根因，也不能从该候选证明 Gateway 成功。
先前根据最后一次轮询推测 preparing 已被此磁盘证据更正。
02:38:59 UTC 新恢复候选真实运行后明确拒绝空归档（exit=1）；自动断言 current、配置摘要不变且 journal/锁保留。
这证明损坏快照保护生效，并非成功恢复旧业务数据。

10:49:35 CST .93 uptime 15 min，boot_id 仍为 52367011-c599-415d-81d3-2b3c2c89ef36。
10:50:15 CST .244 uptime 58 min，boot_id 仍为 89c3020f-eb5b-4044-adff-6d0bcc5517f6。
两次复核未观察到再次重启；.244 保持只读检查范围。
