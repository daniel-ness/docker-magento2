#!/bin/bash

# create a database
service mysql start
while ! mysqladmin ping -hlocalhost --silent; do sleep 1; done
mysql -h localhost -u root -e "
  CREATE DATABASE magento;
  CREATE USER magento@localhost IDENTIFIED BY '';
  GRANT ALL PRIVILEGES ON magento.* TO magento@localhost;
"

[ ! -z "${PHP_MEMORY_LIMIT}" ] && sed -i "s/!PHP_MEMORY_LIMIT!/${PHP_MEMORY_LIMIT}/" /usr/local/etc/php/conf.d/zz-magento.ini
[ ! -z "${UPLOAD_MAX_FILESIZE}" ] && sed -i "s/!UPLOAD_MAX_FILESIZE!/${UPLOAD_MAX_FILESIZE}/" /usr/local/etc/php/conf.d/zz-magento.ini
[ ! -z "${MAGENTO_RUN_MODE}" ] && sed -i "s/!MAGENTO_RUN_MODE!/${MAGENTO_RUN_MODE}/" /usr/local/etc/php-fpm.conf

# extract magento tarball + sample data over the top
tar xzf /tmp/magento.tar.gz -C /var/www/ \
  && mv "/var/www/magento2-$MAGENTO_VERSION" /var/www/magento2 \
  && tar xzf /tmp/magento-sample.tar.gz -C /var/www/magento2/ magento2-sample-data-$MAGENTO_VERSION/ \
  && cp -rp magento2-sample-data-$MAGENTO_VERSION/* /var/www/magento2 \
  && rmdir magento2-sample-data-$MAGENTO_VERSION \
  && rm /tmp/magento-sample.tar.gz \
  && rm /tmp/magento.tar.gz

cd /var/www/magento2
/usr/local/bin/composer install
bin/magento setup:install \
  --db-host 127.0.0.1 \
  --db-name magento \
  --db-user magento \
  --admin-user admin \
  --admin-email admin@example.com \
  --admin-password password123 \
  --admin-firstname admin \
  --admin-lastname admin
php -f dev/tools/build-sample-data.php -- --ce-source="/var/www/magento2"
bin/magento setup:upgrade



