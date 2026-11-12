#!/usr/bin/env bash
# Установка VPN-сервера Xray (VLESS + XTLS-Vision + Reality).
# Трафик выглядит как обычный TLS к стороннему сайту (SNI), поэтому
# протокол устойчив к блокировкам по DPI.
#
# Использование (под root на чистом Ubuntu 22.04+/Debian 11+):
#   bash install.sh                       # значения по умолчанию
#   SNI=www.samsung.com PORT=443 bash install.sh
set -euo pipefail

PORT="${PORT:-443}"
SNI="${SNI:-www.microsoft.com}"
FIRST_CLIENT="${FIRST_CLIENT:-client1}"

CONFIG_DIR=/usr/local/etc/xray
CONFIG="$CONFIG_DIR/config.json"
PARAMS="$CONFIG_DIR/vpn-params"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "Ошибка: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "запустите скрипт от root (sudo bash install.sh)"
command -v apt-get >/dev/null || die "поддерживаются только Debian/Ubuntu"
[[ -f "$PARAMS" ]] && die "Xray уже установлен этим скриптом. Управление клиентами: bash manage.sh"

if ss -ltnH "( sport = :$PORT )" | grep -q .; then
  die "порт $PORT уже занят. Освободите его или задайте другой: PORT=8443 bash install.sh"
fi

echo "==> Установка зависимостей"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q curl jq openssl qrencode ca-certificates

echo "==> Установка Xray (официальный скрипт XTLS/Xray-install)"
bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

XRAY=/usr/local/bin/xray
[[ -x $XRAY ]] || die "xray не установился"

echo "==> Проверка доступности маскировочного сайта $SNI"
if ! curl -fsS --max-time 10 -o /dev/null "https://$SNI"; then
  echo "   Внимание: https://$SNI недоступен с сервера. Лучше выбрать другой SNI." >&2
fi

echo "==> Генерация ключей"
KEYS="$($XRAY x25519)"
# Старые версии Xray печатают "Private key:/Public key:",
# новые печатают "PrivateKey:/Password:" (Password и есть публичный ключ).
PRIVATE_KEY="$(awk -F': *' '/^Private ?[Kk]ey/ {print $2; exit}' <<<"$KEYS")"
PUBLIC_KEY="$(awk -F': *' '/^(Public ?[Kk]ey|Password)/ {print $2; exit}' <<<"$KEYS")"
[[ -n $PRIVATE_KEY && -n $PUBLIC_KEY ]] || die "не удалось разобрать вывод 'xray x25519': $KEYS"
SHORT_ID="$(openssl rand -hex 8)"
UUID="$($XRAY uuid)"

SERVER_IP="${SERVER_IP:-$(curl -4 -fsS --max-time 10 https://api.ipify.org || true)}"
[[ -n $SERVER_IP ]] || die "не удалось определить внешний IP, задайте вручную: SERVER_IP=1.2.3.4 bash install.sh"

echo "==> Запись конфигурации $CONFIG"
mkdir -p "$CONFIG_DIR"
jq -n \
  --argjson port "$PORT" \
  --arg sni "$SNI" \
  --arg pk "$PRIVATE_KEY" \
  --arg sid "$SHORT_ID" \
  --arg uuid "$UUID" \
  --arg email "$FIRST_CLIENT" '
{
  log: { loglevel: "warning" },
  inbounds: [{
    tag: "vless-reality",
    listen: "0.0.0.0",
    port: $port,
    protocol: "vless",
    settings: {
      clients: [{ id: $uuid, email: $email, flow: "xtls-rprx-vision" }],
      decryption: "none"
    },
    streamSettings: {
      network: "tcp",
      security: "reality",
      realitySettings: {
        show: false,
        dest: ($sni + ":443"),
        xver: 0,
        serverNames: [$sni],
        privateKey: $pk,
        shortIds: [$sid]
      }
    },
    sniffing: { enabled: true, destOverride: ["http", "tls", "quic"] }
  }],
  outbounds: [
    { tag: "direct", protocol: "freedom" },
    { tag: "block", protocol: "blackhole" }
  ],
  routing: {
    rules: [
      { type: "field", ip: ["geoip:private"], outboundTag: "block" },
      { type: "field", protocol: ["bittorrent"], outboundTag: "block" }
    ]
  }
}' > "$CONFIG"
chmod 644 "$CONFIG"

cat > "$PARAMS" <<EOF
SERVER_IP=$SERVER_IP
PORT=$PORT
SNI=$SNI
PUBLIC_KEY=$PUBLIC_KEY
SHORT_ID=$SHORT_ID
EOF
chmod 600 "$PARAMS"

$XRAY run -test -c "$CONFIG" >/dev/null || die "конфигурация не прошла проверку"

echo "==> Включение BBR (ускоряет TCP)"
cat > /etc/sysctl.d/99-vpn-bbr.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl --system >/dev/null || true

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  echo "==> Открытие порта $PORT/tcp в ufw"
  ufw allow "$PORT/tcp"
fi

systemctl enable xray >/dev/null
systemctl restart xray
sleep 1
systemctl is-active --quiet xray || die "xray не запустился, смотрите: journalctl -u xray -n 50"

echo
echo "Готово! VPN-сервер запущен."
echo
bash "$SCRIPT_DIR/manage.sh" link "$FIRST_CLIENT"
echo
echo "Добавить ещё клиентов: bash $SCRIPT_DIR/manage.sh add <имя>"
