#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  [OK]   $desc"; ((PASS++))
    else
        echo "  [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён"        "no"  "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no"  "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

PORT_VAL="$(sudo sshd -T | awk '/^port/{print $2}')"
if [[ "$PORT_VAL" != "22" && -n "$PORT_VAL" ]]; then
    check "Порт службы SSH изменён с 22" "not_22" "not_22"
else
    check "Порт службы SSH изменён с 22" "not_22" "22"
fi

check "Максимум попыток аутентификации равен 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"
DEFAULT_INCOMING="$(sudo ufw status verbose | grep -i "Default:" | awk '{print $2}')"
check "Политика по умолчанию для входящего трафика: deny" "deny" "$DEFAULT_INCOMING"

echo "[3] Учётные записи"
awk -F: '$3>=1000 && $3<65534 {printf "    %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер Nginx"
check "Служба Nginx активна" "active" "$(systemctl is-active nginx 2>/dev/null || echo inactive)"

NGINX_TEST="$(sudo nginx -t >/dev/null 2>&1 && echo ok || echo fail)"
check "Конфигурация Nginx корректна" "ok" "$NGINX_TEST"

if sudo openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; then
    CERT_EXP="valid"
else
    CERT_EXP="expiring"
fi
check "Сертификат действует более 30 дней" "valid" "$CERT_EXP"

WORLD_WRITABLE="$(find /var/www/devops-site -perm -o+w 2>/dev/null | wc -l | tr -d ' ')"
KEY_PERMS="$(sudo stat -c '%a' /etc/ssl/private/devops.key 2>/dev/null || echo 000)"
if [[ "$WORLD_WRITABLE" -eq 0 && "$KEY_PERMS" == "600" ]]; then
    check "Права на файлы сайта и TLS-ключ безопасны" "safe" "safe"
else
    check "Права на файлы сайта и TLS-ключ безопасны" "safe" "unsafe"
fi

echo "[5] Контейнеризация"
check "Служба Docker активна" "active" "$(systemctl is-active docker 2>/dev/null || echo inactive)"

DB_HEALTH="$(docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null || echo unhealthy)"
check "Контейнер СУБД в состоянии healthy" "healthy" "$DB_HEALTH"

PUBLIC_PORTS="$(sudo ss -tln | grep -E ':(5000|5432)\b' | grep -v '127.0.0.1:5000' | wc -l | tr -d ' ')"
check "Порты 5000 и 5432 изолированы (только 127.0.0.1)" "0" "$PUBLIC_PORTS"

ENV_PERMS="$(stat -c '%a' /home/devops/app/.env 2>/dev/null || echo 000)"
check "Права файла .env равны 600" "600" "$ENV_PERMS"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1