#!/usr/bin/env bash
# Установка VPN-сервера WireGuard.
# Быстрый и простой протокол, но легко определяется DPI —
# используйте там, где WireGuard не блокируют.
#
# Использование (под root на Ubuntu 22.04+/Debian 11+):
#   bash install.sh
#   PORT=51820 DNS="1.1.1.1, 1.0.0.1" bash install.sh
set -euo pipefail

PORT="${PORT:-51820}"
SUBNET="${SUBNET:-10.66.66}"          # клиенты получат адреса SUBNET.2 ... SUBNET.254
DNS="${DNS:-1.1.1.1, 8.8.8.8}"
FIRST_CLIENT="${FIRST_CLIENT:-client1}"

WG_DIR=/etc/wireguard
PARAMS="$WG_DIR/params"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "Ошибка: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "запустите скрипт от root (sudo bash install.sh)"
command -v apt-get >/dev/null || die "поддерживаются только Debian/Ubuntu"
[[ -f "$PARAMS" ]] && die "WireGuard уже установлен этим скриптом. Управление клиентами: bash manage.sh"

echo "==> Установка пакетов"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q wireguard wireguard-tools iptables qrencode curl

PUB_IF="$(ip -4 route show default | awk '{print $5; exit}')"
[[ -n $PUB_IF ]] || die "не удалось определить внешний сетевой интерфейс"
SERVER_IP="${SERVER_IP:-$(curl -4 -fsS --max-time 10 https://api.ipify.org || true)}"
[[ -n $SERVER_IP ]] || die "не удалось определить внешний IP, задайте вручную: SERVER_IP=1.2.3.4 bash install.sh"

echo "==> Генерация ключей сервера"
umask 077
mkdir -p "$WG_DIR"
SERVER_PRIV="$(wg genkey)"
SERVER_PUB="$(wg pubkey <<<"$SERVER_PRIV")"

cat > "$WG_DIR/wg0.conf" <<EOF
[Interface]
Address = ${SUBNET}.1/24
ListenPort = ${PORT}
PrivateKey = ${SERVER_PRIV}
PostUp = iptables -I FORWARD -i wg0 -j ACCEPT; iptables -I FORWARD -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -A POSTROUTING -s ${SUBNET}.0/24 -o ${PUB_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -D POSTROUTING -s ${SUBNET}.0/24 -o ${PUB_IF} -j MASQUERADE
EOF

cat > "$PARAMS" <<EOF
SERVER_IP=$SERVER_IP
PORT=$PORT
SUBNET=$SUBNET
DNS="$DNS"
SERVER_PUB=$SERVER_PUB
EOF

echo "==> Включение маршрутизации"
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
sysctl --system >/dev/null

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  echo "==> Настройка ufw"
  ufw allow "$PORT/udp"
  ufw route allow in on wg0 out "$PUB_IF"
fi

systemctl enable --now wg-quick@wg0
systemctl is-active --quiet wg-quick@wg0 || die "WireGuard не запустился: journalctl -u wg-quick@wg0 -n 50"

echo
echo "Готово! WireGuard запущен на ${SERVER_IP}:${PORT}/udp"
echo
bash "$SCRIPT_DIR/manage.sh" add "$FIRST_CLIENT"
echo
echo "Добавить ещё клиентов: bash $SCRIPT_DIR/manage.sh add <имя>"
