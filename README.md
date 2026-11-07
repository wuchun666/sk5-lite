# sk5-lite — 最简 SOCKS5(SK5) 一键安装

适用 **Ubuntu / Debian**，走系统官方 apt 源的 `dante-server`（1.4.2/1.4.3）：

- 无第三方二进制、无编译、无外部脚本依赖，**1核1G 小机器友好**（包装完约 1MB）
- 账号走系统用户 + PAM，加用户/改密码就是系统命令
- 替代旧方案（gitee 镜像 `wuhcun/sk5` 的 raw 文件已被屏蔽，原一键命令已失效）

## 使用方法

把本仓库推到你自己的 GitHub 后，在目标服务器（root）上执行一行命令：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wuchun666/sk5-lite/main/sk5.sh) --port=5431 --user=admin --passwd=123
```

多 IP 机器（IP 用冒号分隔，自动开出口轮换）：

```bash
bash sk5.sh --ip="A.A.A.A:B.B.B.B" --port=5431 --user=admin --passwd=123
```

也可以先下载再执行：

```bash
wget -O sk5.sh https://raw.githubusercontent.com/wuchun666/sk5-lite/main/sk5.sh && bash sk5.sh --port=5431 --user=admin --passwd=123
```

## 参数

| 参数 | 说明 | 默认 |
|---|---|---|
| `--port=` | SK5 端口 | `2016` |
| `--user=` | 账号（系统用户） | `admin` |
| `--passwd=` | 密码 | 不填则自动生成 8 位随机密码并打印 |
| `--ip=` | 绑定指定 IP（冒号分隔多个） | 不填则监听 0.0.0.0 |
| `--uninstall` | 卸载 | - |

- **重复执行 = 更新配置并重启服务**，可随时改端口/密码/绑定 IP。
- 不填 `--passwd` 时自动生成随机密码，适合临时起代理。

## 防火墙（重要，装完连不上先看这里）

1. 脚本只会自动放行 **ufw**（如果它是开着的）。
2. 云厂商网页控制台里的**安全组/防火墙规则**要自己去放行端口的 **TCP 和 UDP**。
3. 用 SSTap 玩游戏**必须放行 UDP**——只放 TCP 就会"UDP 测试不通过"。这是最常见的坑。

## 日常管理

```bash
systemctl status danted      # 看状态
systemctl restart danted     # 重启
systemctl reload danted      # 改完配置热加载

passwd admin                 # 改 SK5 密码（admin 换成你的账号）
useradd -r -M -s /usr/sbin/nologin 新用户 && passwd 新用户   # 加一个账号

cat /etc/danted.conf         # 配置文件
journalctl -fu danted        # 实时日志
bash sk5.sh --uninstall      # 卸载
```

## 客户端

- Windows：**SSTap**（游戏）、**Proxifier**（全局）
- 安卓：**socksdroid**

连不上按顺序查：安全组/防火墙（TCP+UDP）→ `systemctl status danted` → `journalctl -u danted -e`。

## 支持的系统

Ubuntu 18.04+ / Debian 10+（apt 系）。CentOS 不在支持范围（需换 dnf/yum 源，如有需要再扩展）。
