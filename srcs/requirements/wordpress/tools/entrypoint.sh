#! /bin/bash

sed -i "s|listen = /run/php/php8.2-fpm.sock|listen = 0.0.0.0:9000|g" /etc/php/8.2/fpm/pool.d/www.conf

mkdir -p /run/php

cd /var/www/html

if [ ! -f /var/www/html/wp-config.php ]; then
    mysqladmin ping -h $DB_HOST --wait=30 --silent 2>/dev/null
    wp core download --allow-root
    wp config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_USER_PASS" --dbhost="$DB_HOST" --allow-root
    wp core install --url="https://$DOMAIN_NAME" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASS" --admin_email="$WP_ADMIN_EMAIL" --allow-root
fi
chown -R www-data:www-data /var/www/html
exec php-fpm8.2 -F
