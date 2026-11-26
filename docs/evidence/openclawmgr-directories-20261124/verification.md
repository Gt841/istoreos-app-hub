# OpenClaw 数据目录选择修复

结果：已在192.168.30.7直部署并通过5项真实浏览器验证。没有重启设备或服务、编译安装包、迁移目录或修改运行配置。

根因：目录候选生成沿用与iStoreEnhance一致的挂载盘→Configs/OpenClawMgr模式，后端已返回有效硬盘候选；原前端使用input+datalist，当前值填满时浏览器按该值过滤候选，用户难以发现其他硬盘。M5路径是已安装实例的配置，不是插件硬编码默认目录。

修改为显式下拉：逐项显示后端返回的挂载盘候选，保留并标识当前目录，提供自定义目录输入。当前标识来自已加载配置，不依赖后续异步状态探测先后顺序；选择路径会保留其他尚未保存的表单内容。保存序列化真实路径，不写入自定义选项的内部标识。提示更换目录不会自动搬移数据。

当前候选包括 /mnt/vio4-0/Configs/OpenClawMgr、/mnt/mise-runtime/Configs/OpenClawMgr、参考实现也提供的/ext_overlay/Configs/OpenClawMgr，并保留既有安装目录。新挂载盘候选在刷新配置时重新获取。

验证：

- 真实后端硬盘候选正确；旧UI回归明确失败：INPUT≠SELECT。
- 新UI下拉含各候选及当前路径，当前标识在切换草稿后仍正确。
- 选择其他硬盘仅改表单，服务端base_dir不变。
- 自定义带空格路径可输入；测试拦截POST并验证提交真实路径，未让保存/重启操作到达设备。
- 390宽手机布局通过；截图见 [最终页面](final-pass/directory-selector.png)。

测试过程中修正两处测试设施：提示弹层位于外层document，不能在ShadowRoot里等待；异步表单重绘会使单元素截图句柄失效，改为页面截图。保留此前结果，不改写为初次全通过。

最后一批仅更新app.js一个文件；其余73个非配置文件未变，1个配置保留。74文件的SHA256/权限/归属审计通过，回滚命令见deployment-final.json；最终结果见final-pass/directories-live.json。JavaScript语法和git diff --check通过。临时LuCI会话已销毁。

当前运行实例仍保留/mnt/mise-runtime/acceptance/M5/OpenClawMgr，未自动迁到新位置。截图已有的Gateway“未托管”状态不是目录UI修复范围，现有Gateway HTTP仍可达；未操作该进程。发布号为luci-app-openclawmgr0.1.12-r3、app-meta-openclawmgr0.1.12-r5；安装包仍按用户要求待人工确认后编译。
