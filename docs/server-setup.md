## 8. Веб-сервер Nginx
- **Устанавливаемый пакет:** `nginx` (версия 1.24+ из официального репозитория Ubuntu).
- **Конфигурация ресурса:** `/etc/nginx/sites-available/devops-site` (активирована символической ссылкой в `/etc/nginx/sites-enabled/devops-site`). Стандартный файл `default` отключён.
- **Каталог ресурса:** `/var/www/devops-site`, владелец `devops:devops`, права `755` на каталоги, `644` на файлы.
- **Сертификат и закрытый ключ TLS:**
  - Сертификат: `/etc/ssl/certs/devops.crt` (права `644`, владелец `root:root`);
  - Закрытый ключ: `/etc/ssl/private/devops.key` (права `600`, владелец `root:root`).
- **Срок действия сертификата:** 365 дней (с расширением Subject Alternative Name `DNS:devops.local`).