#!/bin/bash
# ============================================================
# sk5.sh — 最简 SOCKS5(SK5) 一键安装（Ubuntu/Debian 官方源 dante）
#
# 用法:
#   bash sk5.sh [--port=端口] [--user=账号] [--passwd=密码] [--ip=IP1:IP2...]
#   bash sk5.sh --uninstall
#
# 说明:
#   - 只支持 Ubuntu / Debian（走系统官方 apt 源，无第三方二进制、无编译）
#   - 不填 --user 默认 admin；不填 --passwd 自动生成随机密码并打印
#   - 重复执行 = 重新生成配置并重启服务（可用来改端口/密码/绑定IP）
# ============================================================

PORT=2016
USER_NAME=""
PASSWD=""
IPLIST=""
UNINSTALL=0

for arg in "$@"; do
  case "$arg" in
    --port=*)    PORT="${arg#--port=}" ;;
    --user=*)    USER_NAME="${arg#--user=}" ;;
    --passwd=*)  PASSWD="${arg#--passwd=}" ;;
    --ip=*)      IPLIST="${arg#--ip=}" ;;   # 多IP，用冒号分隔，如 --ip=1.1.1.1:2.2.2.2
    --uninstall) UNINSTALL=1 ;;
    --help|-h)
      sed -n '2,12p' "$0"
      exit 0 ;;
    *)
      echo "未知参数: $arg （用 --help 查看用法）"
      exit 1 ;;
  esac
done

if [ "$(id -u)" != "0" ]; then
  echo "请用 root 运行（先执行 sudo -i 再重试）"
  exit 1
fi

# ---------- 卸载 ----------
if [ "$UNINSTALL" = "1" ]; then
  systemctl stop danted 2>/dev/null
  apt-get purge -y dante-server
  rm -f /etc/pam.d/danted
  echo "已卸载 dante-server。"
  echo "如需彻底清理: rm -f /etc/danted.conf ，并自行删除建过的系统用户"
  exit 0
fi

# ---------- 只支持 apt 系 ----------
if ! command -v apt-get >/dev/null 2>&1; then
  echo "本脚本只支持 Ubuntu/Debian（走官方 apt 源），当前系统不支持。"
  exit 1
fi

if ! echo "$PORT" | grep -qE '^[0-9]+$'; then
  echo "端口格式不对: $PORT"
  exit 1
fi

# ---------- 默认账号 ----------
[ -z "$USER_NAME" ] && USER_NAME="admin"
[ -z "$PASSWD" ] && PASSWD=$(tr -dc 'a-z0-9' </dev/urandom | head -c 8)

# ---------- 安装 ----------
echo "==> 安装 dante-server（系统官方源）..."
apt-get update
if ! apt-get install -y dante-server; then
  echo "直接安装失败，尝试启用 universe 源后重试..."
  add-apt-repository -y universe 2>/dev/null
  apt-get update
  apt-get install -y dante-server || { echo "安装失败：请确认是 Ubuntu/Debian 且软件源可用"; exit 1; }
fi

# ---------- 生成配置 ----------
EXT_IF=""
IPS=""
if [ -n "$IPLIST" ]; then
  IPS=$(echo "$IPLIST" | tr ':' ' ')
else
  EXT_IF=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
  [ -z "$EXT_IF" ] && EXT_IF="eth0"
fi

{
  # 官方 danted.service 把 /var 挂为只读，日志只能走 stderr（由 journald 捕获）
  echo "logoutput: stderr"
  if [ -n "$IPS" ]; then
    for ip in $IPS; do
      echo "internal: $ip port = $PORT"
      echo "external: $ip"
    done
    [ "$(echo $IPS | wc -w)" -gt 1 ] && echo "external.rotation: same-same"
  else
    echo "internal: 0.0.0.0 port = $PORT"
    echo "external: $EXT_IF"
  fi
  cat <<'RULES'

socksmethod: pam.username
clientmethod: none
user.privileged: root
user.unprivileged: nobody

client pass  { from: 0.0.0.0/0 to: 0.0.0.0/0 }
client block { from: 0.0.0.0/0 to: 0.0.0.0/0 log: connect error }

socks pass  { from: 0.0.0.0/0 to: 0.0.0.0/0 protocol: tcp udp socksmethod: pam.username log: connect disconnect }
socks block { from: 0.0.0.0/0 to: 0.0.0.0/0 log: connect error }
RULES
} > /etc/danted.conf

# ---------- PAM（dante 1.4.x 默认服务名是 danted）----------
cat > /etc/pam.d/danted <<'EOF'
auth required pam_unix.so
account required pam_unix.so
EOF

# ---------- 建用户/设密码 ----------
if ! id "$USER_NAME" >/dev/null 2>&1; then
  useradd -r -M -s /usr/sbin/nologin "$USER_NAME"
fi
echo "$USER_NAME:$PASSWD" | chpasswd

# ---------- 启动 ----------
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable danted >/dev/null 2>&1
  # 官方服务单元没有 Restart=，补一个 drop-in：崩溃后自动拉起
  mkdir -p /etc/systemd/system/danted.service.d
  printf '[Service]\nRestart=on-failure\nRestartSec=3\n' > /etc/systemd/system/danted.service.d/10-restart.conf
  systemctl daemon-reload
  systemctl restart danted
else
  /etc/init.d/danted restart
fi

# ---------- 防火墙 ----------
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  ufw allow "${PORT}/tcp" >/dev/null 2>&1
  ufw allow "${PORT}/udp" >/dev/null 2>&1
  echo "==> ufw 防火墙已放行 $PORT（tcp+udp）"
fi

# ---------- 结果 ----------
sleep 1
echo
if ss -ln 2>/dev/null | grep -q ":$PORT "; then
  cat <<EOF
============================================================
 SK5 安装成功
   地址:  服务器IP:${PORT}
   账号:  ${USER_NAME}
   密码:  ${PASSWD}
 $( [ -n "$IPS" ] && echo "  注意:  绑定的是指定IP（多IP已开轮换）" )
 云厂商网页上的"安全组/防火墙"里也要放行该端口的
 TCP 和 UDP，缺 UDP 会导致 SSTap 的 UDP 测试不过。
============================================================
EOF
else
  echo "服务未能启动，排查命令: journalctl -u danted -e"
  exit 1
fi
