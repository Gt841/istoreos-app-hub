# changeguard

仅 CLI 和独立 OpenWrt 后台；依赖 Linkspace 二进制，不安装 GUI、独立认证、公开 HTTP 监听或应用登记清单。KAI 运行于路由器内时提供共享 LuCI 登录下的浏览器界面和真实客户端证明。

运行时包为 `changeguard`，作为 KAIPlus 的依赖安装，不提供独立的软件中心元包。唯一后台为 `changeguard_bin`，唯一 CLI 为 `/usr/bin/changeguard`，默认配置为 `/etc/changeguard/config.json`，服务为 `/etc/init.d/changeguard`。源码、安装和运行均不包含改名前的兼容包或配置回退。

更新仅在 maintenance-check 允许时进行；活动保护、恢复和未解决的失败材料阻止升级/卸载。新旧后端必须一起提供符合 filetree-local-v1 契约的 Linkspace；依赖声明并不绕过运行时能力校验。

软件中心仅展示 KAIPlus；设备保护界面由 KAIPlus 提供。ChangeGuard 不包含独立 LuCI 页面、登录或应用登记清单。依赖链为 KAIPlus → ChangeGuard → Linkspace，软件中心更新通知由 app-meta-kaiplus 承担。仅更新源码/本地候选包不代表二进制已公开发布。
