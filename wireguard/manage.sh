#!/usr/bin/env bash
# Управление клиентами WireGuard.
#   bash manage.sh add <имя>      добавить клиента, сохранить .conf и показать QR
#   bash manage.sh remove <имя>   удалить клиента
#   bash manage.sh list           список клиентов
#   bash manage.sh show <имя>     показать конфиг и QR существующего клиента
set -euo pipefail

WG_DIR=/etc/wireguard
CONF="$WG_DIR/wg0.conf"
PARAMS="$WG_DIR/params"
CLIENTS_DIR=/root/wg-clients

die() { echo "Ошибка: $*" >&2; exit 1; }
usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

[[ $EUID -eq 0 ]] || die "запустите от root"
[[ -f $PARAMS ]] || die "сервер не установлен, сначала запустите install.sh"
# shellcheck source=/dev/null
source "$PARAMS"

valid_name() { [[ $1 =~ ^[A-Za-z0-9_.-]{1,32}$ ]] || die "имя может содержать только латиницу, цифры, _ . - (до 32 символов)"; }
exists() { grep -qx "### BEGIN $1" "$CONF"; }
reload() { wg syncconf wg0 <(wg-quick strip wg0); }

show() {
  local file="$CLIENTS_DIR/$1.conf"
  [[ -f $file ]] || die "конфиг клиента '$1' не найден"
  echo "Файл конфигурации: $file"
  echo "Импортируйте его в приложение WireGuard или отсканируйте QR:"
  echo
  qrencode -t ansiutf8 < "$file"
}

cmd="${1:-}"; name="${2:-}"
case "$cmd" in
  add)
    [[ -n $name ]] || usage
    valid_name "$name"
    exists "$name" && die "клиент '$name' уже существует"

    ip=""
    for i in $(seq 2 254); do
      if ! grep -q "AllowedIPs = ${SUBNET}.${i}/32" "$CONF"; then ip="${SUBNET}.${i}"; break; fi
    done
    [[ -n $ip ]] || die "закончились свободные адреса в подсети ${SUBNET}.0/24"

    umask 077
    priv="$(wg genkey)"
    pub="$(wg pubkey <<<"$priv")"
    psk="$(wg genpsk)"

    cat >> "$CONF" <<EOF

### BEGIN $name
[Peer]
PublicKey = $pub
PresharedKey = $psk
AllowedIPs = $ip/32
### END $name
EOF

    mkdir -p "$CLIENTS_DIR"
    cat > "$CLIENTS_DIR/$name.conf" <<EOF
[Interface]
PrivateKey = $priv
Address = $ip/32
DNS = $DNS

[Peer]
PublicKey = $SERVER_PUB
PresharedKey = $psk
Endpoint = $SERVER_IP:$PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
    reload
    echo "Клиент '$name' добавлен ($ip)."
    show "$name"
    ;;
  remove)
    [[ -n $name ]] || usage
    valid_name "$name"
    exists "$name" || die "клиент '$name' не найден"
    cp "$CONF" "$CONF.bak"
    sed -i "/^### BEGIN ${name}\$/,/^### END ${name}\$/d" "$CONF"
    sed -i '/^$/N;/^\n$/D' "$CONF"   # убрать лишние пустые строки
    rm -f "$CLIENTS_DIR/$name.conf"
    reload
    echo "Клиент '$name' удалён."
    ;;
  list)
    grep '^### BEGIN ' "$CONF" | cut -d' ' -f3- || true
    ;;
  show)
    [[ -n $name ]] || usage
    valid_name "$name"
    show "$name"
    ;;
  *) usage ;;
esac
