# changeguard

仅 CLI 和独立 OpenWrt 后台；依赖 Linkspace 二进制，不安装 GUI、独立认证、公开 HTTP 监听或应用登记清单。KAI 运行于路由器内时提供共享 LuCI 登录下的浏览器界面和真实客户端证明。

新配置为 /etc/changeguard/config.json。已存在 /etc/optimemachine/config.json 时继续使用该文件、原 stateDir/dataDir/socketPath，不复制历史身份。兼容旧命令由 apps/optimemachine 的薄包提供，唯一后台是 changeguard_bin。

更新仅在 maintenance-check 允许时进行；活动保护、恢复和未解决的失败材料阻止升级/卸载。新旧后端必须一起提供符合 filetree-local-v1 契约的 Linkspace；依赖声明并不绕过运行时能力校验。

软件中心沿用原 app-meta-optimemachine 标识，名称“变更保护”。不会注册第二个页面。仅更新源码/本地候选包不代表二进制已公开发布。
