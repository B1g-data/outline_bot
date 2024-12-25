#!/bin/bash

# Обновление системы
sudo apt update -y
sudo apt upgrade -y

# Установка необходимых пакетов
sudo apt install apache2 mysql-server libapache2-mod-php php php-gd php-json php-mysql php-curl php-xml php-zip php-mbstring php-bcmath php-intl unzip wget -y

# Настройка базы данных MySQL
DB_NAME="nextcloud"
DB_USER="nextclouduser"
DB_PASS="mamuebal"

# Создание базы данных и пользователя в MySQL
sudo mysql -e "CREATE DATABASE ${DB_NAME};"
sudo mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Загрузка и установка Nextcloud
cd /var/www/
sudo wget https://download.nextcloud.com/server/releases/nextcloud-25.0.0.zip
sudo unzip nextcloud-25.0.0.zip
sudo chown -R www-data:www-data nextcloud

# Настройка Apache
APACHE_CONF="/etc/apache2/sites-available/nextcloud.conf"
sudo bash -c "cat > ${APACHE_CONF} <<EOL
<VirtualHost *:80>
    DocumentRoot /var/www/nextcloud
    ServerName localhost

    <Directory /var/www/nextcloud>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL"

# Активировать конфигурацию Apache и перезапустить сервер
sudo a2ensite nextcloud.conf
sudo a2enmod rewrite headers env dir mime
sudo systemctl restart apache2

# Установка SSL через Let's Encrypt (если сервер работает через домен)
# Замените 'your_domain_or_IP' на свой реальный домен или IP-адрес
# sudo apt install certbot python3-certbot-apache -y
# sudo certbot --apache

# Информация о завершении установки
echo "Nextcloud установлен! Перейдите по адресу http://91.49.254.221 для завершения установки."
