# luci-app-campus-auth

一个用于 OpenWrt / iStoreOS 的 LuCI 校园网认证插件，支持：

- LuCI 后台内嵌管理页面
- 多账号与优先级切换
- 手动选择当前账号与调整登录顺序
- 余额阈值自动切换
- 已用流量达到上限后自动切换
- 手动登录、注销和状态查询
- `procd` 后台监控与自动认证

## 安装

将项目放入 OpenWrt SDK 的 `package/` 目录，然后执行：

```sh
make menuconfig
# 选择 LuCI -> Applications -> luci-app-campus-auth
make package/luci-app-campus-auth/compile V=s
```

生成的 `.ipk` 安装后，重启 LuCI 或清理 LuCI 缓存即可看到“网络 -> 校园网认证”。

也可以直接把仓库中的 `etc/` 和 `usr/` 目录复制到路由器根目录。

Windows 下可以使用一次性部署脚本（需要本机已安装 OpenSSH 和 tar）：

```powershell
.\scripts\deploy.ps1
```

部署脚本只更新程序文件，不会覆盖路由器上的 `/etc/config/campus_auth`；已有账号和配置会保留。

## 配置

首次安装不会包含任何账号或校园网地址。进入 LuCI 页面填写：

- 登录地址：认证门户的 POST 地址，例如 `/0.htm`
- 状态页地址：登录后可读取余额和流量的页面
- 注销地址：门户提供的注销地址
- 一个或多个账号；密码通过每行的「编辑」按钮录入，列表中不显示密码
- 账号列表中的“使用”单选框决定手动登录账号，上移/下移图标按钮调整优先级（即自动切换顺序）
- 每个账号显示最近一次查询到的已用流量、余额和剩余额度圆环（剩余额度按 100 GB 计算）
- 已用流量上限（MB）：达到上限后切换，填写 `0` 表示不限制

密码只写入路由器本机的 UCI 配置，不会显示在状态接口中。默认不会启用后台自动认证，需要在“基本设置”中手动开启。

## Dr.COM 密码字段

当前脚本支持常见的 Dr.COM WebLogin 形式：

```text
upass = MD5(pid + password + calg) + calg + pid
```

其中 `pid` 和 `calg` 可在 LuCI 的基本设置中调整。不同学校可能使用不同字段、地址或参数，发布前请根据本校门户抓包结果配置和测试。

## 安全与合规

请仅在你有权使用的校园网络中部署。不要把真实账号、密码、认证抓包或运行时状态文件提交到公开仓库。项目中的 `ref/` 目录默认被 Git 忽略，用于本地协议分析，不属于发布包。

## 许可证

本项目采用 MIT License，详见 [LICENSE](LICENSE)。
