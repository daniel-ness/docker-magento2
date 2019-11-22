ARG PHP_TAG=7.2-fpm-1.0

# @todo consider using a different base pkg... could be slimmer
FROM magento/magento-cloud-docker-php:${PHP_TAG}

ARG MAGENTO_VERSION=2.3.2-p2
ARG MYSQL_MAJOR=5.7

ENV MYSQL_MAJOR $MYSQL_MAJOR
ENV MAGENTO_VERSION $MAGENTO_VERSION
ENV PHP_MEMORY_LIMIT -1

RUN echo "deb http://repo.mysql.com/apt/debian/ stretch mysql-${MYSQL_MAJOR}" > /etc/apt/sources.list.d/mysql.list \
    && { \
                echo mysql-community-server mysql-community-server/data-dir select ''; \
                echo mysql-community-server mysql-community-server/root-pass password ''; \
                echo mysql-community-server mysql-community-server/re-root-pass password ''; \
                echo mysql-community-server mysql-community-server/remove-test-db select false; \
        } | debconf-set-selections \
    && apt-get update \
    && apt-get install -y --allow-unauthenticated mysql-server nginx

RUN wget -q "https://github.com/magento/magento2/archive/${MAGENTO_VERSION}.tar.gz" -O "/tmp/magento.tar.gz"
RUN wget -q "https://github.com/magento/magento2-sample-data/archive/${MAGENTO_VERSION}.tar.gz" -O "/tmp/magento-sample.tar.gz"

# install composer
RUN curl -sS https://getcomposer.org/installer | php -dmemory_limit=-1 -- --install-dir=/usr/local/bin --filename=composer

# create a database
RUN service mysql start \
  && while ! mysqladmin ping -hlocalhost --silent; do sleep 1; done \
  && mysql -h localhost -u root -e "CREATE DATABASE magento; CREATE USER magento@localhost IDENTIFIED BY ''; GRANT ALL PRIVILEGES ON magento.* TO magento@localhost;"

# extract magento tarball + sample data over the top
RUN tar xzf /tmp/magento.tar.gz -C /var/www/ \
  && mv "/var/www/magento2-$MAGENTO_VERSION" /var/www/magento2 \
  && tar xzf /tmp/magento-sample.tar.gz -C /var/www/magento2/ magento2-sample-data-$MAGENTO_VERSION/ \
  && cp -rp /var/www/magento2/magento2-sample-data-$MAGENTO_VERSION/* /var/www/magento2 \
  && rm -rf /var/www/magento2/magento2-sample-data-$MAGENTO_VERSION \
  && rm /tmp/magento-sample.tar.gz \
  && rm /tmp/magento.tar.gz

# set php.ini values (@todo just use static files... this is unnecessary for our use case)
RUN sed -i "s/!PHP_MEMORY_LIMIT!/${PHP_MEMORY_LIMIT}/" /usr/local/etc/php/conf.d/zz-magento.ini \
  && sed -i "s/!MAGENTO_RUN_MODE!/${MAGENTO_RUN_MODE}/" /usr/local/etc/php-fpm.conf \
  && pecl install -o -f libsodium \
  && docker-php-ext-enable sodium

RUN echo "user = www-data" >> /usr/local/etc/php-fpm.conf
RUN echo "group = www-data" >> /usr/local/etc/php-fpm.conf

# install composer deps
RUN cd /var/www/magento2 && /usr/local/bin/composer install


# install magento app + sample data
RUN service mysql start \
    && cd /var/www/magento2 \
    && bin/magento setup:install --db-host 127.0.0.1 \
                                 --db-name magento \
                                 --db-user magento \
                                 --admin-user admin \
                                 --admin-email admin@example.com \
                                 --admin-password password123 \
                                 --admin-firstname admin \
                                 --admin-lastname admin \
    && php -f dev/tools/build-sample-data.php -- --ce-source="/var/www/magento2" \
    && bin/magento setup:upgrade \
    && bin/magento setup:di:compile \
    && bin/magento setup:static-content:deploy -f \
    && bin/magento cache:clean

# write nginx vhost
RUN echo " \
upstream fastcgi_backend { \
    server 127.0.0.1:9000; \
} \
server { \
    listen 80; \
    set \$MAGE_ROOT /var/www/magento2; \
    include /var/www/magento2/nginx.conf.sample; \
} \
" > /etc/nginx/sites-enabled/default

RUN chown -R www-data:www-data /var/www/magento2

RUN tar cvzf /tmp/magento2.tar.gz /var/www/magento2 && rm -rf /var/www/magento2

COPY start.sh /start.sh
RUN chmod +x /start.sh
WORKDIR /var/www/magento2

CMD '/start.sh'
