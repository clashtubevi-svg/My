#!/usr/bin/env bash
# Управление клиентами Xray VLESS + Reality.
#   bash manage.sh add <имя>      добавить клиента и показать ссылку + QR
#   bash manage.sh remove <имя>   удалить клиента
#   bash manage.sh list           список клиентов
#   bash manage.sh link <имя>     показать ссылку + QR существующего клиента
set -euo pipefail

CONFIG=/usr/local/etc/xray/config.json
PARAMS=/usr/local/etc/xray/vpn-params
XRAY=/usr/local/bin/xray

die() { echo "Ошибка: $*" >&2; exit 1; }
usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

[[ $EUID -eq 0 ]] || die "запустите от root"
[[ -f $PARAMS ]] || die "сервер не установлен, сначала запустите install.sh"
# shellcheck source=/dev/null
source "$PARAMS"

valid_name() { [[ $1 =~ ^[A-Za-z0-9_.-]{1,32}$ ]] || die "имя может содержать только латиницу, цифры, _ . - (до 32 символов)"; }
client_uuid() { jq -r --arg n "$1" '.inbounds[0].settings.clients[] | select(.email == $n) | .id' "$CONFIG"; }

apply() {
  local tmp="$1"
  $XRAY run -test -c "$tmp" >/dev/null || { rm -f "$tmp"; die "новая конфигурация некорректна, изменения отменены"; }
  cp "$CONFIG" "$CONFIG.bak"
  mv "$tmp" "$CONFIG"
  chmod 644 "$CONFIG"
  systemctl restart xray
}

show_link() {
  local name="$1" uuid
  uuid="$(client_uuid "$name")"
  [[ -n $uuid ]] || die "клиент '$name' не найден"
  local link="vless://${uuid}@${SERVER_IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#${name}"
  echo "Клиент: $name"
  echo "Ссылка (импортируйте в v2rayNG / Hiddify / Streisand / v2RayTun / NekoBox):"
  echo
  echo "$link"
  echo
  command -v qrencode >/dev/null && qrencode -t ansiutf8 "$link"
}

cmd="${1:-}"; name="${2:-}"
case "$cmd" in
  add)
    [[ -n $name ]] || usage
    valid_name "$name"
    [[ -z "$(client_uuid "$name")" ]] || die "клиент '$name' уже существует"
    uuid="$($XRAY uuid)"
    tmp="$(mktemp)"
    jq --arg n "$name" --arg id "$uuid" \
      '.inbounds[0].settings.clients += [{id: $id, email: $n, flow: "xtls-rprx-vision"}]' \
      "$CONFIG" > "$tmp"
    apply "$tmp"
    show_link "$name"
    ;;
  remove)
    [[ -n $name ]] || usage
    [[ -n "$(client_uuid "$name")" ]] || die "клиент '$name' не найден"
    count="$(jq '.inbounds[0].settings.clients | length' "$CONFIG")"
    [[ $count -gt 1 ]] || die "нельзя удалить последнего клиента"
    tmp="$(mktemp)"
    jq --arg n "$name" 'del(.inbounds[0].settings.clients[] | select(.email == $n))' "$CONFIG" > "$tmp"
    apply "$tmp"
    echo "Клиент '$name' удалён."
    ;;
  list)
    jq -r '.inbounds[0].settings.clients[].email' "$CONFIG"
    ;;
  link)
    [[ -n $name ]] || usage
    show_link "$name"
    ;;
  *) usage ;;
esac
