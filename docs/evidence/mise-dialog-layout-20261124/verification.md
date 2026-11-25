# 运行时弹窗错位修复（2026-11-24）

目标：修复真实 iStoreOS LuCI Argon 宿主中的弹窗左上角错位、标题被蓝条遮挡和横向溢出，保留 QuickStart 视觉规范。

## 复现与原因

真实设备 `192.168.30.7`，通过 SSH 创建短期 rpcd 会话测试；凭据保存在 SSD 私有文件，未写入证据，测试后全部销毁。

回归命令（需要通过 `apps/mise/tests/luci-session.py` 生成的私有会话文件）：

```sh
rtk proxy /var/cache/build-cache/run.sh -- env MISE_LIVE_SESSION=/private/session.json MISE_LIVE_EVIDENCE=/path/to/evidence node apps/mise/web/tests/dialog-layout-live.browser.mjs
```

[修复前结果](red/dialog-layout.json)：四类弹窗在三种宽度下共 12 项全部失败。1382×751 视口中弹窗位于 `(0, 0)`，滚动宽度 582px 大于客户区 558px，与用户截图一致。

[样式探针](style-probe.json) 确认 LuCI 的通用 `* { margin: 0 }` 覆盖了原生 dialog 的默认居中边距。Argon 全局 `header::after` 生成蓝色绝对定位装饰，遮挡标题且溢出弹窗。浏览器单变量验证：显式 `margin:auto` 后弹窗移至 `(411,16)`，关闭弹窗标题栏的该伪元素后滚动宽度从 582 降至 558px。

## 修改

- `AppDialog.vue`：显式恢复原生模态框居中及视口边距；仅在本组件内隔离宿主的标题栏伪元素及 header/footer 定位规则。固定标题和操作区，长内容在正文内滚动。保留复制的 QuickStart 样式文件。
- LuCI 页面为 JS/CSS 增加缓存版本参数，刷新可加载新资源。
- 更新对应 LuCI 和 app-meta 的 release 至 2；运行时后端、SDK 和应用数据未改动。

## 验收

- [修复后浏览器结果](green/dialog-layout.json)：32/32 通过。安装、使用方法、详情、二层清理确认弹窗 × 1382×751、390×751、320×751、1024×480 × 亮色/深色。
- 检查水平/垂直居中、视口内留边、无横向滚动、标题实际命中可见、底部按钮可见；关闭使用方法弹窗后焦点返回原按钮。无页面脚本异常。
- 全部浏览器操作仅查看及开关弹窗，没有提交安装、清理、存储配置或运行时切换。
- [本地检查](checks.json)：前端构建、类型检查、58 项现有测试和 `git diff --check` 通过。构建输出位于 SSD；[生产模块审计](production-modules.audit.json) 保留。
- [直接文件部署](deployment.json)：仅更新 3 个文件，其余 40 个一致；未构建 IPK/APK，未修改包数据库。[设备文件审计](source-audit.json) 43/43 通过。备份和回退入口记录于部署证据。

人工查看：[桌面](green/install-1382-751-light.png)、[手机深色](green/install-320-751-dark.png)。截图完整集合仅保留本地，按仓库现有证据规则忽略。
