#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site/"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
REPO_ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_ROOT}/site/"

DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
    echo "=== Запуск в режиме имитации (--dry-run) ==="
fi

# Требование 4: Проверка наличия site/index.html
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "❌ ОШИБКА: Файл ${LOCAL_DIR}index.html не найден! Деплой отменён." >&2
    exit 1
fi

# Требование 5: Проверка чистоты рабочей копии Git
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "❌ ОШИБКА: В репозитории есть незафиксированные изменения! Сделайте коммит перед деплоем." >&2
    exit 1
fi

# Требования 3, 8, 9: Синхронизация rsync (1 SSH-сессия, BatchMode=yes без пароля)
rsync -avz --delete --chmod=u=rwX,go=rX ${DRY_RUN} \
  -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
  "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}"

# Требование 1: При dry-run выходим с кодом 0 без health-check
if [[ -n "${DRY_RUN}" ]]; then
    echo "✅ План операций успешно сформирован (--dry-run завершён)."
    exit 0
fi

# Требование 6: Проверка доступности по HTTPS с валидацией сертификата
if ! curl -f -s -o /dev/null --cacert "${CA_CERT}" "${SITE_URL}/"; then
    echo "❌ ОШИБКА: Health-check не пройден! Ресурс ${SITE_URL} недоступен." >&2
    exit 1
fi

# Требование 7: Вывод короткого хеша коммита
COMMIT_HASH="$(git rev-parse --short HEAD)"
echo "🚀 Деплой успешно завершён! Доставлен коммит: ${COMMIT_HASH}"
exit 0