# Свой VPN

> **Рекомендуемый способ (2026): [подробная инструкция GUIDE.md](GUIDE.md)** — панель 3x-ui, VLESS Reality + запасной XHTTP, подписки для Happ.

Скрипты ниже поднимают личный VPN-сервер на арендованном VPS одной командой (без панели).

| Вариант | Когда выбирать | Клиенты |
|---|---|---|
| [`xray-reality/`](xray-reality) — **VLESS + Reality** | Есть блокировки VPN (DPI). Трафик выглядит как обычный HTTPS к крупному сайту. **Рекомендуется для России.** | v2rayNG, Hiddify, v2RayTun (Android/iOS), Streisand, FoXray (iOS), Nekoray / Hiddify (ПК) |
| [`wireguard/`](wireguard) — **WireGuard** | Блокировок нет, нужна максимальная скорость и простота. | Официальное приложение WireGuard |

## 1. Арендуйте сервер

- Любой VPS **за пределами страны с блокировками**: Нидерланды, Германия, Финляндия и т.п.
- ОС: **Ubuntu 22.04/24.04** или **Debian 11/12**.
- Хватит 1 vCPU / 512 МБ–1 ГБ RAM.
- Вам нужны IP-адрес и пароль root (или SSH-ключ).

## 2. Подключитесь к серверу

```bash
ssh root@IP_СЕРВЕРА
```

## 3. Установите VPN

```bash
apt-get update && apt-get install -y git
git clone https://github.com/clashtubevi-svg/My.git vpn && cd vpn
```

**Вариант A: VLESS + Reality**

```bash
bash xray-reality/install.sh
```

**Вариант B: WireGuard**

```bash
bash wireguard/install.sh
```

В конце скрипт выведет ссылку (или файл конфига) и **QR-код** для первого клиента `client1`.
Отсканируйте его в приложении на телефоне или импортируйте ссылку/файл на ПК.

На одном сервере можно поставить оба варианта: Reality использует порт 443/tcp, WireGuard 51820/udp.

## 4. Управление клиентами

Создавайте отдельного клиента для каждого устройства или человека:

```bash
# Reality
bash xray-reality/manage.sh add phone
bash xray-reality/manage.sh list
bash xray-reality/manage.sh link phone
bash xray-reality/manage.sh remove phone

# WireGuard
bash wireguard/manage.sh add laptop
bash wireguard/manage.sh list
bash wireguard/manage.sh show laptop     # конфиги лежат в /root/wg-clients/
bash wireguard/manage.sh remove laptop
```

## Настройки

Параметры задаются переменными окружения перед запуском `install.sh`:

| Скрипт | Переменная | По умолчанию | Описание |
|---|---|---|---|
| reality | `PORT` | `443` | Порт сервера |
| reality | `SNI` | `www.microsoft.com` | Сайт, под который маскируется трафик (должен поддерживать TLS 1.3 и HTTP/2) |
| оба | `SERVER_IP` | определяется автоматически | Внешний IP сервера |
| оба | `FIRST_CLIENT` | `client1` | Имя первого клиента |
| wireguard | `PORT` | `51820` | UDP-порт |
| wireguard | `SUBNET` | `10.66.66` | Внутренняя подсеть /24 |
| wireguard | `DNS` | `1.1.1.1, 8.8.8.8` | DNS для клиентов |

Пример: `SNI=www.samsung.com bash xray-reality/install.sh`

## Если что-то не работает

```bash
systemctl status xray          # или: systemctl status wg-quick@wg0
journalctl -u xray -n 50       # или: journalctl -u wg-quick@wg0 -n 50
```

- **Reality не подключается**: проверьте, что у провайдера VPS открыт порт 443/tcp (в панели firewall хостера). Попробуйте другой `SNI`.
- **WireGuard подключается, но нет интернета**: проверьте `sysctl net.ipv4.ip_forward` (должно быть `1`), а в панели хостера откройте 51820/udp.
- **WireGuard не подключается совсем**: скорее всего, его блокирует провайдер. Используйте Reality.

## Безопасность

- Ссылки и конфиги клиентов работают как пароли, не публикуйте их.
- Закрытые ключи хранятся только на сервере (`/usr/local/etc/xray/`, `/etc/wireguard/`) и не попадают в этот репозиторий.
- Обновлять Xray: `bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install && systemctl restart xray`
