# M4 自检与停止记录

状态：未通过。初次自检及三次优化后，仍有构建配置错误；按照用户设定的上限停止，M5–M8 尚未开始。

任务树与验收范围：

- 正式 Vue 页面及 QuickStart 样式：源码与生产构建已完成；真实 LuCI 下的桌面/移动端/主题/焦点验收待做。
- LuCI 登录、ACL、CSRF 和固定 JSON stdin 后端：接入已实现；真实安装后的认证正反例待做。
- 真实目录/收据/容量/任务/运行库引用/实际 wrap：双设备开发后端 online/unconfigured/offline 数据检查通过；正式包下安装、取消、恢复、重试、删除、缓存和下载交互待做。
- 双架构真实 SDK：独立 profile、固定 feed、候选补丁及逐文件摘要已建立；尚无通过的 IPK，未安装设备。

## 已完成检查

生产前端 TypeScript、Vite 构建及无设计 mock 导入检查通过；开发后端双设备正确保留空数组/null，并读取真实五个 Node SDK。候选补丁应用后的 45 个源文件 SHA256 一致。构建器 11 项测试、服务器只读预检、内部构建运行时部署与核验通过。

构建器提交 `c802be5a0ddd4ad1c1994ebfc5d3dac225aef36f`；候选补丁 SHA256 `6182b1728aa1dedfb26e8d3a783a143dd26b998bee4604c96511ffcff34ee6c7`。它们是未完成验收的内部候选，未推送或公开发布。

## 三次优化

1. TypeScript 发现刷新点击事件类型不匹配，改为显式调用 `refresh()`；前端检查通过。
2. 补丁缺少许可证末尾换行标记，补充 GNU patch 标记后，仍因 Python 对许可证分页符的分行方式失败。
3. 使用仅按真正换行切分的 StringIO，补丁逐字节验证和回归测试通过；随后 profile/feed 复核发现镜像配置仍包含未启用的 nas、nas_luci、istore。构建器的 `seed_feed_checkouts` 会拒绝这些条目，见 `mirror-profile-check.json`，因此整体 M4 仍未通过。

## 停止与现场

两次真实 clean SDK 构建已启动并停留在官方基础 feed 下载阶段，尚未编译目标包。核对容器 BUILD_ID 后，只停止本轮两个容器；构建命令退出 137，真实 `build.status=failed`。两次输入、日志和状态保存在对应 Build ID 子目录，没有把取消当作自然编译失败或通过，也没有修改状态文件。共享缓存、其他容器和构建目录保留。

两台设备本轮没有安装 mise-runtime/luci-app-mise 候选包，也没有创建 Runtime-live。ARM 原 mise 配置/helper、ks-cli、AgentFlow、KSpeeder 文件 SHA256 全部保持基线，AgentFlow healthz 成功。两设备 boot ID 未改变，见 `protected-after-stop.json`。5180 设计预览入口未调整。

## 继续所需工作

新增仅含本 profile 启用 feed 的独立 mise mirror 配置并加入 profile 校验测试；新提交、内部 release/deploy/verify 后，使用新 Build ID 重建。通过真实 IPK 的依赖/文件/摘要审计后才安装设备，执行已准备的生产 LuCI 浏览器脚本及其余 M4 验收。M4 通过后才进入 M5。此项缺口是构建配置实现错误，不涉及产品语义决策；本轮未继续进行第 4 次优化。
