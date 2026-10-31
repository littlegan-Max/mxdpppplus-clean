# mxdpppplus 服务端部署说明

这是一个 UDP 端口的权威服务端。客户端填写「服务器 IP + 端口」即可联机，没有匹配功能，房间由玩家创建。

## Windows（推荐给服主）

1. 解压 `mxdpppplus-server-win64.zip`。
2. 双击 `run_server.bat`（或命令行运行）。
3. 首次运行时 Windows 防火墙会询问，请允许「专用/公用网络」的 UDP 入站。
4. 默认监听 **UDP 7777**；把公网 IP 和 7777 发给玩家即可。
5. 端口被占用时可设置环境变量 `MXD_PORT`，或运行：

```
mxdpppplus_server.exe --headless --port=7777
```

程序是 `dedicated_server` 导出，启动后直接作为服务端运行，不需要 Godot 编辑器。

## Linux

1. 解压 `mxdpppplus-server-linux.zip`。
2. 运行 `./run_server.sh`（或 `./mxdpppplus_server.x86_64 --headless --port=7777`）。
3. 云服务器安全组/防火墙放行对应 UDP 端口。

## 数据

- 账号与好友数据：`user://mxdpppplus_accounts.json`（Godot 用户数据目录）。
- 可用环境变量 `MXD_DATA_PATH` 指定账号文件路径，例如：

```
MXD_DATA_PATH=/data/mxd_accounts.json ./mxdpppplus_server.x86_64 --headless --port=7777
```

- 重启服务端不会丢失账号与好友；房间与对局是内存态，重启会清空。

## 账号规则

- 客户端读取设备唯一标识（硬件码）并 SHA-256 后作为账号键；服务端只保存哈希，不保存原始硬件码。
- 无密码。换设备会生成新账号；好友与房间不跨设备同步。
- 用户名 2~12 字符、全服唯一；好友码 6 位数字，加好友需对方同意。
- 房间默认公开、人数上限 6、不补 AI、出牌限时 10 秒；房主可在创建时与房间内调整。
- 邀请好友成功时邀请者成为房主；房主可踢人、改设置、开始游戏。

## 网络说明

- 传输为 ENet（UDP），未做 TLS/加密；请只在内网或可信公网使用，不要复用敏感密码。
- 服务端只信任经过校验的客户端指令，出牌、费用、连招、伤害均由服务端引擎计算。
- 若客户端连不上，依次检查：IP、UDP 端口、安全组、Windows 防火墙、服务端是否显示 listening。

## 从源码运行（可选）

```bash
godot --headless --path . -- --server --port=7777
```

需要 Godot 4.7.2 与工程文件。
